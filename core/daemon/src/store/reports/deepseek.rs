use super::super::{Store, StoreResult};
use super::llm::{
    list_recent_materials, list_recent_messages, request_json_object, truncate_text,
    MaterialContext, MessageContext,
};
use crate::logger;
use crate::runtime::DeepSeekConfig;
use serde_json::{json, Value};

const MAX_CONTEXT_MESSAGES: usize = 8;
const MAX_CONTEXT_MATERIALS: usize = 6;

pub(super) fn generate_final_report(store: &Store, thread_id: &str) -> StoreResult<Value> {
    let fallback_report = store.thread_report_draft(thread_id)?;
    let recent_messages = list_recent_messages(store, thread_id, MAX_CONTEXT_MESSAGES)?;
    let recent_materials = list_recent_materials(store, thread_id, MAX_CONTEXT_MATERIALS)?;
    let config = DeepSeekConfig::from_env().map_err(|reason| {
        logger::error_fields(
            "final report model unavailable",
            &[
                ("thread_id", thread_id.to_string()),
                ("reason", reason.clone()),
            ],
        );
        reason
    })?;

    let candidate = request_json_object(
        &config,
        system_prompt(),
        &user_prompt(&fallback_report, &recent_messages, &recent_materials),
        0.2,
        900,
    )?;
    Ok(normalize_report(candidate, &fallback_report))
}

fn system_prompt() -> &'static str {
    "你是资深产品可行性分析助手。仅输出一个 JSON 对象，不要解释、不要 markdown、不要代码块。\
字段必须完整：project_name(string)、problem_definition(string)、target_users(string)、\
core_capabilities(string[])、risks_and_constraints(string[])、initial_delivery_plan(string[])、\
feasibility_conclusion(string)。列表字段输出 3 到 6 条，语言简洁且可执行。"
}

fn user_prompt(
    draft: &Value,
    messages: &[MessageContext],
    materials: &[MaterialContext],
) -> String {
    let message_lines = if messages.is_empty() {
        "- 无历史消息".to_string()
    } else {
        messages
            .iter()
            .enumerate()
            .map(|(index, message)| {
                format!(
                    "- {}. [{}] {}",
                    index + 1,
                    message.role,
                    truncate_text(&message.content, 240)
                )
            })
            .collect::<Vec<_>>()
            .join("\n")
    };

    let material_lines = if materials.is_empty() {
        "- 无材料".to_string()
    } else {
        materials
            .iter()
            .enumerate()
            .map(|(index, material)| {
                format!(
                    "- {}. {} | {} | {} | {}",
                    index + 1,
                    material.name,
                    material.type_hint,
                    material.size_hint,
                    material.status
                )
            })
            .collect::<Vec<_>>()
            .join("\n")
    };

    format!(
        "请基于以下上下文，输出最终可行性方案 JSON。\n\n\
已有草稿(JSON):\n{}\n\n\
最近对话:\n{}\n\n\
已导入材料(仅元信息):\n{}\n\n\
约束：\n\
1) 不要输出字段以外的内容。\n\
2) 项目名不要使用“待定义/新项目/项目”这类占位词。\n\
3) 如果信息不足，结合已有草稿做保守补全。",
        serde_json::to_string(draft).unwrap_or_else(|_| "{}".to_string()),
        message_lines,
        material_lines
    )
}

fn normalize_report(candidate: Value, fallback: &Value) -> Value {
    let fallback_project_name = fallback_text(fallback, "project_name", "新项目");
    let project_name = normalize_project_name(
        candidate.get("project_name").and_then(Value::as_str),
        fallback_project_name,
    );

    let fallback_problem = fallback_text(fallback, "problem_definition", "待补充");
    let fallback_target_users = fallback_text(fallback, "target_users", "待补充");
    let fallback_conclusion = fallback_text(fallback, "feasibility_conclusion", "待评估");
    let fallback_capabilities = fallback_array(fallback, "core_capabilities", "待补充");
    let fallback_risks = fallback_array(fallback, "risks_and_constraints", "待补充");
    let fallback_delivery = fallback_array(fallback, "initial_delivery_plan", "待补充");

    json!({
        "project_name": project_name,
        "problem_definition": normalize_text(candidate.get("problem_definition").and_then(Value::as_str), fallback_problem),
        "target_users": normalize_text(candidate.get("target_users").and_then(Value::as_str), fallback_target_users),
        "core_capabilities": normalize_string_list(candidate.get("core_capabilities"), &fallback_capabilities),
        "risks_and_constraints": normalize_string_list(candidate.get("risks_and_constraints"), &fallback_risks),
        "initial_delivery_plan": normalize_string_list(candidate.get("initial_delivery_plan"), &fallback_delivery),
        "feasibility_conclusion": normalize_text(candidate.get("feasibility_conclusion").and_then(Value::as_str), fallback_conclusion),
        "version": "v0.1"
    })
}

fn normalize_project_name(candidate: Option<&str>, fallback: &str) -> String {
    let chosen = normalize_text(candidate, fallback);
    if matches!(chosen.as_str(), "待定义" | "新项目" | "项目") {
        "可行性方案项目".to_string()
    } else {
        chosen
    }
}

fn normalize_text(candidate: Option<&str>, fallback: &str) -> String {
    candidate
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or(fallback)
        .to_string()
}

fn normalize_string_list(candidate: Option<&Value>, fallback: &[String]) -> Vec<String> {
    let values = match candidate {
        Some(Value::Array(items)) => items
            .iter()
            .filter_map(Value::as_str)
            .map(str::trim)
            .filter(|item| !item.is_empty())
            .map(|item| item.to_string())
            .collect::<Vec<_>>(),
        Some(Value::String(value)) => vec![value.trim().to_string()],
        _ => vec![],
    };

    let mut merged = if values.is_empty() {
        fallback.to_vec()
    } else {
        values
    };
    merged.retain(|item| !item.is_empty());
    if merged.is_empty() {
        merged.push("待补充".to_string());
    }
    merged.truncate(6);
    merged
}

fn fallback_text<'a>(report: &'a Value, field: &str, default: &'a str) -> &'a str {
    report.get(field).and_then(Value::as_str).unwrap_or(default)
}

fn fallback_array(report: &Value, field: &str, default: &str) -> Vec<String> {
    let mut values = report
        .get(field)
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(Value::as_str)
                .map(str::trim)
                .filter(|item| !item.is_empty())
                .map(|item| item.to_string())
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    if values.is_empty() {
        values.push(default.to_string());
    }
    values
}

#[cfg(test)]
mod tests {
    use super::normalize_report;
    use serde_json::json;

    #[test]
    fn normalize_report_falls_back_when_missing_fields() {
        let fallback = json!({
            "project_name": "备用名",
            "problem_definition": "问题",
            "target_users": "用户",
            "core_capabilities": ["能力A"],
            "risks_and_constraints": ["风险A"],
            "initial_delivery_plan": ["计划A"],
            "feasibility_conclusion": "结论A"
        });
        let candidate = json!({
            "project_name": "  ",
            "problem_definition": "新问题"
        });
        let normalized = normalize_report(candidate, &fallback);
        assert_eq!(normalized["problem_definition"], "新问题");
        assert_eq!(normalized["target_users"], "用户");
        assert_eq!(normalized["core_capabilities"], json!(["能力A"]));
    }
}

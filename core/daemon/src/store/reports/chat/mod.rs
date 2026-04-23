use super::super::{Store, StoreResult};
use super::llm::{
    list_recent_materials, list_recent_messages, request_json_object, truncate_text,
    MaterialContext, MessageContext, MAX_CONTEXT_MATERIALS, MAX_CONTEXT_MESSAGES,
};
use crate::logger;
use crate::runtime::DeepSeekConfig;
use serde_json::{json, Map, Value};

pub(in crate::store) struct ClarificationTurn {
    pub(in crate::store) assistant_message: String,
    pub(in crate::store) report_patch: Value,
}

pub(super) fn generate_clarification_turn(
    store: &Store,
    thread_id: &str,
    user_message: &str,
) -> StoreResult<ClarificationTurn> {
    let draft = store.thread_report_draft(thread_id)?;
    let recent_messages = list_recent_messages(store, thread_id, MAX_CONTEXT_MESSAGES)?;
    let recent_materials = list_recent_materials(store, thread_id, MAX_CONTEXT_MATERIALS)?;
    let config = DeepSeekConfig::from_env().map_err(|reason| {
        let message = format!("DeepSeek 配置缺失: {reason}");
        logger::error_fields(
            "clarification model unavailable",
            &[
                ("thread_id", thread_id.to_string()),
                ("reason", message.clone()),
            ],
        );
        message
    })?;
    let model = config.model().to_string();

    let candidate = request_json_object(
        &config,
        &system_prompt(),
        &user_prompt(&draft, &recent_messages, &recent_materials, user_message),
        0.2,
        520,
    )?;
    let reply = normalize_reply(candidate.get("assistant_reply")).map_err(|reason| {
        let message = format!("DeepSeek 响应缺少有效 assistant_reply: {reason}");
        let request_data = json!({
            "draft": draft,
            "recent_messages": recent_messages,
            "recent_materials": recent_materials,
            "user_message": user_message,
        });
        logger::error_fields(
            "clarification model response invalid",
            &[
                ("thread_id", thread_id.to_string()),
                ("model", model.clone()),
                ("request_data", request_data.to_string()),
                ("response_data", candidate.to_string()),
                ("reason", message.clone()),
            ],
        );
        message
    })?;
    let report_patch = normalize_report_patch(candidate.get("report_patch"));

    Ok(ClarificationTurn {
        assistant_message: reply,
        report_patch,
    })
}

fn system_prompt() -> String {
    "你是资深产品顾问和架构分析助手，负责用自然语言给出需求的第一版可行性判断。\
你的默认目标不是追问，而是先根据行业里常见的技术方案、专业边界和产品方向，尽可能一次性给出完整的可行性报告、核心方案和风险判断。\
只有在确实缺少“无法继续生成”的关键元素时，才在 assistant_reply 里自然地问一句，不要输出固定追问模板。\
如果用户的问题与生成系统无关，先明确询问他真正想实现的效果，再继续判断。\
仅输出一个 JSON 对象，不要解释、不要 markdown、不要代码块。\
JSON 字段要求：\
assistant_reply(string, 直接可展示给用户的中文回复);\
report_patch(object, 只放新增或修正字段，可选字段：project_name,problem_definition,target_users,core_capabilities,risks_and_constraints,initial_delivery_plan,feasibility_conclusion)。\
report_patch 允许为空对象；不要输出占位词（待定义/待补充/未知）。"
    .to_string()
        + "表达要求：如果信息足够，直接给出完整判断和建议；如果信息不足，只问最必要的一句自然问题，不能拼接“确认两点/请补充”等固定格式。"
}

fn user_prompt(
    draft: &Value,
    messages: &[MessageContext],
    materials: &[MaterialContext],
    user_message: &str,
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
                    truncate_text(&message.content, 220)
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
        "请基于以下上下文，输出 AI 原生的需求分析 JSON。\n\n\
当前草稿(JSON):\n{}\n\n\
最近对话:\n{}\n\n\
本轮用户输入:\n{}\n\n\
材料元信息:\n{}\n\n\
约束：\
1) assistant_reply 必须是可直接展示的自然回复，优先先给完整可行性分析，不要固定开场白；\
2) 只有在确实缺少关键输入时，assistant_reply 才能包含一句自然提问；\
3) 如果当前主题与生成系统无关，先问用户真正想实现的效果，再给判断；\
4) report_patch 只包含你确定要更新的字段；\
5) 不要要求用户按固定模板回答，允许自然叙述。",
        serde_json::to_string(draft).unwrap_or_else(|_| "{}".to_string()),
        message_lines,
        truncate_text(user_message, 240),
        material_lines
    )
}

fn normalize_reply(candidate: Option<&Value>) -> Result<String, String> {
    candidate
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .ok_or_else(|| "assistant_reply 不能为空".to_string())
}

fn normalize_report_patch(candidate: Option<&Value>) -> Value {
    let Some(Value::Object(raw_patch)) = candidate else {
        return json!({});
    };
    let mut patch = Map::new();

    update_text_field(raw_patch, &mut patch, "project_name", true);
    update_text_field(raw_patch, &mut patch, "problem_definition", false);
    update_text_field(raw_patch, &mut patch, "target_users", false);
    update_text_field(raw_patch, &mut patch, "feasibility_conclusion", false);

    update_list_field(raw_patch, &mut patch, "core_capabilities");
    update_list_field(raw_patch, &mut patch, "risks_and_constraints");
    update_list_field(raw_patch, &mut patch, "initial_delivery_plan");

    Value::Object(patch)
}

fn update_text_field(
    source: &Map<String, Value>,
    target: &mut Map<String, Value>,
    field: &str,
    reject_placeholder: bool,
) {
    let Some(raw) = source.get(field).and_then(Value::as_str) else {
        return;
    };
    let text = raw.trim();
    if text.is_empty() {
        return;
    }
    if reject_placeholder && matches!(text, "待定义" | "新项目" | "项目") {
        return;
    }
    target.insert(field.to_string(), Value::String(text.to_string()));
}

fn update_list_field(source: &Map<String, Value>, target: &mut Map<String, Value>, field: &str) {
    let values = match source.get(field) {
        Some(Value::Array(items)) => items
            .iter()
            .filter_map(Value::as_str)
            .map(str::trim)
            .filter(|item| !item.is_empty())
            .map(|item| item.to_string())
            .collect::<Vec<_>>(),
        Some(Value::String(one)) => {
            let trimmed = one.trim();
            if trimmed.is_empty() {
                Vec::new()
            } else {
                vec![trimmed.to_string()]
            }
        }
        _ => Vec::new(),
    };

    if values.is_empty() {
        return;
    }

    let mut unique = Vec::new();
    for value in values {
        if !unique.contains(&value) {
            unique.push(value);
        }
    }
    unique.truncate(6);
    let json_array = unique.into_iter().map(Value::String).collect::<Vec<_>>();
    target.insert(field.to_string(), Value::Array(json_array));
}

#[cfg(test)]
mod tests {
    use super::normalize_report_patch;
    use serde_json::json;

    #[test]
    fn normalize_report_patch_discards_placeholder_and_empty_values() {
        let patch = json!({
            "project_name": "待定义",
            "problem_definition": "  ",
            "core_capabilities": ["A", "", "A"],
            "initial_delivery_plan": "先完成最小闭环"
        });
        let normalized = normalize_report_patch(Some(&patch));
        assert!(normalized.get("project_name").is_none());
        assert!(normalized.get("problem_definition").is_none());
        assert_eq!(normalized["core_capabilities"], json!(["A"]));
        assert_eq!(
            normalized["initial_delivery_plan"],
            json!(["先完成最小闭环"])
        );
    }
}

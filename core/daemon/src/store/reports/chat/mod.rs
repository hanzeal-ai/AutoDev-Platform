use super::super::{Store, StoreResult};
use super::llm::{
    list_recent_materials, list_recent_messages, MAX_CONTEXT_MATERIALS, MAX_CONTEXT_MESSAGES,
};
use super::llm::worker;
use crate::logger;
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
    if !worker::worker_available() {
        return Err(
            "AI Worker 不可用，无法生成对话。请确保 Python AI Worker 正在运行。".to_string(),
        );
    }

    let draft = store.thread_report_draft(thread_id)?;
    let recent_messages = list_recent_messages(store, thread_id, MAX_CONTEXT_MESSAGES)?;
    let recent_materials = list_recent_materials(store, thread_id, MAX_CONTEXT_MATERIALS)?;

    let messages: Vec<Value> = recent_messages
        .iter()
        .map(|m| serde_json::to_value(m).unwrap_or_default())
        .collect();
    let materials: Vec<Value> = recent_materials
        .iter()
        .map(|m| serde_json::to_value(m).unwrap_or_default())
        .collect();

    let candidate = worker::request_chat_clarification(
        thread_id,
        user_message,
        &draft,
        &messages,
        &materials,
    )?;

    let reply = candidate
        .get("assistant_reply")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .ok_or_else(|| {
            logger::error_fields(
                "worker chat response missing assistant_reply",
                &[
                    ("thread_id", thread_id.to_string()),
                    ("response_data", candidate.to_string()),
                ],
            );
            "AI Worker 响应缺少有效 assistant_reply".to_string()
        })?;

    let report_patch = normalize_report_patch(candidate.get("report_patch"));

    Ok(ClarificationTurn {
        assistant_message: reply,
        report_patch,
    })
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

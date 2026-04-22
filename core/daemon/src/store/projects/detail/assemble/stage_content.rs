use super::super::super::super::helpers::{parse_json_array_strings, parse_json_value};
use super::super::super::super::StageDefaults;
use super::super::query::StageRow;
use serde_json::Value;

pub(in crate::store::projects::detail) struct StageContent {
    pub(in crate::store::projects::detail) objective: String,
    pub(in crate::store::projects::detail) input_contexts: Vec<String>,
    pub(in crate::store::projects::detail) step_progress: Value,
    pub(in crate::store::projects::detail) risk_items: Vec<String>,
    pub(in crate::store::projects::detail) event_flow: Vec<String>,
    pub(in crate::store::projects::detail) primary_action: String,
    pub(in crate::store::projects::detail) secondary_actions: Vec<String>,
    pub(in crate::store::projects::detail) downloads: Vec<Value>,
    pub(in crate::store::projects::detail) work_units: Vec<Value>,
}

pub(in crate::store::projects::detail) fn merge_stage_content(
    stage_row: Option<&StageRow>,
    defaults: &StageDefaults,
) -> StageContent {
    let objective = stage_row
        .map(|value| value.objective.as_str())
        .unwrap_or(defaults.objective)
        .to_string();
    let input_contexts = stage_row
        .map(|value| parse_json_array_strings(&value.input_contexts_json))
        .unwrap_or_else(|| {
            defaults
                .input_contexts
                .iter()
                .map(ToString::to_string)
                .collect()
        });
    let step_progress = stage_row
        .map(|value| parse_json_value(&value.step_progress_json))
        .unwrap_or_else(|| defaults.step_progress.clone());
    let risk_items = stage_row
        .map(|value| parse_json_array_strings(&value.risk_items_json))
        .unwrap_or_else(|| {
            defaults
                .risk_items
                .iter()
                .map(ToString::to_string)
                .collect()
        });
    let event_flow = stage_row
        .map(|value| parse_json_array_strings(&value.event_flow_json))
        .unwrap_or_else(|| {
            defaults
                .event_flow
                .iter()
                .map(ToString::to_string)
                .collect()
        });
    let primary_action = stage_row
        .map(|value| value.primary_action.as_str())
        .unwrap_or(defaults.primary_action)
        .to_string();
    let secondary_actions = stage_row
        .map(|value| parse_json_array_strings(&value.secondary_actions_json))
        .unwrap_or_else(|| {
            defaults
                .secondary_actions
                .iter()
                .map(ToString::to_string)
                .collect()
        });
    let downloads = stage_row
        .map(|value| json_array_values(&value.downloads_json))
        .filter(|items| !items.is_empty())
        .unwrap_or_else(|| {
            defaults
                .downloads
                .iter()
                .map(|item| {
                    serde_json::json!({
                        "id": item.id,
                        "title": item.title,
                        "category": item.category,
                        "availability": item.availability,
                        "file_path": item.file_path,
                        "updated_at_ms": item.updated_at_ms,
                        "content_type": item.content_type,
                    })
                })
                .collect()
        });
    let work_units = stage_row
        .map(|value| json_array_values(&value.work_units_json))
        .filter(|items| !items.is_empty())
        .unwrap_or_else(|| {
            defaults
                .work_units
                .iter()
                .map(|unit| {
                    serde_json::json!({
                        "id": unit.id,
                        "title": unit.title,
                        "agent_role": unit.agent_role,
                        "status": unit.status,
                        "progress": unit.progress,
                        "depends_on": unit.depends_on,
                        "current_output": unit.current_output,
                        "next_step": unit.next_step,
                        "downloads": [],
                    })
                })
                .collect()
        });

    StageContent {
        objective,
        input_contexts,
        step_progress,
        risk_items,
        event_flow,
        primary_action,
        secondary_actions,
        downloads,
        work_units,
    }
}

fn json_array_values(raw: &str) -> Vec<Value> {
    parse_json_value(raw).as_array().cloned().unwrap_or_default()
}

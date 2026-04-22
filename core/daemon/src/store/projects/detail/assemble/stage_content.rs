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
    if let Some(row) = stage_row {
        let input_contexts = parse_json_array_strings(&row.input_contexts_json);
        let default_input_contexts = defaults
            .input_contexts
            .iter()
            .map(ToString::to_string)
            .collect::<Vec<_>>();
        if row.objective == defaults.objective && input_contexts == default_input_contexts {
            return StageContent {
                objective: String::new(),
                input_contexts: Vec::new(),
                step_progress: Value::Array(Vec::new()),
                risk_items: Vec::new(),
                event_flow: Vec::new(),
                primary_action: String::new(),
                secondary_actions: Vec::new(),
                downloads: Vec::new(),
                work_units: Vec::new(),
            };
        }
    }

    let objective = stage_row
        .map(|value| value.objective.as_str())
        .unwrap_or("")
        .to_string();
    let input_contexts = stage_row
        .map(|value| parse_json_array_strings(&value.input_contexts_json))
        .unwrap_or_default();
    let step_progress = stage_row
        .map(|value| parse_json_value(&value.step_progress_json))
        .unwrap_or_else(|| Value::Array(Vec::new()));
    let risk_items = stage_row
        .map(|value| parse_json_array_strings(&value.risk_items_json))
        .unwrap_or_default();
    let event_flow = stage_row
        .map(|value| parse_json_array_strings(&value.event_flow_json))
        .unwrap_or_default();
    let primary_action = stage_row
        .map(|value| value.primary_action.as_str())
        .unwrap_or("")
        .to_string();
    let secondary_actions = stage_row
        .map(|value| parse_json_array_strings(&value.secondary_actions_json))
        .unwrap_or_default();
    let downloads = stage_row
        .map(|value| json_array_values(&value.downloads_json))
        .unwrap_or_default()
        .into_iter()
        .filter(has_real_file_path)
        .collect();
    let work_units = stage_row
        .map(|value| json_array_values(&value.work_units_json))
        .unwrap_or_default();

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
    parse_json_value(raw)
        .as_array()
        .cloned()
        .unwrap_or_default()
}

fn has_real_file_path(value: &Value) -> bool {
    value
        .get("file_path")
        .and_then(Value::as_str)
        .map(str::trim)
        .is_some_and(|path| !path.is_empty())
}

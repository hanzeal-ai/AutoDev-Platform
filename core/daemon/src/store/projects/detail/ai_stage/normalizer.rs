use super::super::super::super::helpers::to_json_string;
use super::super::super::super::{StageDefaults, Store, StoreResult};
use super::prompt::stage_prompt_label;
use crate::runtime::DeepSeekConfig;
use rusqlite::params;
use serde_json::{json, Value};

const MAX_INPUT_CONTEXTS: usize = 8;
const MAX_RISK_ITEMS: usize = 6;
const MAX_EVENT_FLOW: usize = 6;
const MAX_SECONDARY_ACTIONS: usize = 4;
const MAX_WORK_UNITS: usize = 6;

pub(super) fn normalize_stage_content(
    candidate: Value,
    stage: &str,
    defaults: &StageDefaults,
    config: &DeepSeekConfig,
) -> Value {
    let objective = text_field(&candidate, "objective", "");
    let input_contexts = capped_string_list(
        candidate.get("input_contexts"),
        &[],
        MAX_INPUT_CONTEXTS,
    );
    let mut input_contexts = input_contexts;
    input_contexts.insert(
        0,
        format!("真实 AI：{} / {}", config.model(), stage_prompt_label(stage)),
    );

    json!({
        "objective": objective,
        "input_contexts": input_contexts,
        "step_progress": normalize_step_progress(candidate.get("step_progress"), &json!([])),
        "risk_items": capped_string_list(candidate.get("risk_items"), &[], MAX_RISK_ITEMS),
        "event_flow": capped_string_list(candidate.get("event_flow"), &[], MAX_EVENT_FLOW),
        "primary_action": text_field(&candidate, "primary_action", ""),
        "secondary_actions": capped_string_list(candidate.get("secondary_actions"), &[], MAX_SECONDARY_ACTIONS),
        "work_units": normalize_work_units(candidate.get("work_units"), defaults)
    })
}

pub(super) fn persist_stage_content(
    store: &Store,
    project_id: &str,
    stage: &str,
    defaults: &StageDefaults,
    content: &Value,
) -> StoreResult<()> {
    let now = super::super::super::super::helpers::now_ms();
    store
        .conn
        .execute(
            r#"
INSERT INTO project_stages (
  project_id, stage, objective, input_contexts_json, step_progress_json,
  risk_items_json, event_flow_json, primary_action, secondary_actions_json,
  downloads_json, work_units_json, updated_at_ms
) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
ON CONFLICT(project_id, stage) DO UPDATE SET
  objective = excluded.objective,
  input_contexts_json = excluded.input_contexts_json,
  step_progress_json = excluded.step_progress_json,
  risk_items_json = excluded.risk_items_json,
  event_flow_json = excluded.event_flow_json,
  primary_action = excluded.primary_action,
  secondary_actions_json = excluded.secondary_actions_json,
  work_units_json = excluded.work_units_json,
  updated_at_ms = excluded.updated_at_ms
"#,
            params![
                project_id,
                stage,
                content
                    .get("objective")
                    .and_then(Value::as_str)
                    .unwrap_or(defaults.objective),
                to_json_string(
                    content
                        .get("input_contexts")
                        .unwrap_or(&json!(defaults.input_contexts))
                ),
                to_json_string(
                    content
                        .get("step_progress")
                        .unwrap_or(&defaults.step_progress)
                ),
                to_json_string(
                    content
                        .get("risk_items")
                        .unwrap_or(&json!(defaults.risk_items))
                ),
                to_json_string(
                    content
                        .get("event_flow")
                        .unwrap_or(&json!(defaults.event_flow))
                ),
                content
                    .get("primary_action")
                    .and_then(Value::as_str)
                    .unwrap_or(defaults.primary_action),
                to_json_string(
                    content
                        .get("secondary_actions")
                        .unwrap_or(&json!(defaults.secondary_actions))
                ),
                "[]",
                to_json_string(content.get("work_units").unwrap_or(&json!([]))),
                now,
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

fn text_field(candidate: &Value, key: &str, fallback: &str) -> String {
    candidate
        .get(key)
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or(fallback)
        .to_string()
}

fn capped_string_list(candidate: Option<&Value>, fallback: &[String], max: usize) -> Vec<String> {
    let mut out = match candidate {
        Some(Value::Array(items)) => items
            .iter()
            .filter_map(Value::as_str)
            .map(str::trim)
            .filter(|item| !item.is_empty())
            .map(ToString::to_string)
            .collect::<Vec<_>>(),
        Some(Value::String(value)) => vec![value.trim().to_string()],
        _ => fallback.to_vec(),
    };
    if out.is_empty() {
        out = fallback.to_vec();
    }
    out.truncate(max);
    out
}

fn normalize_step_progress(candidate: Option<&Value>, fallback: &Value) -> Value {
    let items = candidate
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(|item| {
                    let title = item.get("title").and_then(Value::as_str)?.trim();
                    if title.is_empty() {
                        return None;
                    }
                    Some(json!({
                        "title": title,
                        "status": normalize_status(item.get("status").and_then(Value::as_str), "queued")
                    }))
                })
                .collect::<Vec<Value>>()
        })
        .unwrap_or_default();

    if items.is_empty() {
        fallback.clone()
    } else {
        Value::Array(items)
    }
}

fn normalize_work_units(candidate: Option<&Value>, _defaults: &StageDefaults) -> Value {
    let mut units = candidate
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(normalize_work_unit)
                .collect::<Vec<Value>>()
        })
        .unwrap_or_default();

    units.truncate(MAX_WORK_UNITS);
    Value::Array(units)
}

fn normalize_work_unit(item: &Value) -> Option<Value> {
    let id = item.get("id").and_then(Value::as_str)?.trim();
    let title = item.get("title").and_then(Value::as_str)?.trim();
    let agent_role = item.get("agent_role").and_then(Value::as_str)?.trim();
    if id.is_empty() || title.is_empty() || agent_role.is_empty() {
        return None;
    }
    let progress = item
        .get("progress")
        .and_then(Value::as_f64)
        .unwrap_or(0.0)
        .clamp(0.0, 1.0);
    let depends_on = item
        .get("depends_on")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(Value::as_str)
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(ToString::to_string)
                .collect::<Vec<String>>()
        })
        .unwrap_or_default();

    Some(json!({
        "id": id,
        "title": title,
        "agent_role": agent_role,
        "status": normalize_status(item.get("status").and_then(Value::as_str), "queued"),
        "progress": progress,
        "depends_on": depends_on,
        "current_output": item.get("current_output").and_then(Value::as_str),
        "next_step": text_field(item, "next_step", "继续推进"),
        "downloads": []
    }))
}

fn normalize_status(candidate: Option<&str>, fallback: &str) -> String {
    match candidate.unwrap_or(fallback).trim() {
        "queued" | "running" | "completed" | "awaiting_confirmation" | "blocked" | "failed" => {
            candidate.unwrap_or(fallback).trim().to_string()
        }
        _ => fallback.to_string(),
    }
}

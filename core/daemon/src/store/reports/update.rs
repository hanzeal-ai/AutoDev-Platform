use super::super::helpers::to_json_string;
use super::super::{Store, StoreResult};
use super::file::write_report_file;
use rusqlite::params;
use serde_json::{json, Value};

pub(super) fn update_report_from_patch(
    store: &Store,
    thread_id: &str,
    patch: &Value,
    now: i64,
) -> StoreResult<()> {
    let mut report = store.thread_report_draft(thread_id)?;
    merge_report_patch(&mut report, patch);
    persist_report(store, thread_id, &report, now)
}

pub(super) fn persist_report(
    store: &Store,
    thread_id: &str,
    report: &Value,
    now: i64,
) -> StoreResult<()> {
    let report_path = write_report_file(store, thread_id, report)?;
    store
        .conn
        .execute(
            r#"
UPDATE feasibility_reports
SET
  project_name = ?1,
  problem_definition = ?2,
  target_users = ?3,
  core_capabilities_json = ?4,
  risks_constraints_json = ?5,
  delivery_plan_json = ?6,
  feasibility_conclusion = ?7,
  report_file_path = ?8,
  updated_at_ms = ?9
WHERE thread_id = ?10
"#,
            params![
                text_or_default(report, "project_name", "待定义"),
                text_or_default(report, "problem_definition", "待补充"),
                text_or_default(report, "target_users", "待补充"),
                array_or_default(report, "core_capabilities"),
                array_or_default(report, "risks_and_constraints"),
                array_or_default(report, "initial_delivery_plan"),
                text_or_default(report, "feasibility_conclusion", "待评估"),
                report_path.display().to_string(),
                now,
                thread_id
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

fn merge_report_patch(report: &mut Value, patch: &Value) {
    let Some(patch_obj) = patch.as_object() else {
        return;
    };

    merge_text_field(report, patch_obj, "project_name");
    merge_text_field(report, patch_obj, "problem_definition");
    merge_text_field(report, patch_obj, "target_users");
    merge_text_field(report, patch_obj, "feasibility_conclusion");

    merge_list_field(report, patch_obj, "core_capabilities");
    merge_list_field(report, patch_obj, "risks_and_constraints");
    merge_list_field(report, patch_obj, "initial_delivery_plan");
}

fn merge_text_field(report: &mut Value, patch: &serde_json::Map<String, Value>, field: &str) {
    let Some(content) = patch.get(field).and_then(Value::as_str) else {
        return;
    };
    let text = content.trim();
    if text.is_empty() {
        return;
    }
    report[field] = Value::String(text.to_string());
}

fn merge_list_field(report: &mut Value, patch: &serde_json::Map<String, Value>, field: &str) {
    let values = match patch.get(field) {
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
    report[field] = Value::Array(unique.into_iter().map(Value::String).collect());
}

fn text_or_default<'a>(report: &'a Value, field: &str, default: &'a str) -> &'a str {
    report.get(field).and_then(Value::as_str).unwrap_or(default)
}

fn array_or_default(report: &Value, field: &str) -> String {
    to_json_string(
        &report
            .get(field)
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_else(|| vec![json!("待补充")]),
    )
}

#[cfg(test)]
mod tests {
    use super::merge_report_patch;
    use serde_json::json;

    #[test]
    fn merge_report_patch_updates_only_present_fields() {
        let mut report = json!({
            "problem_definition": "旧问题",
            "target_users": "旧用户",
            "core_capabilities": ["旧能力"],
            "initial_delivery_plan": ["旧计划"]
        });
        let patch = json!({
            "problem_definition": "新问题",
            "core_capabilities": ["新能力", "新能力"],
            "risks_and_constraints": ["风险A"]
        });
        merge_report_patch(&mut report, &patch);
        assert_eq!(report["problem_definition"], "新问题");
        assert_eq!(report["target_users"], "旧用户");
        assert_eq!(report["core_capabilities"], json!(["新能力"]));
        assert_eq!(report["risks_and_constraints"], json!(["风险A"]));
        assert_eq!(report["initial_delivery_plan"], json!(["旧计划"]));
    }
}

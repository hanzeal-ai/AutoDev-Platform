use super::super::helpers::{parse_json_array_strings, relative_label};
use super::super::{Store, StoreResult};
use rusqlite::{params, OptionalExtension};
use serde_json::{json, Value};

pub(super) fn load_thread_report_draft(store: &Store, thread_id: &str) -> StoreResult<Value> {
    let row = store
        .conn
        .query_row(
            r#"
SELECT
  project_name, problem_definition, target_users, core_capabilities_json,
  risks_constraints_json, delivery_plan_json, feasibility_conclusion, version,
  report_file_path, updated_at_ms
FROM feasibility_reports
WHERE thread_id = ?1
"#,
            params![thread_id],
            |row| {
                Ok(json!({
                    "project_name": row.get::<_, String>(0)?,
                    "problem_definition": row.get::<_, String>(1)?,
                    "target_users": row.get::<_, String>(2)?,
                    "core_capabilities": parse_json_array_strings(&row.get::<_, String>(3)?),
                    "risks_and_constraints": parse_json_array_strings(&row.get::<_, String>(4)?),
                    "initial_delivery_plan": parse_json_array_strings(&row.get::<_, String>(5)?),
                    "feasibility_conclusion": row.get::<_, String>(6)?,
                    "version": row.get::<_, String>(7)?,
                    "report_download_path": row.get::<_, Option<String>>(8)?,
                    "updated_at": relative_label(row.get::<_, i64>(9)?)
                }))
            },
        )
        .optional()
        .map_err(|err| err.to_string())?;

    Ok(row.unwrap_or_else(default_report_draft))
}

fn default_report_draft() -> Value {
    json!({
        "project_name": "待定义",
        "problem_definition": "待补充",
        "target_users": "待补充",
        "core_capabilities": ["待补充"],
        "risks_and_constraints": ["待补充"],
        "initial_delivery_plan": ["待补充"],
        "feasibility_conclusion": "待评估",
        "version": "v0.1",
        "report_download_path": Value::Null,
        "updated_at": "刚刚"
    })
}

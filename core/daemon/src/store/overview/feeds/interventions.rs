use super::super::super::helpers::relative_label;
use super::super::super::{Store, StoreResult};
use serde_json::{json, Value};

pub(super) fn interventions(store: &Store) -> StoreResult<Vec<Value>> {
    let mut stmt = store
        .conn
        .prepare(
            r#"
SELECT id, title, status, current_goal, next_action, updated_at_ms
FROM projects
WHERE status IN ('awaiting_confirmation','blocked','failed')
ORDER BY updated_at_ms DESC
LIMIT 8
"#,
        )
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map([], |row| {
            let status: String = row.get(2)?;
            let priority = if status == "failed" {
                "critical"
            } else {
                "normal"
            };
            Ok(json!({
                "id": row.get::<_, String>(0)?,
                "title": if status == "awaiting_confirmation" { "等待确认" } else { "处理阻塞" },
                "project_name": row.get::<_, String>(1)?,
                "reason": row.get::<_, String>(3)?,
                "next_action": row.get::<_, String>(4)?,
                "priority": priority,
                "updated_at": relative_label(row.get::<_, i64>(5)?)
            }))
        })
        .map_err(|err| err.to_string())?;

    let mut out = Vec::new();
    for row in rows {
        out.push(row.map_err(|err| err.to_string())?);
    }
    Ok(out)
}

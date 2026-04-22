use super::super::super::helpers::relative_label;
use super::super::super::{Store, StoreResult};
use serde_json::{json, Value};

pub(super) fn managed_alerts(store: &Store) -> StoreResult<Vec<Value>> {
    let mut stmt = store
        .conn
        .prepare(
            r#"
SELECT id, title, status, block_reason, next_action, updated_at_ms
FROM projects
WHERE status IN ('blocked','failed')
ORDER BY updated_at_ms DESC
LIMIT 5
"#,
        )
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map([], |row| {
            let status: String = row.get(2)?;
            let level = if status == "failed" {
                "critical"
            } else {
                "warning"
            };
            Ok(json!({
                "id": row.get::<_, String>(0)?,
                "title": if status == "failed" { "执行失败" } else { "执行阻塞" },
                "project_name": row.get::<_, String>(1)?,
                "reason": row.get::<_, Option<String>>(3)?.unwrap_or_else(|| "阶段执行受阻".to_string()),
                "next_action": row.get::<_, String>(4)?,
                "level": level,
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

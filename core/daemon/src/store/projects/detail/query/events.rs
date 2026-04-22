use super::super::super::super::helpers::hhmm_label;
use super::super::super::super::{Store, StoreResult};
use rusqlite::params;
use serde_json::{json, Value};

pub(in crate::store::projects::detail) fn list_stage_events(
    store: &Store,
    project_id: &str,
    stage: &str,
) -> StoreResult<Vec<Value>> {
    let mut stmt = store
        .conn
        .prepare(
            r#"
SELECT id, title, detail, created_at_ms
FROM stage_events
WHERE project_id = ?1 AND stage = ?2
ORDER BY created_at_ms DESC
LIMIT 20
"#,
        )
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map(params![project_id, stage], |row| {
            let created_at_ms: i64 = row.get(3)?;
            Ok(json!({
                "id": row.get::<_, String>(0)?,
                "title": row.get::<_, String>(1)?,
                "detail": row.get::<_, String>(2)?,
                "time": hhmm_label(created_at_ms),
                "created_at_ms": created_at_ms
            }))
        })
        .map_err(|err| err.to_string())?;

    let mut out = Vec::new();
    for row in rows {
        out.push(row.map_err(|err| err.to_string())?);
    }
    Ok(out)
}

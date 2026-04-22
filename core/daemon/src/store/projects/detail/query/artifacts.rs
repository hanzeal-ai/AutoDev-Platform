use super::super::super::super::helpers::relative_label;
use super::super::super::super::{Store, StoreResult};
use rusqlite::params;
use serde_json::{json, Value};

pub(in crate::store::projects::detail) fn list_stage_artifacts(
    store: &Store,
    project_id: &str,
    stage: &str,
) -> StoreResult<Vec<Value>> {
    let mut stmt = store
        .conn
        .prepare(
            r#"
SELECT id, name, kind, updated_at_ms, file_path
FROM stage_artifacts
WHERE project_id = ?1 AND stage = ?2
ORDER BY updated_at_ms DESC
"#,
        )
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map(params![project_id, stage], |row| {
            let updated_at_ms: i64 = row.get(3)?;
            Ok(json!({
                "id": row.get::<_, String>(0)?,
                "name": row.get::<_, String>(1)?,
                "kind": row.get::<_, String>(2)?,
                "updated_at": relative_label(updated_at_ms),
                "updated_at_ms": updated_at_ms,
                "file_path": row.get::<_, Option<String>>(4)?
            }))
        })
        .map_err(|err| err.to_string())?;

    let mut out = Vec::new();
    for row in rows {
        out.push(row.map_err(|err| err.to_string())?);
    }
    Ok(out)
}

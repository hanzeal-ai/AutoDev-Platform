use super::super::helpers::relative_label;
use super::super::{Store, StoreResult};
use rusqlite::params;
use serde_json::{json, Value};

pub(super) fn list_thread_materials(store: &Store, thread_id: &str) -> StoreResult<Vec<Value>> {
    let mut stmt = store
        .conn
        .prepare(
            r#"
SELECT id, name, type_hint, size_hint, analysis_status, added_at_ms, blob_path
FROM materials
WHERE thread_id = ?1
ORDER BY added_at_ms DESC
"#,
        )
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map(params![thread_id], |row| {
            let added_at_ms: i64 = row.get(5)?;
            Ok(json!({
                "id": row.get::<_, String>(0)?,
                "name": row.get::<_, String>(1)?,
                "type_hint": row.get::<_, String>(2)?,
                "size_hint": row.get::<_, String>(3)?,
                "status": row.get::<_, String>(4)?,
                "added_at": relative_label(added_at_ms),
                "added_at_ms": added_at_ms,
                "download_path": row.get::<_, Option<String>>(6)?
            }))
        })
        .map_err(|err| err.to_string())?;

    let mut out = Vec::new();
    for row in rows {
        out.push(row.map_err(|err| err.to_string())?);
    }
    Ok(out)
}

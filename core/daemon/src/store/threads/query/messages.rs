use super::super::super::helpers::relative_label;
use super::super::super::{Store, StoreResult};
use rusqlite::params;
use serde_json::{json, Value};

pub(super) fn list_thread_messages(store: &Store, thread_id: &str) -> StoreResult<Vec<Value>> {
    let mut stmt = store
        .conn
        .prepare(
            r#"
SELECT id, role, content, created_at_ms
FROM creation_messages
WHERE thread_id = ?1
ORDER BY created_at_ms ASC
"#,
        )
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map(params![thread_id], |row| {
            let created_at_ms: i64 = row.get(3)?;
            Ok(json!({
                "id": row.get::<_, String>(0)?,
                "role": row.get::<_, String>(1)?,
                "content": row.get::<_, String>(2)?,
                "timestamp": relative_label(created_at_ms),
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

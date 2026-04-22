use super::super::super::helpers::relative_label;
use super::super::super::{Store, StoreResult};
use super::messages::list_thread_messages;
use rusqlite::params;
use serde_json::{json, Value};

pub(super) fn list_creation_threads(store: &Store) -> StoreResult<Value> {
    let mut stmt = store
        .conn
        .prepare(
            r#"
SELECT id, title, is_archived, linked_project_id, lifecycle_stage, last_updated_ms
FROM creation_threads
ORDER BY is_archived ASC, last_updated_ms DESC
"#,
        )
        .map_err(|err| err.to_string())?;

    let rows = stmt
        .query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, i64>(2)? != 0,
                row.get::<_, Option<String>>(3)?,
                row.get::<_, String>(4)?,
                row.get::<_, i64>(5)?,
            ))
        })
        .map_err(|err| err.to_string())?;

    let mut threads = Vec::new();
    for row in rows {
        let (thread_id, title, is_archived, linked_project_id, lifecycle_stage, last_updated_ms) =
            row.map_err(|err| err.to_string())?;
        let messages = list_thread_messages(store, &thread_id)?;
        let materials = store.list_thread_materials(&thread_id)?;
        let report_draft = store.thread_report_draft(&thread_id)?;
        threads.push(json!({
            "id": thread_id,
            "title": title,
            "is_archived": is_archived,
            "linked_project_id": linked_project_id,
            "lifecycle_stage": lifecycle_stage,
            "last_updated": relative_label(last_updated_ms),
            "last_updated_ms": last_updated_ms,
            "messages": messages,
            "materials": materials,
            "report_draft": report_draft
        }));
    }

    Ok(json!({ "threads": threads }))
}

pub(super) fn count_threads(store: &Store) -> StoreResult<i64> {
    store
        .conn
        .query_row("SELECT COUNT(*) FROM creation_threads", [], |row| {
            row.get(0)
        })
        .map_err(|err| err.to_string())
}

pub(super) fn touch_thread(store: &Store, thread_id: &str, now: i64) -> StoreResult<()> {
    store
        .conn
        .execute(
            "UPDATE creation_threads SET last_updated_ms = ?1 WHERE id = ?2",
            params![now, thread_id],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

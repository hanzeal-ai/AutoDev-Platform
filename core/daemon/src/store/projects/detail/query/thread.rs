use super::super::super::super::{Store, StoreResult};
use rusqlite::{params, OptionalExtension};

pub(in crate::store::projects::detail) fn linked_thread_id(
    store: &Store,
    project_id: &str,
) -> StoreResult<Option<String>> {
    store
        .conn
        .query_row(
            "SELECT id FROM creation_threads WHERE linked_project_id = ?1 ORDER BY last_updated_ms DESC LIMIT 1",
            params![project_id],
            |row| row.get(0),
        )
        .optional()
        .map_err(|err| err.to_string())
}

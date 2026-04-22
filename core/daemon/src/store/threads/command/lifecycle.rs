use super::super::super::helpers::now_ms;
use super::super::super::{Store, StoreResult};
use rusqlite::params;
use serde_json::{json, Value};

impl Store {
    pub fn rename_creation_thread(&self, thread_id: &str, title: &str) -> StoreResult<Value> {
        let now = now_ms();
        self.conn
            .execute(
                "UPDATE creation_threads SET title = ?1, last_updated_ms = ?2 WHERE id = ?3",
                params![title, now, thread_id],
            )
            .map_err(|err| err.to_string())?;
        Ok(json!({ "thread_id": thread_id }))
    }

    pub fn archive_creation_thread(&self, thread_id: &str) -> StoreResult<Value> {
        let now = now_ms();
        self.conn
            .execute(
                "UPDATE creation_threads SET is_archived = 1, last_updated_ms = ?1 WHERE id = ?2",
                params![now, thread_id],
            )
            .map_err(|err| err.to_string())?;
        Ok(json!({ "thread_id": thread_id }))
    }

    pub fn delete_creation_thread(&self, thread_id: &str) -> StoreResult<Value> {
        self.conn
            .execute(
                "DELETE FROM creation_threads WHERE id = ?1",
                params![thread_id],
            )
            .map_err(|err| err.to_string())?;
        Ok(json!({ "thread_id": thread_id }))
    }
}

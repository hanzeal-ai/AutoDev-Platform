use super::super::super::helpers::now_ms;
use super::super::super::{Store, StoreResult};
use crate::logger;
use rusqlite::{params, OptionalExtension};
use serde_json::{json, Value};
use uuid::Uuid;

impl Store {
    pub fn add_creation_message(&self, thread_id: &str, content: &str) -> StoreResult<Value> {
        self.ensure_active_creation_thread(thread_id)?;

        let now = now_ms();
        self.conn
            .execute(
                "INSERT INTO creation_messages (id, thread_id, role, content, created_at_ms) VALUES (?1, ?2, 'user', ?3, ?4)",
                params![Uuid::new_v4().to_string(), thread_id, content, now],
            )
            .map_err(|err| err.to_string())?;

        let ai_turn = match self.generate_clarification_turn(thread_id, content) {
            Ok(turn) => turn,
            Err(err) => {
                logger::error_fields(
                    "add_creation_message failed",
                    &[
                        ("thread_id", thread_id.to_string()),
                        ("reason", err.clone()),
                        ("user_message", content.to_string()),
                    ],
                );
                return Err(err);
            }
        };
        let assistant_message = ai_turn.assistant_message;
        let report_patch = ai_turn.report_patch;
        self.conn
            .execute(
                "INSERT INTO creation_messages (id, thread_id, role, content, created_at_ms) VALUES (?1, ?2, 'ai', ?3, ?4)",
                params![Uuid::new_v4().to_string(), thread_id, assistant_message, now],
            )
            .map_err(|err| err.to_string())?;

        self.update_report_from_patch(thread_id, &report_patch, now)?;
        self.touch_thread(thread_id, now)?;
        Ok(json!({
            "thread_id": thread_id,
            "assistant_message": assistant_message,
            "report_draft": self.thread_report_draft(thread_id)?
        }))
    }

    fn ensure_active_creation_thread(&self, thread_id: &str) -> StoreResult<()> {
        let archived_flag: Option<i64> = self
            .conn
            .query_row(
                "SELECT is_archived FROM creation_threads WHERE id = ?1",
                params![thread_id],
                |row| row.get(0),
            )
            .optional()
            .map_err(|err| err.to_string())?;

        match archived_flag {
            Some(0) => Ok(()),
            Some(_) => Err("当前线程已归档或失效，请刷新线程列表后重试。".to_string()),
            None => Err("当前线程不存在或已失效，请刷新线程列表后重试。".to_string()),
        }
    }
}

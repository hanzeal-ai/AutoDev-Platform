use super::super::super::helpers::{now_ms, to_json_string};
use super::super::super::{Store, StoreResult};
use rusqlite::params;
use serde_json::{json, Value};
use uuid::Uuid;

impl Store {
    pub fn create_creation_thread(&self) -> StoreResult<Value> {
        let now = now_ms();
        let thread_id = Uuid::new_v4().to_string();
        let index = self.count_threads()? + 1;
        let title = format!("新建线程 #{index:02}");
        self.conn
            .execute(
                r#"
INSERT INTO creation_threads (id, title, is_archived, linked_project_id, lifecycle_stage, last_updated_ms, created_at_ms)
VALUES (?1, ?2, 0, NULL, 'feasibility', ?3, ?4)
"#,
                params![thread_id, title, now, now],
            )
            .map_err(|err| format!("failed to create thread {}: {}", thread_id, err))?;

        self.conn
            .execute(
                r#"
INSERT INTO feasibility_reports (
  thread_id, project_name, problem_definition, target_users, core_capabilities_json,
  risks_constraints_json, delivery_plan_json, feasibility_conclusion, version, report_file_path, updated_at_ms
) VALUES (?1, '待定义', '待补充', '待补充', ?2, ?3, ?4, '待评估', 'v0.1', NULL, ?5)
"#,
                params![
                    thread_id,
                    to_json_string(&vec!["待补充"]),
                    to_json_string(&vec!["待补充"]),
                    to_json_string(&vec!["待补充"]),
                    now
                ],
            )
            .map_err(|err| err.to_string())?;

        self.conn
            .execute(
                "INSERT INTO creation_messages (id, thread_id, role, content, created_at_ms) VALUES (?1, ?2, 'ai', ?3, ?4)",
                params![
                    Uuid::new_v4().to_string(),
                    thread_id,
                    "新线程已建立。请先描述你想交付的系统目标。",
                    now
                ],
            )
            .map_err(|err| err.to_string())?;

        Ok(json!({ "thread_id": thread_id }))
    }
}

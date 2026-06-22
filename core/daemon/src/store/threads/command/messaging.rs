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
                params![Uuid::new_v4().to_string(), &thread_id, content, now],
            )
            .map_err(|err| err.to_string())?;

        let (project_id, project_title) =
            self.ensure_workflow_project_for_thread(thread_id, content, now)?;
        let assistant_message = workflow_started_message(&project_title);
        self.conn
            .execute(
                "INSERT INTO creation_messages (id, thread_id, role, content, created_at_ms) VALUES (?1, ?2, 'ai', ?3, ?4)",
                params![Uuid::new_v4().to_string(), &thread_id, assistant_message, now],
            )
            .map_err(|err| err.to_string())?;

        self.touch_thread(thread_id, now)?;
        Ok(json!({
            "thread_id": thread_id,
            "assistant_message": assistant_message,
            "report_draft": self.thread_report_draft(thread_id)?,
            "project_id": project_id
        }))
    }

    /// Streaming variant of add_creation_message.
    /// Calls on_delta for each streaming text chunk from the AI worker.
    /// After streaming completes, inserts the AI message to DB and returns final result.
    pub fn add_creation_message_streaming<F>(
        &self,
        thread_id: &str,
        content: &str,
        mut on_delta: F,
    ) -> StoreResult<Value>
    where
        F: FnMut(&str) -> StoreResult<()>,
    {
        let thread_id = thread_id.to_lowercase();
        self.ensure_active_creation_thread(&thread_id)?;

        // Open a SAVEPOINT so that if the AI call fails, the user message
        // INSERT is rolled back and the thread stays consistent.
        self.conn
            .execute("SAVEPOINT sp_streaming_msg", [])
            .map_err(|err| err.to_string())?;

        let user_now = now_ms();
        let insert_user = self.conn.execute(
            "INSERT INTO creation_messages (id, thread_id, role, content, created_at_ms) VALUES (?1, ?2, 'user', ?3, ?4)",
            params![Uuid::new_v4().to_string(), thread_id, content, user_now],
        );
        if let Err(err) = insert_user {
            let _ = self
                .conn
                .execute("ROLLBACK TO SAVEPOINT sp_streaming_msg", []);
            let _ = self.conn.execute("RELEASE SAVEPOINT sp_streaming_msg", []);
            return Err(err.to_string());
        }

        let (project_id, project_title) =
            match self.ensure_workflow_project_for_thread(&thread_id, content, user_now) {
                Ok(project) => project,
                Err(err) => {
                    logger::error_fields(
                        "add_creation_message_streaming project setup failed",
                        &[
                            ("thread_id", thread_id.clone()),
                            ("reason", err.clone()),
                            ("user_message", content.to_string()),
                        ],
                    );
                    let _ = self
                        .conn
                        .execute("ROLLBACK TO SAVEPOINT sp_streaming_msg", []);
                    let _ = self.conn.execute("RELEASE SAVEPOINT sp_streaming_msg", []);
                    return Err(err);
                }
            };
        let assistant_message = workflow_started_message(&project_title);

        // Use a fresh timestamp so the AI message time reflects when
        // workflow dispatch finished, not when the user sent the message.
        let ai_now = now_ms();
        let insert_ai = self.conn.execute(
            "INSERT INTO creation_messages (id, thread_id, role, content, created_at_ms) VALUES (?1, ?2, 'ai', ?3, ?4)",
            params![Uuid::new_v4().to_string(), thread_id, assistant_message, ai_now],
        );
        if let Err(err) = insert_ai {
            let _ = self
                .conn
                .execute("ROLLBACK TO SAVEPOINT sp_streaming_msg", []);
            let _ = self.conn.execute("RELEASE SAVEPOINT sp_streaming_msg", []);
            return Err(err.to_string());
        }

        // All writes succeeded — commit the savepoint.
        self.conn
            .execute("RELEASE SAVEPOINT sp_streaming_msg", [])
            .map_err(|err| err.to_string())?;

        self.touch_thread(&thread_id, ai_now)?;
        let _ = on_delta("可行性报告已准备好，确认后将从 PRD 阶段进入 workflow。");
        Ok(json!({
            "thread_id": thread_id,
            "assistant_message": assistant_message,
            "report_draft": self.thread_report_draft(&thread_id)?,
            "project_id": project_id
        }))
    }

    fn ensure_workflow_project_for_thread(
        &self,
        thread_id: &str,
        user_message: &str,
        now: i64,
    ) -> StoreResult<(String, String)> {
        let linked: Option<(String, String)> = self
            .conn
            .query_row(
                r#"
SELECT p.id, p.title
FROM creation_threads t
JOIN projects p ON p.id = t.linked_project_id
WHERE t.id = ?1
"#,
                params![thread_id],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .optional()
            .map_err(|err| err.to_string())?;
        if let Some((project_id, project_title)) = linked {
            self.seed_workflow_report_draft(thread_id, &project_title, user_message, now)?;
            return Ok((project_id, project_title));
        }

        let project_id = Uuid::new_v4().to_string();
        let project_title = workflow_project_title(user_message);
        self.seed_workflow_report_draft(thread_id, &project_title, user_message, now)?;
        self.conn
            .execute(
                r#"
INSERT INTO projects (
  id, title, current_phase, lifecycle_stage, progress, current_goal, next_action,
  risk, block_reason, status, owner, updated_at_ms, created_at_ms
) VALUES (?1, ?2, 'Workflow', 'prd', 0.05, ?3, ?4, 'medium', NULL, 'awaiting_confirmation', '系统代理', ?5, ?6)
"#,
                params![
                    project_id,
                    project_title,
                    "可行性报告已准备好，等待确认进入 PRD",
                    "确认可行性报告后启动 PRD workflow",
                    now,
                    now
                ],
            )
            .map_err(|err| err.to_string())?;
        self.conn
            .execute(
            "UPDATE creation_threads SET linked_project_id = ?1, lifecycle_stage = 'feasibility', last_updated_ms = ?2 WHERE id = ?3",
                params![project_id, now, thread_id],
            )
            .map_err(|err| err.to_string())?;
        Ok((project_id, project_title))
    }

    fn seed_workflow_report_draft(
        &self,
        thread_id: &str,
        project_title: &str,
        user_message: &str,
        now: i64,
    ) -> StoreResult<()> {
        self.conn
            .execute(
                r#"
UPDATE feasibility_reports
SET project_name = ?1,
    problem_definition = ?2,
    feasibility_conclusion = '可行性报告已准备好，确认后进入 PRD Workflow',
    updated_at_ms = ?3
WHERE thread_id = ?4
"#,
                params![project_title, user_message, now, thread_id],
            )
            .map_err(|err| err.to_string())?;
        Ok(())
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

fn workflow_project_title(user_message: &str) -> String {
    let title = user_message
        .lines()
        .find(|line| !line.trim().is_empty())
        .unwrap_or("新项目")
        .trim()
        .chars()
        .take(32)
        .collect::<String>();
    if title.is_empty() {
        "新项目".to_string()
    } else {
        title
    }
}

fn workflow_started_message(project_title: &str) -> String {
    format!(
        "已创建项目「{}」并生成可行性报告草稿。确认后将进入 Workflow，并从 PRD 阶段开始推进。",
        project_title
    )
}

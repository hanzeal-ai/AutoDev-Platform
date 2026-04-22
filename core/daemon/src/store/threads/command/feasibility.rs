use super::super::super::helpers::now_ms;
use super::super::super::{Store, StoreResult};
use crate::logger;
use rusqlite::{params, OptionalExtension};
use serde_json::{json, Value};
use uuid::Uuid;

impl Store {
    pub fn confirm_feasibility(&self, thread_id: &str) -> StoreResult<Value> {
        let now = now_ms();
        let linked_project_id: Option<String> = self
            .conn
            .query_row(
                "SELECT linked_project_id FROM creation_threads WHERE id = ?1",
                params![thread_id],
                |row| row.get(0),
            )
            .optional()
            .map_err(|err| err.to_string())?
            .flatten();

        let project_id = if let Some(project_id) = linked_project_id {
            project_id
        } else {
            let final_report = self.generate_final_report(thread_id)?;
            self.persist_report(thread_id, &final_report, now)?;

            let project_name = final_report
                .get("project_name")
                .and_then(Value::as_str)
                .filter(|name| !name.trim().is_empty() && *name != "待定义")
                .unwrap_or("新项目");
            let project_id = Uuid::new_v4().to_string();
            self.conn
                .execute(
                    r#"
INSERT INTO projects (
  id, title, current_phase, lifecycle_stage, progress, current_goal, next_action,
  risk, block_reason, status, owner, updated_at_ms, created_at_ms
) VALUES (?1, ?2, 'PRD', 'prd', 0.12, ?3, ?4, 'medium', NULL, 'awaiting_confirmation', '系统代理', ?5, ?6)
"#,
                    params![
                        project_id,
                        project_name,
                        "冻结 PRD 范围边界、功能拆分与验收标准",
                        "确认验收标准并进入 UI 阶段",
                        now,
                        now
                    ],
                )
                .map_err(|err| err.to_string())?;
            project_id
        };

        self.conn
            .execute(
                r#"
INSERT INTO project_stages (
  project_id, stage, objective, input_contexts_json, step_progress_json,
  risk_items_json, event_flow_json, primary_action, secondary_actions_json, updated_at_ms
) VALUES (?1, 'prd', ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
ON CONFLICT(project_id, stage) DO UPDATE SET
  objective = excluded.objective,
  input_contexts_json = excluded.input_contexts_json,
  step_progress_json = excluded.step_progress_json,
  risk_items_json = excluded.risk_items_json,
  event_flow_json = excluded.event_flow_json,
  primary_action = excluded.primary_action,
  secondary_actions_json = excluded.secondary_actions_json,
  updated_at_ms = excluded.updated_at_ms
"#,
                params![
                    project_id,
                    "",
                    "[]",
                    "[]",
                    "[]",
                    "[]",
                    "",
                    "[]",
                    now
                ],
            )
            .map_err(|err| err.to_string())?;

        self.conn
            .execute(
                r#"
INSERT INTO stage_events (id, project_id, stage, title, detail, created_at_ms)
VALUES (?1, ?2, 'prd', '立项已确认', '系统已根据可行性报告创建项目并进入 PRD 阶段。', ?3)
"#,
                params![Uuid::new_v4().to_string(), project_id, now],
            )
            .map_err(|err| err.to_string())?;

        self.conn
            .execute(
                "UPDATE creation_threads SET lifecycle_stage = 'prd', linked_project_id = ?1, last_updated_ms = ?2 WHERE id = ?3",
                params![project_id, now, thread_id],
            )
            .map_err(|err| err.to_string())?;

        self.conn
            .execute(
                "INSERT INTO creation_messages (id, thread_id, role, content, created_at_ms) VALUES (?1, ?2, 'ai', ?3, ?4)",
                params![
                    Uuid::new_v4().to_string(),
                    thread_id,
                    "已确认可行性报告，项目已进入 PRD 阶段，我将继续输出功能边界与验收标准。",
                    now
                ],
            )
            .map_err(|err| err.to_string())?;

        self.conn
            .execute(
                r#"
UPDATE projects
SET lifecycle_stage = 'prd', current_phase = 'PRD', status = 'awaiting_confirmation',
    updated_at_ms = ?1, progress = CASE WHEN progress < 0.12 THEN 0.12 ELSE progress END
WHERE id = ?2
"#,
                params![now, project_id],
            )
            .map_err(|err| err.to_string())?;

        if let Err(reason) = self.generate_project_stage_ai(&project_id, Some("prd")) {
            logger::error_fields(
                "auto prd ai trigger failed",
                &[
                    ("project_id", project_id.clone()),
                    ("stage", "prd".to_string()),
                    ("reason", reason),
                ],
            );
        }

        Ok(json!({
            "thread_id": thread_id,
            "project_id": project_id
        }))
    }
}

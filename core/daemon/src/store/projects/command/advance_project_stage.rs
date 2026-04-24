use super::super::super::helpers::{now_ms, to_json_string};
use super::super::super::lifecycle::LifecycleStage;
use super::super::super::{StageDefaults, Store, StoreResult};
use crate::logger;
use rusqlite::params;
use serde_json::{json, Value};

impl Store {
    pub fn advance_project_stage(
        &self,
        project_id: &str,
        action: Option<&str>,
        auto_trigger_ai: bool,
    ) -> StoreResult<Value> {
        let project_id = project_id.trim().to_lowercase();
        let now = now_ms();
        let (title, current_stage_str): (String, String) = self
            .conn
            .query_row(
                "SELECT title, lifecycle_stage FROM projects WHERE id = ?1",
                params![&project_id],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .map_err(|err| err.to_string())?;

        let current_stage = LifecycleStage::from_str(&current_stage_str)
            .ok_or_else(|| format!("unknown lifecycle stage: {current_stage_str}"))?;

        let Some(next) = current_stage.next() else {
            self.mark_project_completed(&project_id, current_stage, now)?;
            return Ok(json!({
                "project_id": project_id,
                "stage": current_stage.as_str(),
                "status": "completed",
                "action": action.unwrap_or("complete")
            }));
        };

        self.mark_stage_completed(&project_id, current_stage, now)?;
        self.upsert_next_stage(&project_id, next, now)?;

        self.conn
            .execute(
                r#"
UPDATE projects
SET lifecycle_stage = ?2,
    current_phase = ?3,
    progress = ?4,
    current_goal = ?5,
    next_action = ?6,
    status = 'awaiting_confirmation',
    updated_at_ms = ?7,
    block_reason = NULL
WHERE id = ?1
"#,
                params![
                    &project_id,
                    next.as_str(),
                    next.label(),
                    next.progress(),
                    next.goal(),
                    next.next_action(),
                    now,
                ],
            )
            .map_err(|err| err.to_string())?;

        self.conn
            .execute(
                "INSERT INTO stage_events (id, project_id, stage, title, detail, created_at_ms) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
                params![
                    format!("{}-{}-advance", project_id, now),
                    &project_id,
                    next.as_str(),
                    "阶段已进入",
                    format!("{} 已进入 {}", title, next.label()),
                    now,
                ],
            )
            .map_err(|err| err.to_string())?;

        if auto_trigger_ai {
            if let Err(reason) = self.generate_project_stage_ai(&project_id, Some(next.as_str()), None) {
                logger::error_fields(
                    "auto stage ai trigger failed",
                    &[
                        ("project_id", project_id.clone()),
                        ("stage", next.as_str().to_string()),
                        ("reason", reason),
                    ],
                );
            }
        }

        Ok(json!({
            "project_id": project_id,
            "stage": next.as_str(),
            "previous_stage": current_stage.as_str(),
            "status": "awaiting_confirmation",
            "action": action.unwrap_or("advance")
        }))
    }

    fn mark_project_completed(&self, project_id: &str, stage: LifecycleStage, now: i64) -> StoreResult<()> {
        self.mark_stage_completed(project_id, stage, now)?;
        self.conn
            .execute(
                r#"
UPDATE projects
SET status = 'completed',
    progress = 1.0,
    current_goal = '项目生命周期已完成',
    next_action = '查看产物与归档',
    updated_at_ms = ?2,
    block_reason = NULL
WHERE id = ?1
"#,
                params![project_id, now],
            )
            .map_err(|err| err.to_string())?;
        Ok(())
    }

    fn mark_stage_completed(&self, project_id: &str, stage: LifecycleStage, now: i64) -> StoreResult<()> {
        let defaults = stage.defaults();
        self.conn
            .execute(
                r#"
INSERT INTO project_stages (
  project_id, stage, objective, input_contexts_json, step_progress_json,
  risk_items_json, event_flow_json, primary_action, secondary_actions_json,
  downloads_json, work_units_json, updated_at_ms
) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, '', '[]', ?8, ?9, ?10)
ON CONFLICT(project_id, stage) DO UPDATE SET
  step_progress_json = excluded.step_progress_json,
  primary_action = '',
  secondary_actions_json = '[]',
  updated_at_ms = excluded.updated_at_ms
"#,
                params![
                    project_id,
                    stage.as_str(),
                    defaults.objective,
                    to_json_string(&defaults.input_contexts),
                    to_json_string(&completed_steps(&defaults)),
                    to_json_string(&defaults.risk_items),
                    to_json_string(&defaults.event_flow),
                    to_json_string(&downloads_json(&defaults, now)),
                    to_json_string(&work_units_json(&defaults)),
                    now,
                ],
            )
            .map_err(|err| err.to_string())?;
        Ok(())
    }

    fn upsert_next_stage(&self, project_id: &str, stage: LifecycleStage, now: i64) -> StoreResult<()> {
        self.conn
            .execute(
                r#"
INSERT INTO project_stages (
  project_id, stage, objective, input_contexts_json, step_progress_json,
  risk_items_json, event_flow_json, primary_action, secondary_actions_json,
  downloads_json, work_units_json, updated_at_ms
) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
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
                    stage.as_str(),
                    "",
                    "[]",
                    "[]",
                    "[]",
                    "[]",
                    "",
                    "[]",
                    "[]",
                    "[]",
                    now,
                ],
            )
            .map_err(|err| err.to_string())?;
        Ok(())
    }
}

fn completed_steps(defaults: &StageDefaults) -> Value {
    defaults
        .step_progress
        .as_array()
        .map(|items| {
            Value::Array(
                items
                    .iter()
                    .map(|item| {
                        let mut copy = item.clone();
                        if let Some(obj) = copy.as_object_mut() {
                            obj.insert(
                                "status".to_string(),
                                Value::String("completed".to_string()),
                            );
                        }
                        copy
                    })
                    .collect(),
            )
        })
        .unwrap_or_else(|| defaults.step_progress.clone())
}

fn downloads_json(defaults: &StageDefaults, now: i64) -> Vec<Value> {
    defaults
        .downloads
        .iter()
        .map(|item| {
            json!({
                "id": item.id,
                "title": item.title,
                "category": item.category,
                "availability": item.availability,
                "file_path": item.file_path,
                "updated_at_ms": item.updated_at_ms.unwrap_or(now),
                "content_type": item.content_type
            })
        })
        .collect()
}

fn work_units_json(defaults: &StageDefaults) -> Vec<Value> {
    defaults
        .work_units
        .iter()
        .map(|item| {
            json!({
                "id": item.id,
                "title": item.title,
                "agent_role": item.agent_role,
                "status": item.status,
                "progress": item.progress,
                "depends_on": item.depends_on,
                "current_output": item.current_output,
                "next_step": item.next_step,
                "downloads": []
            })
        })
        .collect()
}

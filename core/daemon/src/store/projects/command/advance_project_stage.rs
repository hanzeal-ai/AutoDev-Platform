use super::super::super::helpers::{now_ms, stage_defaults, to_json_string};
use super::super::super::{StageDefaults, Store, StoreResult};
use crate::logger;
use rusqlite::params;
use serde_json::{json, Value};

impl Store {
    pub fn advance_project_stage(
        &self,
        project_id: &str,
        action: Option<&str>,
    ) -> StoreResult<Value> {
        let project_id = project_id.trim().to_lowercase();
        let now = now_ms();
        let (title, current_stage): (String, String) = self
            .conn
            .query_row(
                "SELECT title, lifecycle_stage FROM projects WHERE id = ?1",
                params![&project_id],
                |row| Ok((row.get(0)?, row.get(1)?)),
            )
            .map_err(|err| err.to_string())?;

        let Some(next_stage) = next_stage(&current_stage) else {
            self.mark_project_completed(&project_id, &current_stage, now)?;
            return Ok(json!({
                "project_id": project_id,
                "stage": current_stage,
                "status": "completed",
                "action": action.unwrap_or("complete")
            }));
        };

        self.mark_stage_completed(&project_id, &current_stage, now)?;
        self.upsert_next_stage(&project_id, next_stage, now)?;

        let next_label = stage_label(next_stage);
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
                    next_stage,
                    next_label,
                    stage_progress(next_stage),
                    stage_goal(next_stage),
                    stage_next_action(next_stage),
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
                    next_stage,
                    "阶段已进入",
                    format!("{} 已进入 {}", title, next_label),
                    now,
                ],
            )
            .map_err(|err| err.to_string())?;

        if let Err(reason) = self.generate_project_stage_ai(&project_id, Some(next_stage)) {
            logger::error_fields(
                "auto stage ai trigger failed",
                &[
                    ("project_id", project_id.clone()),
                    ("stage", next_stage.to_string()),
                    ("reason", reason),
                ],
            );
        }

        Ok(json!({
            "project_id": project_id,
            "stage": next_stage,
            "previous_stage": current_stage,
            "status": "awaiting_confirmation",
            "action": action.unwrap_or("advance")
        }))
    }

    fn mark_project_completed(&self, project_id: &str, stage: &str, now: i64) -> StoreResult<()> {
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

    fn mark_stage_completed(&self, project_id: &str, stage: &str, now: i64) -> StoreResult<()> {
        let defaults = stage_defaults(stage);
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
                    stage,
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

    fn upsert_next_stage(&self, project_id: &str, stage: &str, now: i64) -> StoreResult<()> {
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
                    stage,
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

fn next_stage(stage: &str) -> Option<&'static str> {
    match stage {
        "feasibility" => Some("prd"),
        "prd" => Some("ui"),
        "ui" => Some("development"),
        "development" => Some("testing"),
        "testing" => Some("release"),
        "release" => Some("maintenance"),
        _ => None,
    }
}

fn stage_label(stage: &str) -> &'static str {
    match stage {
        "prd" => "PRD",
        "ui" => "UI",
        "development" => "研发",
        "testing" => "测试",
        "release" => "发布",
        "maintenance" => "维护",
        _ => "立项",
    }
}

fn stage_progress(stage: &str) -> f64 {
    match stage {
        "prd" => 0.12,
        "ui" => 0.28,
        "development" => 0.45,
        "testing" => 0.72,
        "release" => 0.9,
        "maintenance" => 1.0,
        _ => 0.08,
    }
}

fn stage_goal(stage: &str) -> &'static str {
    match stage {
        "prd" => "冻结 PRD 范围边界、功能拆分与验收标准",
        "ui" => "完成页面地图、交互流与关键组件定义",
        "development" => "完成前后端任务拆分、编码审查循环与稳定预览交付",
        "testing" => "验证质量门禁并形成发布准入结论",
        "release" => "完成发布准备、执行与回滚保障",
        "maintenance" => "监控运行健康并沉淀下一轮优化建议",
        _ => "完成可行性判断并形成受控立项决策",
    }
}

fn stage_next_action(stage: &str) -> &'static str {
    match stage {
        "prd" => "确认 PRD 后进入 UI 阶段",
        "ui" => "当前联调可跳过 UI 并进入研发阶段",
        "development" => "继续推进研发规划与编码准备",
        "testing" => "确认质量门禁后进入发布阶段",
        "release" => "确认发布后进入维护阶段",
        "maintenance" => "查看维护记录与归档",
        _ => "确认立项",
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

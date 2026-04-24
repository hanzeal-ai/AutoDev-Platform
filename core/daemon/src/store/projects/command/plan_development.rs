use super::super::super::helpers::{ensure_parent_dir, now_ms, to_json_string};
use crate::store::{Store, StoreResult};
use rusqlite::params;
use serde_json::{json, Value};
use std::fs;
use std::path::PathBuf;
use uuid::Uuid;

use super::plan_development_templates::{DevelopmentArtifactSpec, render_frontend_tasks, render_backend_tasks, render_api_contract};

impl Store {
    pub fn plan_development(&self, project_id: &str) -> StoreResult<Value> {
        let project_id = project_id.trim().to_lowercase();
        if project_id.is_empty() {
            return Err("project_id must not be empty".to_string());
        }

        self.conn.execute_batch("BEGIN TRANSACTION")
            .map_err(|err| format!("begin transaction failed (plan_development, project={}): {}", project_id, err))?;

        match self.plan_development_inner(&project_id) {
            Ok(result) => {
                self.conn.execute_batch("COMMIT")
                    .map_err(|err| format!("commit failed (plan_development, project={}): {}", project_id, err))?;
                Ok(result)
            }
            Err(e) => {
                let _ = self.conn.execute_batch("ROLLBACK");
                Err(e)
            }
        }
    }

    fn plan_development_inner(&self, project_id: &str) -> StoreResult<Value> {
        let now = now_ms();
        let project_name = self.load_project_name(&project_id)?;
        let stage = "development";
        let artifact_dir = self
            .paths
            .blobs_dir()
            .join("stage_artifacts")
            .join(&project_id)
            .join(stage);

        // Clean up old blob files before deleting DB records
        {
            let mut stmt = self
                .conn
                .prepare("SELECT file_path FROM stage_artifacts WHERE project_id = ?1 AND stage = ?2")
                .map_err(|err| err.to_string())?;
            let old_paths: Vec<String> = stmt
                .query_map(params![&project_id, stage], |row| row.get::<_, String>(0))
                .map_err(|err| err.to_string())?
                .filter_map(|r| r.ok())
                .filter(|p| !p.is_empty())
                .collect();
            for path in &old_paths {
                let _ = fs::remove_file(path);
            }
        }

        self.conn
            .execute(
                "DELETE FROM stage_artifacts WHERE project_id = ?1 AND stage = ?2",
                params![&project_id, stage],
            )
            .map_err(|err| err.to_string())?;

        let artifact_specs = self.development_artifact_specs(&project_name, now, &project_id);
        let mut downloads = Vec::new();
        let mut artifact_count = 0_usize;

        for spec in artifact_specs {
            let file_path = artifact_dir.join(spec.file_name);
            ensure_parent_dir(&file_path)?;
            fs::write(&file_path, spec.content)
                .map_err(|err| format!("failed to write artifact {}: {}", file_path.display(), err))?;

            self.conn
                .execute(
                    r#"
INSERT INTO stage_artifacts (
  id, project_id, stage, name, kind, updated_at_ms, file_path, content_type
) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
"#,
                    params![
                        Uuid::new_v4().to_string(),
                        &project_id,
                        stage,
                        spec.name,
                        spec.kind,
                        spec.updated_at_ms,
                        file_path.display().to_string(),
                        spec.content_type
                    ],
                )
                .map_err(|err| err.to_string())?;

            downloads.push(json!({
                "id": spec.id,
                "title": spec.title,
                "category": "stage_snapshot",
                "availability": "ready",
                "file_path": file_path.display().to_string(),
                "updated_at_ms": spec.updated_at_ms,
                "content_type": spec.content_type,
            }));
            artifact_count += 1;
        }
        let frontend_download = downloads
            .iter()
            .find(|item| item.get("id").and_then(Value::as_str) == Some("frontend-tasks"))
            .cloned();
        let backend_download = downloads
            .iter()
            .find(|item| item.get("id").and_then(Value::as_str) == Some("backend-tasks"))
            .cloned();
        let api_contract_download = downloads
            .iter()
            .find(|item| item.get("id").and_then(Value::as_str) == Some("api-contract"))
            .cloned();
        let task_split_downloads = [frontend_download, backend_download]
            .into_iter()
            .flatten()
            .collect::<Vec<Value>>();

        let step_progress = json!([
            {"title":"项目输入收敛","status":"completed"},
            {"title":"前端任务拆分生成","status":"completed"},
            {"title":"后端任务拆分与接口契约生成","status":"completed"}
        ]);
        let input_contexts = json!([
            format!("项目名称：{project_name}"),
            "规划输出：frontend-tasks.md".to_string(),
            "规划输出：backend-tasks.md".to_string(),
            "规划输出：api-contract.md".to_string(),
            "落盘位置：stage_artifacts".to_string(),
        ]);
        let risk_items = json!([
            "项目名称信息过少会导致任务拆分过粗",
            "接口契约与任务文件不一致会影响后续实现",
            "后续编码若偏离规划文件会增加返工"
        ]);
        let event_flow = json!([
            "收敛项目名称",
            "生成前端任务拆分",
            "生成后端任务拆分",
            "生成接口契约",
            "写入 stage_artifacts"
        ]);
        let work_units = json!([
            {
                "id": "input-consolidation",
                "title": "项目输入收敛",
                "agent_role": "规划 Agent",
                "status": "completed",
                "progress": 1.0,
                "depends_on": [],
                "current_output": format!("项目名称：{project_name}"),
                "next_step": "已完成",
                "downloads": []
            },
            {
                "id": "frontend-backend-task-split",
                "title": "前后端任务拆分",
                "agent_role": "任务拆分 Agent",
                "status": "completed",
                "progress": 1.0,
                "depends_on": ["input-consolidation", "api-contract"],
                "current_output": "frontend-tasks.md / backend-tasks.md",
                "next_step": "按任务文件进入实现",
                "downloads": task_split_downloads
            },
            {
                "id": "api-contract",
                "title": "接口契约生成",
                "agent_role": "契约规划 Agent",
                "status": "completed",
                "progress": 1.0,
                "depends_on": ["input-consolidation"],
                "current_output": "api-contract.md",
                "next_step": "冻结为实现基线",
                "downloads": api_contract_download.into_iter().collect::<Vec<Value>>()
            }
        ]);
        let downloads_json = to_json_string(&downloads);
        let work_units_json = to_json_string(&work_units);

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
  downloads_json = excluded.downloads_json,
  work_units_json = excluded.work_units_json,
  updated_at_ms = excluded.updated_at_ms
"#,
                params![
                    &project_id,
                    stage,
                    format!("为 {project_name} 生成前后端任务拆分与接口契约"),
                    to_json_string(&input_contexts),
                    to_json_string(&step_progress),
                    to_json_string(&risk_items),
                    to_json_string(&event_flow),
                    "继续实现",
                    to_json_string(&vec!["查看任务拆分", "进入编码"]),
                    downloads_json,
                    work_units_json,
                    now
                ],
            )
            .map_err(|err| err.to_string())?;

        self.conn
            .execute(
                r#"
INSERT INTO stage_events (id, project_id, stage, title, detail, created_at_ms)
VALUES (?1, ?2, ?3, ?4, ?5, ?6)
"#,
                params![
                    Uuid::new_v4().to_string(),
                    &project_id,
                    stage,
                    "研发规划已生成",
                    format!(
                        "系统已根据项目名称 {project_name} 生成 frontend-tasks.md、backend-tasks.md 和 api-contract.md。"
                    ),
                    now
                ],
            )
            .map_err(|err| err.to_string())?;

        self.conn
            .execute(
                r#"
UPDATE projects
SET current_phase = '研发',
    lifecycle_stage = 'development',
    progress = CASE WHEN progress < 0.35 THEN 0.35 ELSE progress END,
    current_goal = ?1,
    next_action = ?2,
    status = 'running',
    updated_at_ms = ?3
WHERE id = ?4
"#,
                params![
                    format!("为 {project_name} 生成前后端任务拆分与接口契约"),
                    "按任务文件开始实现",
                    now,
                    &project_id
                ],
            )
            .map_err(|err| err.to_string())?;

        Ok(json!({
            "project_id": project_id,
            "stage": stage,
            "artifact_count": artifact_count
        }))
    }

    fn load_project_name(&self, project_id: &str) -> StoreResult<String> {
        self.conn
            .query_row(
                "SELECT title FROM projects WHERE id = ?1",
                params![project_id],
                |row| row.get(0),
            )
            .map_err(|err| match err {
                rusqlite::Error::QueryReturnedNoRows => {
                    format!("project not found: {project_id}")
                }
                _ => err.to_string(),
            })
    }

    fn development_artifact_specs(
        &self,
        project_name: &str,
        now: i64,
        project_id: &str,
    ) -> Vec<DevelopmentArtifactSpec> {
        vec![
            DevelopmentArtifactSpec {
                id: "frontend-tasks",
                name: "frontend-tasks.md",
                title: "前端任务拆分",
                kind: "规划文档",
                file_name: PathBuf::from("frontend-tasks.md"),
                content: render_frontend_tasks(project_name),
                content_type: Some("text/markdown"),
                updated_at_ms: now,
            },
            DevelopmentArtifactSpec {
                id: "backend-tasks",
                name: "backend-tasks.md",
                title: "后端任务拆分",
                kind: "规划文档",
                file_name: PathBuf::from("backend-tasks.md"),
                content: render_backend_tasks(project_name),
                content_type: Some("text/markdown"),
                updated_at_ms: now,
            },
            DevelopmentArtifactSpec {
                id: "api-contract",
                name: "api-contract.md",
                title: "接口契约",
                kind: "契约文档",
                file_name: PathBuf::from("api-contract.md"),
                content: render_api_contract(project_name, project_id),
                content_type: Some("text/markdown"),
                updated_at_ms: now,
            },
        ]
    }
}


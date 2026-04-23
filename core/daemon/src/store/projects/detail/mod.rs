mod ai_stage;
mod assemble;
mod query;

use super::super::helpers::{now_ms, risk_priority, stage_defaults, stage_label};
use super::super::{Store, StoreResult};
use crate::logger;
use serde_json::{json, Value};
use std::thread;

impl Store {
    pub fn generate_project_stage_ai(
        &self,
        project_id: &str,
        stage: Option<&str>,
    ) -> StoreResult<Value> {
        let project_id = project_id.trim().to_lowercase();
        let project = query::load_project(self, &project_id)?;
        let active_stage = stage
            .map(ToString::to_string)
            .unwrap_or_else(|| project.lifecycle_stage.clone());
        let active_stage = if active_stage.is_empty() {
            "development".to_string()
        } else {
            active_stage
        };
        let feasibility = self.project_feasibility_context(&project_id)?;
        let defaults = stage_defaults(&active_stage);
        let project_title = if project.title.is_empty() {
            "项目".to_string()
        } else {
            project.title.clone()
        };
        let run_id = ai_stage::create_stage_ai_run(self, &project_id, &active_stage)?;
        let runtime_paths = self.paths.clone();
        let project_id_for_task = project_id.clone();
        let active_stage_for_task = active_stage.clone();
        thread::spawn(move || {
            let store = match Store::open(&runtime_paths) {
                Ok(store) => store,
                Err(reason) => {
                    logger::error_fields(
                        "stage agent store open failed",
                        &[
                            ("project_id", project_id_for_task.clone()),
                            ("stage", active_stage_for_task.clone()),
                            ("reason", reason),
                        ],
                    );
                    return;
                }
            };
            if let Err(reason) = ai_stage::generate_stage_ai_content(
                &store,
                &run_id,
                &project_id_for_task,
                &project_title,
                &active_stage_for_task,
                &defaults,
                feasibility.as_ref(),
            ) {
                logger::error_fields(
                    "stage agent task failed",
                    &[
                        ("project_id", project_id_for_task.clone()),
                        ("stage", active_stage_for_task.clone()),
                        ("reason", reason.clone()),
                    ],
                );
                let _ = store.conn.execute(
                    "UPDATE stage_ai_runs SET status = 'failed', error_message = ?1 WHERE id = ?2",
                    rusqlite::params![reason, run_id],
                );
            }
        });

        Ok(json!({
            "project_id": project_id,
            "stage": active_stage,
            "started": true
        }))
    }

    pub fn get_project_stage_detail(
        &self,
        project_id: &str,
        stage: Option<&str>,
    ) -> StoreResult<Value> {
        let project_id = project_id.trim().to_lowercase();
        let project = query::load_project(self, &project_id)?;
        let active_stage = stage
            .map(ToString::to_string)
            .unwrap_or_else(|| project.lifecycle_stage.clone());
        let active_stage = if active_stage.is_empty() {
            "development".to_string()
        } else {
            active_stage
        };

        let feasibility = self.project_feasibility_context(&project_id)?;

        let defaults = stage_defaults(&active_stage);
        let stage_row = query::load_stage(self, &project_id, &active_stage)?;
        let stage_content = assemble::merge_stage_content(stage_row.as_ref(), &defaults);
        let artifacts = query::list_stage_artifacts(self, &project_id, &active_stage)?;
        let events = query::list_stage_events(self, &project_id, &active_stage)?;
        let ai_run = query::latest_ai_run(self, &project_id, &active_stage)?;

        let updated_at_ms = if project.updated_at_ms > 0 {
            project.updated_at_ms
        } else {
            now_ms()
        };
        let status_raw = if project.status.is_empty() {
            "running"
        } else {
            &project.status
        };
        let risk_raw = if project.risk.is_empty() {
            "medium"
        } else {
            &project.risk
        };

        let detail = assemble::build_detail_payload(assemble::DetailPayloadInput {
            project_id: &project_id,
            project_name: if project.title.is_empty() {
                "项目"
            } else {
                &project.title
            },
            active_stage: &active_stage,
            status_raw,
            risk_raw,
            owner: if project.owner.is_empty() {
                "系统代理"
            } else {
                &project.owner
            },
            updated_at_ms,
            next_action: if project.next_action.is_empty() {
                "继续"
            } else {
                &project.next_action
            },
            progress: project.progress,
            block_reason: project.block_reason.as_deref(),
            stage_content,
            artifacts,
            events,
            ai_run,
            feasibility,
            stage_unit_label: stage_label(&active_stage),
            risk_priority: risk_priority(risk_raw),
        });

        Ok(json!({ "detail": detail }))
    }

    fn project_feasibility_context(&self, project_id: &str) -> StoreResult<Option<Value>> {
        if let Some(thread_id) = query::linked_thread_id(self, project_id)? {
            let report = self.thread_report_draft(&thread_id)?;
            let materials = self.list_thread_materials(&thread_id)?;
            Ok(Some(json!({
                "thread_id": thread_id,
                "report_draft": report,
                "materials": materials
            })))
        } else {
            Ok(None)
        }
    }
}

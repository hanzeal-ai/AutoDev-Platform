mod ai_stage;
mod assemble;
mod query;

use super::super::helpers::{now_ms, risk_priority, stage_defaults, stage_label};
use super::super::reports::llm::worker;
use super::super::{Store, StoreResult};
use crate::logger;
use serde_json::{json, Value};
use std::path::Path;
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

impl Store {
    pub fn run_project_workflow(
        &self,
        project_id: &str,
        feedback: Option<&str>,
        action: Option<&str>,
    ) -> StoreResult<Value> {
        let project_id = project_id.trim().to_lowercase();
        let project = query::load_project(self, &project_id)?;
        let active_stage = project.lifecycle_stage.clone();
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
        let feedback_for_task = feedback.map(ToString::to_string);
        let action_for_task = action.map(ToString::to_string);
        let run_id_for_watchdog = run_id.clone();
        let watchdog_paths = self.paths.clone();
        let pid_watchdog = project_id.clone();
        let stage_watchdog = active_stage.clone();
        thread::spawn(move || {
            let (done_tx, done_rx) = mpsc::channel::<()>();
            let worker_handle = thread::spawn(move || {
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
                    feedback_for_task.as_deref(),
                    action_for_task.as_deref(),
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
                let _ = done_tx.send(());
            });

            // Unified workflow can run PRD, review, planning, coding, and review loops.
            const AI_TIMEOUT: Duration = Duration::from_secs(900);
            if done_rx.recv_timeout(AI_TIMEOUT).is_err() {
                logger::error_fields(
                    "stage agent timeout",
                    &[
                        ("project_id", pid_watchdog.clone()),
                        ("stage", stage_watchdog.clone()),
                        ("timeout_secs", "900".to_string()),
                    ],
                );
                if let Ok(store) = Store::open(&watchdog_paths) {
                    let _ = store.conn.execute(
                        "UPDATE stage_ai_runs SET status = 'failed', error_message = ?1 WHERE id = ?2",
                        rusqlite::params!["AI 生成超时（15分钟）", run_id_for_watchdog],
                    );
                }
            }
            let _ = worker_handle.join();
        });

        Ok(json!({
            "project_id": project_id,
            "stage": active_stage,
            "started": true
        }))
    }

    pub fn run_project_workflow_streaming<F>(
        &self,
        project_id: &str,
        _feedback: Option<&str>,
        action: Option<&str>,
        mode: &str,
        on_event: F,
    ) -> StoreResult<Value>
    where
        F: FnMut(Value) -> StoreResult<()>,
    {
        let project_id = project_id.trim().to_lowercase();
        let project = query::load_project(self, &project_id)?;
        let active_stage = if project.lifecycle_stage.is_empty() {
            "development".to_string()
        } else {
            project.lifecycle_stage.clone()
        };
        let feasibility = self.project_feasibility_context(&project_id)?;
        let project_title = if project.title.is_empty() {
            "项目".to_string()
        } else {
            project.title.clone()
        };
        let run_id = ai_stage::create_stage_ai_run(self, &project_id, &active_stage)?;
        let completed = ai_stage::generate_stage_ai_content_streaming(
            self,
            &run_id,
            &project_id,
            &project_title,
            &active_stage,
            feasibility.as_ref(),
            action,
            mode,
            on_event,
        )?;
        Ok(json!({
            "project_id": project_id,
            "stage": active_stage,
            "completed": completed
        }))
    }

    pub fn get_project_stage_detail(
        &self,
        project_id: &str,
        stage: Option<&str>,
        sub_step: Option<&str>,
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
        let ai_run = query::latest_ai_run(self, &project_id, &active_stage)?;

        // Determine the effective data key for stages with sub-steps
        let lifecycle = crate::store::lifecycle::LifecycleStage::from_str(&active_stage);
        let sub_steps_def = lifecycle.map(|ls| ls.sub_steps()).unwrap_or(&[]);
        let has_sub_steps = !sub_steps_def.is_empty();

        let (data_stage_key, active_sub_step) = if has_sub_steps {
            if let Some(ss) = sub_step.filter(|s| sub_steps_def.iter().any(|(k, _)| k == s)) {
                // Client explicitly selected a sub-step — use it
                (format!("{}:{}", active_stage, ss), Some(ss.to_string()))
            } else {
                let base_has_content =
                    query::load_stage(self, &project_id, &active_stage)?.is_some();
                let detected: Option<&str> = if active_stage == "ui" {
                    let page_map_has_content = self.sub_step_has_content(
                        &project_id,
                        &active_stage,
                        "page_map",
                        0,
                        base_has_content,
                    )?;
                    let interaction_has_content = self.sub_step_has_content(
                        &project_id,
                        &active_stage,
                        "interaction",
                        1,
                        base_has_content,
                    )?;
                    let ai_run_active = ai_run
                        .as_ref()
                        .and_then(|value| value.get("status").and_then(Value::as_str))
                        .map(|status| {
                            matches!(
                                status,
                                "dispatched"
                                    | "waiting_first_delta"
                                    | "streaming"
                                    | "post_processing"
                            )
                        })
                        .unwrap_or(false);

                    if interaction_has_content {
                        Some("interaction")
                    } else if page_map_has_content {
                        if ai_run_active {
                            // AI is actively generating interaction content — show it early
                            Some("interaction")
                        } else {
                            // page_map done, interaction not yet started — stay on page_map
                            Some("page_map")
                        }
                    } else if ai_run_active || base_has_content {
                        Some("page_map")
                    } else {
                        sub_steps_def.first().map(|(k, _)| *k)
                    }
                } else {
                    // Generic auto-detect: find the LAST sub-step that has data (most recent progress)
                    let mut detected: Option<&str> = None;
                    for (key, _) in sub_steps_def.iter() {
                        let compound = format!("{}:{}", active_stage, key);
                        if query::load_stage(self, &project_id, &compound)?.is_some() {
                            detected = Some(key);
                        }
                    }
                    if detected.is_none() && base_has_content {
                        detected = sub_steps_def.first().map(|(k, _)| *k);
                    }
                    detected
                };

                let ss = detected
                    .or_else(|| sub_steps_def.first().map(|(k, _)| *k))
                    .unwrap_or("");
                if ss.is_empty() {
                    (active_stage.clone(), None)
                } else {
                    (format!("{}:{}", active_stage, ss), Some(ss.to_string()))
                }
            }
        } else {
            (active_stage.clone(), None)
        };

        let defaults = stage_defaults(&active_stage);

        // For stages with sub-steps, try compound key first.
        // Only the FIRST sub-step falls back to base stage key (backward compat).
        // Other sub-steps show empty if their compound key has no data.
        let effective_data_key = if has_sub_steps && data_stage_key != active_stage {
            let row = query::load_stage(self, &project_id, &data_stage_key)?;
            if row.is_some() {
                data_stage_key.clone()
            } else {
                let is_first = active_sub_step.as_deref() == sub_steps_def.first().map(|(k, _)| *k);
                if is_first {
                    // First sub-step: fall back to base key for backward compat
                    let base_row = query::load_stage(self, &project_id, &active_stage)?;
                    if base_row.is_some() {
                        active_stage.clone()
                    } else {
                        data_stage_key.clone()
                    }
                } else {
                    // Non-first sub-steps: no fallback, use compound key (may be empty)
                    data_stage_key.clone()
                }
            }
        } else {
            data_stage_key.clone()
        };

        let stage_row = query::load_stage(self, &project_id, &effective_data_key)?;
        let stage_content = assemble::merge_stage_content(stage_row.as_ref(), &defaults);
        let artifacts = query::list_stage_artifacts(self, &project_id, &effective_data_key)?;
        let events = query::list_stage_events(self, &project_id, &effective_data_key)?;
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

        // Build sub-steps metadata if applicable
        let sub_steps_value: Value = if has_sub_steps {
            // Check if legacy data exists under the base stage key (pre-sub-step era)
            let base_has_content = query::load_stage(self, &project_id, &active_stage)
                .ok()
                .flatten()
                .is_some();

            let mut items: Vec<Value> = Vec::new();
            for (i, (key, label)) in sub_steps_def.iter().enumerate() {
                let has_content = self.sub_step_has_content(
                    &project_id,
                    &active_stage,
                    key,
                    i,
                    base_has_content,
                )?;
                items.push(json!({
                    "key": key,
                    "label": label,
                    "has_content": has_content
                }));
            }
            json!(items)
        } else {
            json!(null)
        };

        let mut result = json!({ "detail": detail });
        if has_sub_steps {
            result["detail"]["sub_steps"] = sub_steps_value;
            if let Some(ss) = &active_sub_step {
                result["detail"]["active_sub_step"] = json!(ss);
            }
        }

        Ok(result)
    }

    pub fn get_project_workflow_status(&self, project_id: &str) -> StoreResult<Value> {
        let project_id = project_id.trim().to_lowercase();
        let project = query::load_project(self, &project_id)?;
        let mut workflow = worker::request_workflow_status(&project_id)
            .unwrap_or_else(|_| query::fallback_workflow_status(&project_id, &project));
        self.attach_workflow_artifact_files(&project_id, &mut workflow)?;
        Ok(json!({ "workflow": workflow }))
    }

    pub fn list_project_workflow_events(&self, project_id: &str) -> StoreResult<Value> {
        let project_id = project_id.trim().to_lowercase();
        let project = query::load_project(self, &project_id)?;
        let workflow_events = worker::request_workflow_events(&project_id)
            .unwrap_or_else(|_| query::fallback_workflow_events(self, &project_id, &project));
        Ok(json!({ "workflow_events": workflow_events }))
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

    fn attach_workflow_artifact_files(
        &self,
        project_id: &str,
        workflow: &mut Value,
    ) -> StoreResult<()> {
        let stage_mappings: [(&str, &[&str]); 6] = [
            ("prd", &["prd"]),
            ("prd_review", &["prd:prd_review"]),
            ("development", &["development:task_breakdown"]),
            ("coding", &["development:coding"]),
            ("code_review", &["development:code_review"]),
            ("summary", &["development:summary"]),
        ];

        for (workflow_stage, artifact_stages) in stage_mappings {
            let Some(artifact) =
                self.latest_workflow_stage_artifact(project_id, artifact_stages)?
            else {
                continue;
            };
            let artifact_id = artifact
                .get("id")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string();
            let artifact_name = artifact
                .get("name")
                .and_then(Value::as_str)
                .unwrap_or("阶段产物")
                .to_string();
            let artifact_kind = artifact
                .get("kind")
                .and_then(Value::as_str)
                .unwrap_or("workflow-artifact")
                .to_string();
            let file_path = artifact
                .get("file_path")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string();
            let file_name = artifact_file_name(&artifact_name, &file_path);

            if let Some(phase) = workflow
                .get_mut("phases")
                .and_then(Value::as_object_mut)
                .and_then(|phases| phases.get_mut(workflow_stage))
                .and_then(Value::as_object_mut)
            {
                phase.insert("artifact_id".to_string(), json!(artifact_id));
                phase.insert("file_name".to_string(), json!(file_name));
                phase.insert("file_path".to_string(), json!(file_path));
            }

            let artifact_entry = json!({
                "artifact_id": artifact_id,
                "stage": workflow_stage,
                "name": artifact_name,
                "kind": artifact_kind,
                "status": "completed",
                "file_name": file_name,
                "file_path": file_path
            });
            if let Some(artifacts) = workflow.get_mut("artifacts").and_then(Value::as_array_mut) {
                if let Some(existing) = artifacts
                    .iter_mut()
                    .find(|item| item.get("stage").and_then(Value::as_str) == Some(workflow_stage))
                {
                    *existing = artifact_entry;
                } else {
                    artifacts.push(artifact_entry);
                }
            } else {
                workflow["artifacts"] = json!([artifact_entry]);
            }
        }
        Ok(())
    }

    fn latest_workflow_stage_artifact(
        &self,
        project_id: &str,
        stages: &[&str],
    ) -> StoreResult<Option<Value>> {
        for stage in stages {
            if let Some(artifact) = query::list_stage_artifacts(self, project_id, stage)?
                .into_iter()
                .next()
            {
                return Ok(Some(artifact));
            }
        }
        Ok(None)
    }

    fn sub_step_has_content(
        &self,
        project_id: &str,
        active_stage: &str,
        sub_step_key: &str,
        index: usize,
        base_has_content: bool,
    ) -> StoreResult<bool> {
        let ss_key = format!("{}:{}", active_stage, sub_step_key);
        let stage_exists = query::load_stage(self, project_id, &ss_key)?.is_some()
            || (index == 0 && base_has_content);

        if !stage_exists {
            return Ok(false);
        }

        if active_stage == "ui" && sub_step_key == "interaction" {
            let artifacts = query::list_stage_artifacts(self, project_id, &ss_key)?;
            let has_deliverable = artifacts.iter().any(|artifact| {
                artifact.get("kind").and_then(Value::as_str) == Some("interaction-snapshot")
            });
            return Ok(has_deliverable);
        }

        Ok(true)
    }
}

fn artifact_file_name(name: &str, path: &str) -> String {
    Path::new(path)
        .file_name()
        .and_then(|value| value.to_str())
        .filter(|value| !value.trim().is_empty())
        .unwrap_or(name)
        .to_string()
}

mod assemble;
mod query;

use super::super::helpers::{now_ms, risk_priority, stage_defaults, stage_label};
use super::super::{Store, StoreResult};
use serde_json::{json, Value};

impl Store {
    pub fn get_project_stage_detail(
        &self,
        project_id: &str,
        stage: Option<&str>,
    ) -> StoreResult<Value> {
        let project = query::load_project(self, project_id)?;
        let active_stage = stage
            .map(ToString::to_string)
            .unwrap_or_else(|| project.lifecycle_stage.clone());
        let active_stage = if active_stage.is_empty() {
            "development".to_string()
        } else {
            active_stage
        };

        let defaults = stage_defaults(&active_stage);
        let stage_row = query::load_stage(self, project_id, &active_stage)?;
        let stage_content = assemble::merge_stage_content(stage_row.as_ref(), &defaults);
        let artifacts = query::list_stage_artifacts(self, project_id, &active_stage)?;
        let events = query::list_stage_events(self, project_id, &active_stage)?;

        let feasibility = if let Some(thread_id) = query::linked_thread_id(self, project_id)? {
            let report = self.thread_report_draft(&thread_id)?;
            let materials = self.list_thread_materials(&thread_id)?;
            Some(json!({
                "thread_id": thread_id,
                "report_draft": report,
                "materials": materials
            }))
        } else {
            None
        };

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
            project_id,
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
            feasibility,
            stage_unit_label: stage_label(&active_stage),
            risk_priority: risk_priority(risk_raw),
        });

        Ok(json!({ "detail": detail }))
    }
}

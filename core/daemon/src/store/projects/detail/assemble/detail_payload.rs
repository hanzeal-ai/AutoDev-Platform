use super::super::super::super::helpers::relative_label;
use super::stage_content::StageContent;
use serde_json::{json, Value};

pub(in crate::store::projects::detail) struct DetailPayloadInput<'a> {
    pub(in crate::store::projects::detail) project_id: &'a str,
    pub(in crate::store::projects::detail) project_name: &'a str,
    pub(in crate::store::projects::detail) active_stage: &'a str,
    pub(in crate::store::projects::detail) status_raw: &'a str,
    pub(in crate::store::projects::detail) risk_raw: &'a str,
    pub(in crate::store::projects::detail) owner: &'a str,
    pub(in crate::store::projects::detail) updated_at_ms: i64,
    pub(in crate::store::projects::detail) next_action: &'a str,
    pub(in crate::store::projects::detail) progress: f64,
    pub(in crate::store::projects::detail) block_reason: Option<&'a str>,
    pub(in crate::store::projects::detail) stage_content: StageContent,
    pub(in crate::store::projects::detail) artifacts: Vec<Value>,
    pub(in crate::store::projects::detail) events: Vec<Value>,
    pub(in crate::store::projects::detail) ai_run: Option<Value>,
    pub(in crate::store::projects::detail) feasibility: Option<Value>,
    pub(in crate::store::projects::detail) stage_unit_label: &'a str,
    pub(in crate::store::projects::detail) risk_priority: &'a str,
}

pub(in crate::store::projects::detail) fn build_detail_payload(
    input: DetailPayloadInput<'_>,
) -> Value {
    json!({
        "project_id": input.project_id,
        "unit_name": format!("{} / {}执行单元", input.project_name, input.stage_unit_label),
        "project_name": input.project_name,
        "lifecycle_stage": input.active_stage,
        "status": input.status_raw,
        "priority": input.risk_priority,
        "owner": input.owner,
        "updated_at": relative_label(input.updated_at_ms),
        "objective": input.stage_content.objective,
        "input_contexts": input.stage_content.input_contexts,
        "output_artifacts": input.artifacts,
        "downloads": input.stage_content.downloads,
        "work_units": input.stage_content.work_units,
        "step_progress": input.stage_content.step_progress,
        "risk_level": input.risk_raw,
        "blocker_reason": input.block_reason,
        "needs_user_intervention": matches!(input.status_raw, "awaiting_confirmation" | "blocked" | "failed"),
        "events": input.events,
        "ai_run": input.ai_run,
        "primary_action": input.stage_content.primary_action,
        "secondary_actions": input.stage_content.secondary_actions,
        "risk_items": input.stage_content.risk_items,
        "event_flow": input.stage_content.event_flow,
        "next_action": input.next_action,
        "progress": input.progress,
        "feasibility": input.feasibility
    })
}

use crate::protocol;
use crate::runtime;
use crate::store;
use serde_json::Value;

pub(super) fn handle_generate(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    let project_id = inbound.payload_string("project_id")?.trim().to_lowercase();
    let stage = inbound.payload_object().ok().and_then(|payload| {
        payload
            .get("stage")
            .and_then(Value::as_str)
            .map(str::to_string)
    });
    let feedback = inbound.payload_object().ok().and_then(|payload| {
        payload
            .get("feedback")
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
            .map(str::to_string)
    });
    let store = store::Store::open(runtime_paths)?;
    Ok((
        protocol::MESSAGE_COMMAND_GENERATE_PROJECT_STAGE_AI_OK,
        store.generate_project_stage_ai(&project_id, stage.as_deref(), feedback.as_deref())?,
    ))
}

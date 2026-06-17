use crate::protocol;
use crate::runtime;
use crate::store;
use serde_json::Value;

pub(super) fn handle_run(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    let project_id = inbound.payload_string("project_id")?.trim().to_lowercase();
    let feedback = inbound.payload_object().ok().and_then(|payload| {
        payload
            .get("feedback")
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
            .map(str::to_string)
    });
    let store = store::Store::open(runtime_paths)?;
    Ok((
        protocol::MESSAGE_COMMAND_RUN_PROJECT_WORKFLOW_OK,
        store.run_project_workflow(&project_id, feedback.as_deref())?,
    ))
}

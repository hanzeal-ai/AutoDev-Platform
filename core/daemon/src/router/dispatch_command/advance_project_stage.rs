use crate::protocol;
use crate::runtime;
use crate::store;
use serde_json::Value;

pub(super) fn handle_advance(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    let project_id = inbound.payload_string("project_id")?;
    let action = inbound.payload_object().ok().and_then(|payload| {
        payload
            .get("action")
            .and_then(Value::as_str)
            .map(str::to_string)
    });
    let store = store::Store::open(runtime_paths)?;
    Ok((
        protocol::MESSAGE_COMMAND_ADVANCE_PROJECT_STAGE_OK,
        store.advance_project_stage(&project_id, action.as_deref())?,
    ))
}

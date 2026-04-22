use crate::protocol;
use crate::runtime;
use crate::store;
use serde_json::Value;

pub(super) fn handle_plan(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    let project_id = inbound.payload_string("project_id")?;
    let store = store::Store::open(runtime_paths)?;
    Ok((
        protocol::MESSAGE_COMMAND_PLAN_DEVELOPMENT_OK,
        store.plan_development(&project_id)?,
    ))
}

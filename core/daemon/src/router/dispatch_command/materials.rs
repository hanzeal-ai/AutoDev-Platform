use super::super::payload::parse_material_inputs;
use crate::protocol;
use crate::runtime;
use crate::store;
use serde_json::Value;

pub(super) fn handle_add_materials(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    let thread_id = inbound.payload_string("thread_id")?.to_lowercase();
    let material_inputs = parse_material_inputs(inbound)?;
    let store = store::Store::open(runtime_paths)?;
    Ok((
        protocol::MESSAGE_COMMAND_ADD_CREATION_MATERIALS_OK,
        store.add_creation_materials(&thread_id, &material_inputs)?,
    ))
}

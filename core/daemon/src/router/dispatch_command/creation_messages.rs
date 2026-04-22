use crate::protocol;
use crate::runtime;
use crate::store;
use serde_json::Value;

pub(super) fn handle_add_message(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    let thread_id = inbound.payload_string("thread_id")?.to_lowercase();
    let content = inbound.payload_string("content")?;
    let store = store::Store::open(runtime_paths)?;
    Ok((
        protocol::MESSAGE_COMMAND_ADD_CREATION_MESSAGE_OK,
        store.add_creation_message(&thread_id, &content)?,
    ))
}

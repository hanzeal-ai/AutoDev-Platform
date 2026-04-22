use crate::protocol;
use crate::runtime;
use crate::store;
use serde_json::Value;

pub(super) fn handle_create(
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    let store = store::Store::open(runtime_paths)?;
    Ok((
        protocol::MESSAGE_COMMAND_CREATE_CREATION_THREAD_OK,
        store.create_creation_thread()?,
    ))
}

pub(super) fn handle_rename(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    let thread_id = inbound.payload_string("thread_id")?.to_lowercase();
    let title = inbound.payload_string("title")?;
    let store = store::Store::open(runtime_paths)?;
    Ok((
        protocol::MESSAGE_COMMAND_RENAME_CREATION_THREAD_OK,
        store.rename_creation_thread(&thread_id, &title)?,
    ))
}

pub(super) fn handle_archive(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    let thread_id = inbound.payload_string("thread_id")?.to_lowercase();
    let store = store::Store::open(runtime_paths)?;
    Ok((
        protocol::MESSAGE_COMMAND_ARCHIVE_CREATION_THREAD_OK,
        store.archive_creation_thread(&thread_id)?,
    ))
}

pub(super) fn handle_delete(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    let thread_id = inbound.payload_string("thread_id")?.to_lowercase();
    let store = store::Store::open(runtime_paths)?;
    Ok((
        protocol::MESSAGE_COMMAND_DELETE_CREATION_THREAD_OK,
        store.delete_creation_thread(&thread_id)?,
    ))
}

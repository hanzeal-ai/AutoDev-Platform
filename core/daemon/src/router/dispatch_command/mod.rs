mod advance_project_stage;
mod creation_messages;
mod creation_threads;
mod delete_project;
mod feasibility;
mod generate_project_stage_ai;
mod materials;
mod plan_development;

use crate::protocol;
use crate::runtime;
use serde_json::Value;
use std::io::Write;

pub(super) fn dispatch(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Option<Result<(&'static str, Value), String>> {
    match inbound.message_type.as_str() {
        protocol::MESSAGE_COMMAND_CREATE_CREATION_THREAD => {
            Some(creation_threads::handle_create(runtime_paths))
        }
        protocol::MESSAGE_COMMAND_RENAME_CREATION_THREAD => {
            Some(creation_threads::handle_rename(inbound, runtime_paths))
        }
        protocol::MESSAGE_COMMAND_ARCHIVE_CREATION_THREAD => {
            Some(creation_threads::handle_archive(inbound, runtime_paths))
        }
        protocol::MESSAGE_COMMAND_DELETE_CREATION_THREAD => {
            Some(creation_threads::handle_delete(inbound, runtime_paths))
        }
        protocol::MESSAGE_COMMAND_ADD_CREATION_MESSAGE => Some(
            creation_messages::handle_add_message(inbound, runtime_paths),
        ),
        protocol::MESSAGE_COMMAND_ADD_CREATION_MATERIALS => {
            Some(materials::handle_add_materials(inbound, runtime_paths))
        }
        protocol::MESSAGE_COMMAND_CONFIRM_FEASIBILITY => {
            Some(feasibility::handle_confirm(inbound, runtime_paths))
        }
        protocol::MESSAGE_COMMAND_ADVANCE_PROJECT_STAGE => Some(
            advance_project_stage::handle_advance(inbound, runtime_paths),
        ),
        protocol::MESSAGE_COMMAND_PLAN_DEVELOPMENT => {
            Some(plan_development::handle_plan(inbound, runtime_paths))
        }
        protocol::MESSAGE_COMMAND_GENERATE_PROJECT_STAGE_AI => Some(
            generate_project_stage_ai::handle_generate(inbound, runtime_paths),
        ),
        protocol::MESSAGE_COMMAND_DELETE_PROJECT => {
            Some(delete_project::handle_delete(inbound, runtime_paths))
        }
        _ => None,
    }
}

pub(super) fn dispatch_streaming_add_message(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
    writer: &mut dyn Write,
    correlation_id: &str,
    schema_version: u32,
) {
    creation_messages::handle_add_message_streaming(
        inbound,
        runtime_paths,
        writer,
        correlation_id,
        schema_version,
    );
}

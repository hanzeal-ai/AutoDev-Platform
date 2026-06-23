use crate::protocol;
use crate::runtime;
use crate::store;
use serde_json::{json, Value};
use std::io::Write;

pub(super) fn handle_run(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    handle_workflow_command(
        inbound,
        runtime_paths,
        protocol::MESSAGE_COMMAND_RUN_PROJECT_WORKFLOW_OK,
    )
}

pub(super) fn handle_start(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    handle_workflow_command(
        inbound,
        runtime_paths,
        protocol::MESSAGE_COMMAND_START_PROJECT_WORKFLOW_OK,
    )
}

pub(super) fn handle_resume(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    handle_workflow_command(
        inbound,
        runtime_paths,
        protocol::MESSAGE_COMMAND_RESUME_PROJECT_WORKFLOW_OK,
    )
}

fn handle_workflow_command(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
    response_type: &'static str,
) -> Result<(&'static str, Value), String> {
    let project_id = inbound.payload_string("project_id")?.trim().to_lowercase();
    let feedback = inbound.payload_object().ok().and_then(|payload| {
        payload
            .get("feedback")
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
            .map(str::to_string)
    });
    let action = inbound.payload_object().ok().and_then(|payload| {
        payload
            .get("action")
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
            .map(str::to_string)
    });
    let store = store::Store::open(runtime_paths)?;
    Ok((
        response_type,
        store.run_project_workflow(&project_id, feedback.as_deref(), action.as_deref())?,
    ))
}

pub(super) fn handle_run_streaming(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
    writer: &mut dyn Write,
    correlation_id: &str,
    schema_version: u32,
) {
    let project_id = match inbound.payload_string("project_id") {
        Ok(id) => id.trim().to_lowercase(),
        Err(err) => {
            write_error(writer, correlation_id, schema_version, err);
            return;
        }
    };
    let payload = inbound.payload_object().ok();
    let feedback = payload.and_then(|payload| {
        payload
            .get("feedback")
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
            .map(str::to_string)
    });
    let action = payload.and_then(|payload| {
        payload
            .get("action")
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())
            .map(str::to_string)
    });
    let mode = payload
        .and_then(|payload| payload.get("mode").and_then(Value::as_str))
        .filter(|s| !s.is_empty())
        .unwrap_or("resume")
        .to_string();
    let store = match store::Store::open(runtime_paths) {
        Ok(store) => store,
        Err(err) => {
            write_error(writer, correlation_id, schema_version, err);
            return;
        }
    };
    let corr = correlation_id.to_string();
    let mut wrote_done = false;
    let result = store.run_project_workflow_streaming(
        &project_id,
        feedback.as_deref(),
        action.as_deref(),
        &mode,
        |event| {
            let message_type = match event.get("type").and_then(Value::as_str) {
                Some("workflow_done") => {
                    wrote_done = true;
                    protocol::MESSAGE_EVENT_PROJECT_WORKFLOW_DONE
                }
                Some("workflow_error") => protocol::MESSAGE_EVENT_PROJECT_WORKFLOW_ERROR,
                _ => protocol::MESSAGE_EVENT_PROJECT_WORKFLOW_UPDATE,
            };
            let envelope =
                protocol::EnvelopeOut::success(corr.clone(), schema_version, message_type, event);
            crate::server::write_envelope(writer, &envelope)
                .map_err(|err| format!("failed to write workflow stream event: {err}"))?;
            Ok(())
        },
    );

    match result {
        Ok(payload) if !wrote_done => {
            let done_envelope = protocol::EnvelopeOut::success(
                corr,
                schema_version,
                protocol::MESSAGE_EVENT_PROJECT_WORKFLOW_DONE,
                json!({ "type": "workflow_done", "workflow_id": project_id, "result": payload }),
            );
            let _ = crate::server::write_envelope(writer, &done_envelope);
        }
        Ok(_) => {}
        Err(err) => {
            let error_envelope = protocol::EnvelopeOut::success(
                corr,
                schema_version,
                protocol::MESSAGE_EVENT_PROJECT_WORKFLOW_ERROR,
                json!({ "type": "workflow_error", "workflow_id": project_id, "detail": err }),
            );
            let _ = crate::server::write_envelope(writer, &error_envelope);
        }
    }
}

fn write_error(writer: &mut dyn Write, correlation_id: &str, schema_version: u32, detail: String) {
    let envelope = protocol::EnvelopeOut::error(
        "request_failed",
        Some(correlation_id.to_string()),
        Some(schema_version),
        detail,
    );
    let _ = crate::server::write_envelope(writer, &envelope);
}

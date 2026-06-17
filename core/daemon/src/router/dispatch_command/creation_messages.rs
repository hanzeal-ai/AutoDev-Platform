use crate::protocol;
use crate::runtime;
use crate::store;
use serde_json::{json, Value};
use std::io::Write;

const REQUEST_FAILED: &str = "request_failed";

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

pub(super) fn handle_add_message_streaming(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
    writer: &mut dyn Write,
    correlation_id: &str,
    schema_version: u32,
) {
    let thread_id = match inbound.payload_string("thread_id") {
        Ok(id) => id.to_lowercase(),
        Err(err) => {
            let out = protocol::EnvelopeOut::error(
                REQUEST_FAILED,
                Some(correlation_id.to_string()),
                Some(schema_version),
                err,
            );
            let _ = crate::server::write_envelope(writer, &out);
            return;
        }
    };
    let content = match inbound.payload_string("content") {
        Ok(c) => c,
        Err(err) => {
            let out = protocol::EnvelopeOut::error(
                REQUEST_FAILED,
                Some(correlation_id.to_string()),
                Some(schema_version),
                err,
            );
            let _ = crate::server::write_envelope(writer, &out);
            return;
        }
    };

    let store = match store::Store::open(runtime_paths) {
        Ok(s) => s,
        Err(err) => {
            let out = protocol::EnvelopeOut::error(
                REQUEST_FAILED,
                Some(correlation_id.to_string()),
                Some(schema_version),
                err,
            );
            let _ = crate::server::write_envelope(writer, &out);
            return;
        }
    };

    let corr = correlation_id.to_string();
    let result = store.add_creation_message_streaming(&thread_id, &content, |delta| {
        let delta_envelope = protocol::EnvelopeOut::success(
            corr.clone(),
            schema_version,
            protocol::MESSAGE_EVENT_CREATION_MESSAGE_DELTA,
            json!({ "delta": delta }),
        );
        crate::server::write_envelope(writer, &delta_envelope)
            .map_err(|err| format!("failed to write delta: {err}"))?;
        Ok(())
    });

    match result {
        Ok(payload) => {
            let done_envelope = protocol::EnvelopeOut::success(
                corr,
                schema_version,
                protocol::MESSAGE_EVENT_CREATION_MESSAGE_DONE,
                payload,
            );
            let _ = crate::server::write_envelope(writer, &done_envelope);
        }
        Err(err) => {
            let error_envelope = protocol::EnvelopeOut::success(
                corr,
                schema_version,
                protocol::MESSAGE_EVENT_CREATION_MESSAGE_ERROR,
                json!({ "error": err }),
            );
            let _ = crate::server::write_envelope(writer, &error_envelope);
        }
    }
}

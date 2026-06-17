mod dispatch_command;
mod dispatch_query;
mod payload;

use crate::logger;
use crate::protocol;
use crate::runtime;
use std::io::Write;

pub fn is_streaming_command(inbound: &protocol::EnvelopeIn) -> bool {
    inbound.message_type == protocol::MESSAGE_COMMAND_ADD_CREATION_MESSAGE_STREAM
}

pub fn route_request(
    inbound: protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> protocol::EnvelopeOut {
    let correlation_id = inbound.response_correlation_id();
    let schema_version = inbound.response_schema_version();
    let result = dispatch_query::dispatch(&inbound, runtime_paths)
        .or_else(|| dispatch_command::dispatch(&inbound, runtime_paths))
        .unwrap_or_else(|| {
            Err(format!(
                "unsupported message_type: {}",
                inbound.message_type
            ))
        });

    match result {
        Ok((message_type, payload)) => {
            protocol::EnvelopeOut::success(correlation_id, schema_version, message_type, payload)
        }
        Err(detail) => {
            logger::error_fields(
                "request failed",
                &[
                    ("message_type", inbound.message_type.clone()),
                    ("detail", detail.clone()),
                ],
            );
            protocol::EnvelopeOut::error(
                "request_failed",
                inbound
                    .message_id
                    .clone()
                    .or(inbound.correlation_id.clone()),
                inbound.schema_version,
                detail,
            )
        }
    }
}

pub fn route_streaming_request(
    inbound: protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
    writer: &mut dyn Write,
) {
    let correlation_id = inbound.response_correlation_id();
    let schema_version = inbound.response_schema_version();

    match inbound.message_type.as_str() {
        protocol::MESSAGE_COMMAND_ADD_CREATION_MESSAGE_STREAM => {
            dispatch_command::dispatch_streaming_add_message(
                &inbound,
                runtime_paths,
                writer,
                &correlation_id,
                schema_version,
            );
        }
        _ => {
            let out = protocol::EnvelopeOut::error(
                "unsupported_streaming",
                Some(correlation_id),
                Some(schema_version),
                format!(
                    "unsupported streaming message_type: {}",
                    inbound.message_type
                ),
            );
            let _ = crate::server::write_envelope(writer, &out);
        }
    }
}

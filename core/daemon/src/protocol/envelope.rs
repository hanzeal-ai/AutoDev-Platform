use super::constants::{MESSAGE_ERROR, SCHEMA_VERSION};
use super::time::{now_ms, server_message_id};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

#[derive(Debug, Deserialize)]
pub struct EnvelopeIn {
    pub message_id: Option<String>,
    pub correlation_id: Option<String>,
    pub message_type: String,
    pub schema_version: Option<u32>,
    #[serde(default)]
    pub payload: Value,
}

impl EnvelopeIn {
    pub fn response_correlation_id(&self) -> String {
        self.message_id
            .clone()
            .or(self.correlation_id.clone())
            .unwrap_or_else(|| "unknown".to_string())
    }

    pub fn response_schema_version(&self) -> u32 {
        self.schema_version.unwrap_or(SCHEMA_VERSION)
    }

    pub fn payload_object(&self) -> Result<&serde_json::Map<String, Value>, String> {
        self.payload
            .as_object()
            .ok_or_else(|| "payload must be an object".to_string())
    }

    pub fn payload_string(&self, key: &str) -> Result<String, String> {
        let obj = self.payload_object()?;
        obj.get(key)
            .and_then(Value::as_str)
            .map(ToString::to_string)
            .ok_or_else(|| format!("payload.{key} must be a string"))
    }
}

#[derive(Debug, Serialize)]
pub struct EnvelopeOut {
    message_id: String,
    correlation_id: String,
    message_type: String,
    schema_version: u32,
    timestamp: u64,
    payload: Value,
}

impl EnvelopeOut {
    pub fn success(
        correlation_id: String,
        schema_version: u32,
        message_type: &str,
        payload: Value,
    ) -> Self {
        Self {
            message_id: server_message_id(),
            correlation_id,
            message_type: message_type.to_string(),
            schema_version,
            timestamp: now_ms(),
            payload,
        }
    }

    pub fn error(
        code: &str,
        correlation_id: Option<String>,
        schema_version: Option<u32>,
        detail: String,
    ) -> Self {
        Self {
            message_id: server_message_id(),
            correlation_id: correlation_id.unwrap_or_else(|| "unknown".to_string()),
            message_type: MESSAGE_ERROR.to_string(),
            schema_version: schema_version.unwrap_or(SCHEMA_VERSION),
            timestamp: now_ms(),
            payload: json!({
                "code": code,
                "detail": detail
            }),
        }
    }
}

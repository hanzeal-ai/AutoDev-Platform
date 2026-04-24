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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deserialize_valid_envelope() {
        let input = json!({
            "message_id": "client-1",
            "correlation_id": "corr-1",
            "message_type": "query.get_health",
            "schema_version": 1,
            "payload": {}
        });
        let env: EnvelopeIn = serde_json::from_value(input).unwrap();
        assert_eq!(env.message_type, "query.get_health");
        assert_eq!(env.message_id, Some("client-1".to_string()));
        assert_eq!(env.response_schema_version(), 1);
    }

    #[test]
    fn deserialize_minimal_envelope() {
        let input = json!({
            "message_type": "query.get_health"
        });
        let env: EnvelopeIn = serde_json::from_value(input).unwrap();
        assert_eq!(env.message_id, None);
        assert_eq!(env.correlation_id, None);
        assert_eq!(env.schema_version, None);
        assert_eq!(env.payload, Value::Null);
    }

    #[test]
    fn response_correlation_id_prefers_message_id() {
        let env = EnvelopeIn {
            message_id: Some("msg-1".to_string()),
            correlation_id: Some("corr-1".to_string()),
            message_type: "test".to_string(),
            schema_version: None,
            payload: Value::Null,
        };
        assert_eq!(env.response_correlation_id(), "msg-1");
    }

    #[test]
    fn response_correlation_id_falls_back_to_correlation_id() {
        let env = EnvelopeIn {
            message_id: None,
            correlation_id: Some("corr-1".to_string()),
            message_type: "test".to_string(),
            schema_version: None,
            payload: Value::Null,
        };
        assert_eq!(env.response_correlation_id(), "corr-1");
    }

    #[test]
    fn response_correlation_id_defaults_to_unknown() {
        let env = EnvelopeIn {
            message_id: None,
            correlation_id: None,
            message_type: "test".to_string(),
            schema_version: None,
            payload: Value::Null,
        };
        assert_eq!(env.response_correlation_id(), "unknown");
    }

    #[test]
    fn response_schema_version_defaults() {
        let env = EnvelopeIn {
            message_id: None,
            correlation_id: None,
            message_type: "test".to_string(),
            schema_version: None,
            payload: Value::Null,
        };
        assert_eq!(env.response_schema_version(), SCHEMA_VERSION);
    }

    #[test]
    fn payload_string_extracts_value() {
        let env = EnvelopeIn {
            message_id: None,
            correlation_id: None,
            message_type: "test".to_string(),
            schema_version: None,
            payload: json!({"id": "abc-123"}),
        };
        assert_eq!(env.payload_string("id").unwrap(), "abc-123");
    }

    #[test]
    fn payload_string_error_on_missing_key() {
        let env = EnvelopeIn {
            message_id: None,
            correlation_id: None,
            message_type: "test".to_string(),
            schema_version: None,
            payload: json!({"id": "abc-123"}),
        };
        assert!(env.payload_string("missing").is_err());
    }

    #[test]
    fn payload_object_error_on_non_object() {
        let env = EnvelopeIn {
            message_id: None,
            correlation_id: None,
            message_type: "test".to_string(),
            schema_version: None,
            payload: json!("not an object"),
        };
        assert!(env.payload_object().is_err());
    }

    #[test]
    fn envelope_out_success_serializes() {
        let out = EnvelopeOut::success(
            "corr-1".to_string(),
            1,
            "query.test.ok",
            json!({"count": 5}),
        );
        let serialized = serde_json::to_value(&out).unwrap();
        assert_eq!(serialized["message_type"], "query.test.ok");
        assert_eq!(serialized["correlation_id"], "corr-1");
        assert_eq!(serialized["payload"]["count"], 5);
    }

    #[test]
    fn envelope_out_error_serializes() {
        let out = EnvelopeOut::error(
            "NOT_FOUND",
            Some("corr-1".to_string()),
            Some(1),
            "item not found".to_string(),
        );
        let serialized = serde_json::to_value(&out).unwrap();
        assert_eq!(serialized["message_type"], MESSAGE_ERROR);
        assert_eq!(serialized["payload"]["code"], "NOT_FOUND");
        assert_eq!(serialized["payload"]["detail"], "item not found");
    }
}

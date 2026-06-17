use serde::Serialize;
use serde_json::Value;

pub(in crate::store) fn parse_json_array_strings(raw: &str) -> Vec<String> {
    serde_json::from_str::<Vec<String>>(raw).unwrap_or_default()
}

pub(in crate::store) fn parse_json_value(raw: &str) -> Value {
    serde_json::from_str::<Value>(raw).unwrap_or_else(|_| Value::Array(vec![]))
}

pub(in crate::store) fn to_json_string<T: Serialize>(value: &T) -> String {
    serde_json::to_string(value).unwrap_or_else(|_| "[]".to_string())
}

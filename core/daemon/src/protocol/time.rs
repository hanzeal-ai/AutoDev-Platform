use std::time::{SystemTime, UNIX_EPOCH};

pub(super) fn now_ms() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as u64
}

pub(super) fn server_message_id() -> String {
    format!("daemon-{}", now_ms())
}

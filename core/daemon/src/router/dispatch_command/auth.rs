use crate::protocol;
use crate::runtime;
use serde_json::{json, Value};

const TEST_USERNAME: &str = "admin";
const TEST_PASSWORD: &str = "admin2026";

pub(super) fn handle_login(
    inbound: &protocol::EnvelopeIn,
    _runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    let username = inbound.payload_string("username")?;
    let password = inbound.payload_string("password")?;

    if username.trim() != TEST_USERNAME || password != TEST_PASSWORD {
        return Err("账号或密码错误".to_string());
    }

    Ok((
        protocol::MESSAGE_COMMAND_LOGIN_OK,
        json!({
            "user": {
                "display_name": "管理员",
                "email": "admin@autodev.local",
                "current_plan": "测试环境"
            }
        }),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn login_envelope(username: &str, password: &str) -> protocol::EnvelopeIn {
        protocol::EnvelopeIn {
            message_id: Some("test-login".to_string()),
            correlation_id: Some("test-login".to_string()),
            message_type: protocol::MESSAGE_COMMAND_LOGIN.to_string(),
            schema_version: Some(protocol::SCHEMA_VERSION),
            payload: json!({
                "username": username,
                "password": password
            }),
        }
    }

    #[test]
    fn login_accepts_test_account() {
        let paths = runtime::RuntimePaths::test_defaults();
        let inbound = login_envelope("admin", "admin2026");

        let (message_type, payload) = handle_login(&inbound, &paths).unwrap();

        assert_eq!(message_type, protocol::MESSAGE_COMMAND_LOGIN_OK);
        assert_eq!(payload["user"]["display_name"], "管理员");
        assert_eq!(payload["user"]["current_plan"], "测试环境");
    }

    #[test]
    fn login_rejects_invalid_password() {
        let paths = runtime::RuntimePaths::test_defaults();
        let inbound = login_envelope("admin", "wrong");

        let error = handle_login(&inbound, &paths).unwrap_err();

        assert_eq!(error, "账号或密码错误");
    }
}

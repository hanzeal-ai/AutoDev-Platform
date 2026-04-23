use super::super::super::StoreResult;
use crate::logger;
use crate::runtime::DeepSeekConfig;
use serde_json::Value;

pub(super) fn parse_json_object(
    config: &DeepSeekConfig,
    system_prompt: &str,
    user_prompt: &str,
    request_body_text: &str,
    response_text: &str,
    raw_content: &str,
) -> StoreResult<Value> {
    let json_text = extract_json_text(raw_content).ok_or_else(|| {
        let reason = "DeepSeek 响应未找到可解析 JSON".to_string();
        logger::error_fields(
            "llm response parse failed",
            &[
                ("model", config.model().to_string()),
                ("system_prompt", system_prompt.to_string()),
                ("user_prompt", user_prompt.to_string()),
                ("request_body", request_body_text.to_string()),
                ("response_raw", response_text.to_string()),
                ("response_content", raw_content.to_string()),
                ("reason", reason.clone()),
            ],
        );
        reason
    })?;
    let value: Value = serde_json::from_str(&json_text).map_err(|err| {
        let reason = format!("解析 DeepSeek JSON 失败: {err}");
        logger::error_fields(
            "llm response parse failed",
            &[
                ("model", config.model().to_string()),
                ("system_prompt", system_prompt.to_string()),
                ("user_prompt", user_prompt.to_string()),
                ("request_body", request_body_text.to_string()),
                ("response_raw", response_text.to_string()),
                ("response_content", raw_content.to_string()),
                ("reason", reason.clone()),
            ],
        );
        reason
    })?;
    if !value.is_object() {
        let reason = "DeepSeek JSON 顶层必须是对象".to_string();
        logger::error_fields(
            "llm response parse failed",
            &[
                ("model", config.model().to_string()),
                ("system_prompt", system_prompt.to_string()),
                ("user_prompt", user_prompt.to_string()),
                ("request_body", request_body_text.to_string()),
                ("response_raw", response_text.to_string()),
                ("response_content", raw_content.to_string()),
                ("reason", reason.clone()),
            ],
        );
        return Err(reason);
    }
    Ok(value)
}

fn extract_json_text(raw: &str) -> Option<String> {
    if is_json_object(raw.trim()) {
        return Some(raw.trim().to_string());
    }

    if let Some(code_block_json) = extract_json_from_code_fence(raw) {
        return Some(code_block_json);
    }

    extract_balanced_json_object(raw)
}

fn is_json_object(text: &str) -> bool {
    serde_json::from_str::<Value>(text)
        .ok()
        .and_then(|value| value.as_object().map(|_| ()))
        .is_some()
}

fn extract_json_from_code_fence(raw: &str) -> Option<String> {
    let mut in_fence = false;
    let mut buffer = String::new();

    for line in raw.lines() {
        if line.trim_start().starts_with("```") {
            if in_fence {
                let candidate = buffer.trim();
                if is_json_object(candidate) {
                    return Some(candidate.to_string());
                }
                buffer.clear();
            }
            in_fence = !in_fence;
            continue;
        }
        if in_fence {
            buffer.push_str(line);
            buffer.push('\n');
        }
    }

    None
}

fn extract_balanced_json_object(raw: &str) -> Option<String> {
    let mut depth = 0usize;
    let mut start = None;
    let mut in_string = false;
    let mut escaped = false;

    for (index, ch) in raw.char_indices() {
        if in_string {
            if escaped {
                escaped = false;
                continue;
            }
            match ch {
                '\\' => escaped = true,
                '"' => in_string = false,
                _ => {}
            }
            continue;
        }

        match ch {
            '"' => in_string = true,
            '{' => {
                if depth == 0 {
                    start = Some(index);
                }
                depth += 1;
            }
            '}' => {
                if depth == 0 {
                    continue;
                }
                depth -= 1;
                if depth == 0 {
                    if let Some(begin) = start {
                        let end = index + ch.len_utf8();
                        let candidate = raw[begin..end].trim();
                        if is_json_object(candidate) {
                            return Some(candidate.to_string());
                        }
                    }
                    start = None;
                }
            }
            _ => {}
        }
    }

    None
}

#[cfg(test)]
mod tests {
    use super::{parse_json_object, DeepSeekConfig};

    fn test_config() -> DeepSeekConfig {
        std::env::set_var("DEEPSEEK_API_KEY", "test-key");
        std::env::set_var("DEEPSEEK_BASE_URL", "https://example.test");
        std::env::set_var("DEEPSEEK_MODEL", "test-model");
        DeepSeekConfig::from_env().expect("test config should be valid")
    }

    #[test]
    fn parse_json_object_handles_code_fence() {
        let raw = "```json\n{\"a\":\"b\"}\n```";
        let parsed = parse_json_object(&test_config(), "system", "user", "{}", "{}", raw)
            .expect("should parse");
        assert_eq!(parsed["a"], "b");
    }

    #[test]
    fn parse_json_object_handles_wrapper_text() {
        let raw = "分析：{\"a\":\"b\"}结束";
        let parsed = parse_json_object(&test_config(), "system", "user", "{}", "{}", raw)
            .expect("should parse");
        assert_eq!(parsed["a"], "b");
    }
}

use super::super::{Store, StoreResult};
use crate::logger;
use crate::runtime::DeepSeekConfig;
use rusqlite::params;
use serde_json::{json, Value};
use std::time::Duration;

#[derive(Debug, Clone, serde::Serialize)]
pub(super) struct MessageContext {
    pub(super) role: String,
    pub(super) content: String,
}

#[derive(Debug, Clone, serde::Serialize)]
pub(super) struct MaterialContext {
    pub(super) name: String,
    pub(super) type_hint: String,
    pub(super) size_hint: String,
    pub(super) status: String,
}

pub(super) fn request_json_object(
    config: &DeepSeekConfig,
    system_prompt: &str,
    user_prompt: &str,
    temperature: f64,
    max_tokens: usize,
) -> StoreResult<Value> {
    let request_body = json!({
        "model": config.model(),
        "temperature": temperature,
        "max_tokens": max_tokens,
        "response_format": {
            "type": "json_object"
        },
        "messages": [
            {
                "role": "system",
                "content": system_prompt
            },
            {
                "role": "user",
                "content": user_prompt
            }
        ]
    });
    let request_body_text = serde_json::to_string(&request_body).unwrap_or_else(|_| "{}".to_string());

    let agent = ureq::AgentBuilder::new()
        .timeout_connect(Duration::from_secs(5))
        .timeout_read(Duration::from_secs(45))
        .build();
    let response = agent
        .post(&config.endpoint())
        .set("Authorization", &format!("Bearer {}", config.api_key()))
        .set("Content-Type", "application/json")
        .send_json(request_body)
        .map_err(|error| {
            let reason = map_request_error(error);
            logger::error_fields(
                "llm request failed",
                &[
                    ("model", config.model().to_string()),
                    ("system_prompt", system_prompt.to_string()),
                    ("user_prompt", user_prompt.to_string()),
                    ("request_body", request_body_text.clone()),
                    ("reason", reason.clone()),
                ],
            );
            reason
        })?;

    let response_text = response.into_string().map_err(|err| {
        let reason = format!("读取 DeepSeek 响应失败: {err}");
        logger::error_fields(
            "llm response read failed",
            &[
                ("model", config.model().to_string()),
                ("system_prompt", system_prompt.to_string()),
                ("user_prompt", user_prompt.to_string()),
                ("request_body", request_body_text.clone()),
                ("reason", reason.clone()),
            ],
        );
        reason
    })?;
    let response_value: Value = serde_json::from_str(&response_text).map_err(|err| {
        let reason = format!("解析 DeepSeek 响应 JSON 失败: {err}");
        logger::error_fields(
            "llm response json invalid",
            &[
                ("model", config.model().to_string()),
                ("system_prompt", system_prompt.to_string()),
                ("user_prompt", user_prompt.to_string()),
                ("request_body", request_body_text.clone()),
                ("response_raw", response_text.clone()),
                ("reason", reason.clone()),
            ],
        );
        reason
    })?;
    let content = response_value
        .pointer("/choices/0/message/content")
        .and_then(Value::as_str)
        .ok_or_else(|| {
            let reason = "DeepSeek 响应缺少 choices[0].message.content".to_string();
            logger::error_fields(
                "llm response content missing",
                &[
                    ("model", config.model().to_string()),
                    ("system_prompt", system_prompt.to_string()),
                    ("user_prompt", user_prompt.to_string()),
                    ("request_body", request_body_text.clone()),
                    ("response_raw", response_text.clone()),
                    ("reason", reason.clone()),
                ],
            );
            reason
        })?;
    parse_json_object(config, system_prompt, user_prompt, &request_body_text, &response_text, content)
}

pub(super) fn parse_json_object(
    config: &DeepSeekConfig,
    system_prompt: &str,
    user_prompt: &str,
    request_body_text: &str,
    response_text: &str,
    raw_content: &str,
) -> StoreResult<Value> {
    let json_text = extract_json_text(raw_content)
        .ok_or_else(|| {
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
    let value: Value = serde_json::from_str(&json_text)
        .map_err(|err| {
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

pub(super) fn list_recent_messages(
    store: &Store,
    thread_id: &str,
    limit: usize,
) -> StoreResult<Vec<MessageContext>> {
    let mut stmt = store
        .conn
        .prepare(
            r#"
SELECT role, content
FROM creation_messages
WHERE thread_id = ?1
ORDER BY created_at_ms DESC
LIMIT ?2
"#,
        )
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map(params![thread_id, limit as i64], |row| {
            Ok(MessageContext {
                role: row.get::<_, String>(0)?,
                content: row.get::<_, String>(1)?,
            })
        })
        .map_err(|err| err.to_string())?;

    let mut out = Vec::new();
    for row in rows {
        out.push(row.map_err(|err| err.to_string())?);
    }
    out.reverse();
    Ok(out)
}

pub(super) fn list_recent_materials(
    store: &Store,
    thread_id: &str,
    limit: usize,
) -> StoreResult<Vec<MaterialContext>> {
    let mut stmt = store
        .conn
        .prepare(
            r#"
SELECT name, type_hint, size_hint, analysis_status
FROM materials
WHERE thread_id = ?1
ORDER BY added_at_ms DESC
LIMIT ?2
"#,
        )
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map(params![thread_id, limit as i64], |row| {
            Ok(MaterialContext {
                name: row.get::<_, String>(0)?,
                type_hint: row.get::<_, String>(1)?,
                size_hint: row.get::<_, String>(2)?,
                status: row.get::<_, String>(3)?,
            })
        })
        .map_err(|err| err.to_string())?;

    let mut out = Vec::new();
    for row in rows {
        out.push(row.map_err(|err| err.to_string())?);
    }
    Ok(out)
}

pub(super) fn truncate_text(input: &str, max_chars: usize) -> String {
    let mut out = String::new();
    for ch in input.chars().take(max_chars) {
        out.push(ch);
    }
    if input.chars().count() > max_chars {
        out.push_str("...");
    }
    out
}

fn map_request_error(error: ureq::Error) -> String {
    match error {
        ureq::Error::Status(code, _) => format!("DeepSeek 请求失败，HTTP {code}"),
        other => format!("DeepSeek 请求失败: {other}"),
    }
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
    use super::parse_json_object;

    #[test]
    fn parse_json_object_handles_code_fence() {
        let raw = "```json\n{\"a\":\"b\"}\n```";
        let parsed = parse_json_object(raw).expect("should parse");
        assert_eq!(parsed["a"], "b");
    }

    #[test]
    fn parse_json_object_handles_wrapper_text() {
        let raw = "分析：{\"a\":\"b\"}结束";
        let parsed = parse_json_object(raw).expect("should parse");
        assert_eq!(parsed["a"], "b");
    }
}

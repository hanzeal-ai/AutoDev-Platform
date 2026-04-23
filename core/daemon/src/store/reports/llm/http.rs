use super::parse::parse_json_object;
use super::super::super::StoreResult;
use crate::logger;
use crate::runtime::DeepSeekConfig;
use serde_json::{json, Value};
use std::io::{BufRead, BufReader};
use std::time::Duration;

pub(crate) fn request_json_object(
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
    let request_body_text =
        serde_json::to_string(&request_body).unwrap_or_else(|_| "{}".to_string());

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
    parse_json_object(
        config,
        system_prompt,
        user_prompt,
        &request_body_text,
        &response_text,
        content,
    )
}

pub(crate) fn request_chat_message_streaming<F>(
    config: &DeepSeekConfig,
    system_prompt: &str,
    user_prompt: &str,
    temperature: f64,
    max_tokens: usize,
    mut on_delta: F,
) -> StoreResult<String>
where
    F: FnMut(&str) -> StoreResult<()>,
{
    let request_body = json!({
        "model": config.model(),
        "temperature": temperature,
        "max_tokens": max_tokens,
        "stream": true,
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
    let request_body_text =
        serde_json::to_string(&request_body).unwrap_or_else(|_| "{}".to_string());

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
                "llm streaming request failed",
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

    let mut full_content = String::new();
    let reader = BufReader::new(response.into_reader());
    for line in reader.lines() {
        let line = line.map_err(|err| format!("读取 DeepSeek 流式响应失败: {err}"))?;
        let line = line.trim();
        if !line.starts_with("data:") {
            continue;
        }
        let data = line.trim_start_matches("data:").trim();
        if data == "[DONE]" {
            break;
        }
        let value: Value = match serde_json::from_str(data) {
            Ok(value) => value,
            Err(_) => continue,
        };
        if let Some(delta) = value
            .pointer("/choices/0/delta/content")
            .and_then(Value::as_str)
            .filter(|delta| !delta.is_empty())
        {
            full_content.push_str(delta);
            on_delta(delta)?;
        }
    }

    if full_content.trim().is_empty() {
        return Err("DeepSeek 流式响应没有返回内容".to_string());
    }
    Ok(full_content)
}

fn map_request_error(error: ureq::Error) -> String {
    match error {
        ureq::Error::Status(code, _) => format!("DeepSeek 请求失败，HTTP {code}"),
        other => format!("DeepSeek 请求失败: {other}"),
    }
}

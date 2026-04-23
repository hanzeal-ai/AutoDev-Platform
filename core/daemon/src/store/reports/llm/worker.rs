//! HTTP client for the Python AI worker (localhost:9720).
//!
//! Falls back to direct DeepSeek calls if the worker is unavailable.

use crate::logger;
use serde_json::{json, Value};
use std::io::{BufRead, BufReader};
use std::sync::Mutex;
use std::time::{Duration, Instant};

use super::super::super::StageDefaults;
use super::super::super::StoreResult;

const DEFAULT_WORKER_URL: &str = "http://127.0.0.1:9720";
const WORKER_CACHE_TTL_SECS: u64 = 30;

fn worker_base_url() -> String {
    std::env::var("AI_WORKER_URL").unwrap_or_else(|_| DEFAULT_WORKER_URL.to_string())
}

static WORKER_CACHE: Mutex<Option<(bool, Instant)>> = Mutex::new(None);

/// Check if the AI worker is reachable (cached for 30 seconds).
pub(crate) fn worker_available() -> bool {
    if let Ok(cache) = WORKER_CACHE.lock() {
        if let Some((result, checked_at)) = *cache {
            if checked_at.elapsed() < Duration::from_secs(WORKER_CACHE_TTL_SECS) {
                return result;
            }
        }
    }
    let result = probe_worker_health();
    if let Ok(mut cache) = WORKER_CACHE.lock() {
        *cache = Some((result, Instant::now()));
    }
    result
}

fn probe_worker_health() -> bool {
    let url = format!("{}/health", worker_base_url());
    let agent = make_agent(Duration::from_secs(2));
    match agent.get(&url).call() {
        Ok(resp) => {
            let text = resp.into_string().unwrap_or_default();
            text.contains("\"status\"")
        }
        Err(_) => false,
    }
}

fn make_agent(timeout_read: Duration) -> ureq::Agent {
    ureq::AgentBuilder::new()
        .timeout_connect(Duration::from_secs(5))
        .timeout_read(timeout_read)
        .build()
}

/// Request stage AI generation from the Python worker via SSE.
///
/// Calls `POST /generate/stage` and processes the SSE stream:
///   - `kind=delta`  → calls `on_delta` callback (agent streaming text)
///   - `kind=result` → returns structured JSON
///   - `kind=error`  → returns error
pub(crate) fn request_stage_generation<F>(
    project_id: &str,
    project_name: &str,
    stage: &str,
    defaults: &StageDefaults,
    feasibility: Option<&Value>,
    mut on_delta: F,
) -> StoreResult<Value>
where
    F: FnMut(&str) -> StoreResult<()>,
{
    let url = format!("{}/generate/stage", worker_base_url());

    let body = json!({
        "project_id": project_id,
        "project_name": project_name,
        "stage": stage,
        "objective": defaults.objective,
        "input_contexts": defaults.input_contexts,
        "step_progress": defaults.step_progress,
        "risk_items": defaults.risk_items,
        "event_flow": defaults.event_flow,
        "primary_action": defaults.primary_action,
        "secondary_actions": defaults.secondary_actions,
        "work_units": defaults.work_units.iter().map(|u| json!({
            "id": u.id,
            "title": u.title,
            "agent_role": u.agent_role,
            "status": u.status,
            "progress": u.progress,
            "depends_on": u.depends_on,
            "current_output": u.current_output,
            "next_step": u.next_step
        })).collect::<Vec<Value>>(),
        "feasibility": feasibility.unwrap_or(&json!(null)),
    });

    let agent = make_agent(Duration::from_secs(120));

    let response = agent
        .post(&url)
        .set("Content-Type", "application/json")
        .set("Accept", "text/event-stream")
        .send_json(body)
        .map_err(|err| {
            let reason = format!("AI Worker 请求失败: {err}");
            logger::error_fields(
                "ai_worker stage request failed",
                &[
                    ("project_id", project_id.to_string()),
                    ("stage", stage.to_string()),
                    ("reason", reason.clone()),
                ],
            );
            reason
        })?;

    let reader = BufReader::new(response.into_reader());
    let mut result_value: Option<Value> = None;
    let mut last_error: Option<String> = None;

    for line in reader.lines() {
        let line = line.map_err(|err| format!("读取 AI Worker SSE 失败: {err}"))?;
        let line = line.trim().to_string();

        if !line.starts_with("data:") {
            continue;
        }
        let data = line.trim_start_matches("data:").trim();
        if data.is_empty() || data == "[DONE]" {
            continue;
        }

        let event: Value = match serde_json::from_str(data) {
            Ok(v) => v,
            Err(_) => continue,
        };

        let kind = event
            .get("kind")
            .and_then(Value::as_str)
            .unwrap_or("");

        match kind {
            "delta" => {
                if let Some(content) = event.get("content").and_then(Value::as_str) {
                    if !content.is_empty() {
                        on_delta(content)?;
                    }
                }
            }
            "result" => {
                if let Some(structured) = event.get("structured") {
                    result_value = Some(structured.clone());
                }
            }
            "error" => {
                let msg = event
                    .get("content")
                    .and_then(Value::as_str)
                    .unwrap_or("unknown error")
                    .to_string();
                last_error = Some(msg);
            }
            _ => {}
        }
    }

    if let Some(err) = last_error {
        return Err(format!("AI Worker 返回错误: {err}"));
    }

    result_value.ok_or_else(|| "AI Worker SSE 流结束但未返回结构化结果".to_string())
}

/// Request a feasibility report from the Python worker.
pub(crate) fn request_report_generation(
    thread_id: &str,
    draft: &Value,
    messages: &[Value],
    materials: &[Value],
) -> StoreResult<Value> {
    let url = format!("{}/generate/report", worker_base_url());

    let body = json!({
        "thread_id": thread_id,
        "draft": draft,
        "messages": messages,
        "materials": materials,
    });

    let agent = make_agent(Duration::from_secs(60));

    let response = agent
        .post(&url)
        .set("Content-Type", "application/json")
        .send_json(body)
        .map_err(|err| {
            let reason = format!("AI Worker report 请求失败: {err}");
            logger::error_fields(
                "ai_worker report request failed",
                &[
                    ("thread_id", thread_id.to_string()),
                    ("reason", reason.clone()),
                ],
            );
            reason
        })?;

    let text = response.into_string().map_err(|err| {
        format!("读取 AI Worker report 响应失败: {err}")
    })?;

    serde_json::from_str(&text).map_err(|err| {
        format!("解析 AI Worker report JSON 失败: {err}")
    })
}

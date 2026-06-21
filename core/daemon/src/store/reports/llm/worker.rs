//! HTTP client for the Python AI worker (localhost:9720).
//!
//! Delegates all AI generation to the Python AI Worker (LangGraph).

use serde_json::{json, Value};
use std::sync::Mutex;
use std::time::{Duration, Instant};

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

pub(crate) fn request_workflow_status(workflow_id: &str) -> StoreResult<Value> {
    post_worker_json(
        "/workflow/status",
        json!({ "workflow_id": workflow_id }),
        Duration::from_secs(30),
        "workflow status",
    )
}

pub(crate) fn request_workflow_events(workflow_id: &str) -> StoreResult<Value> {
    post_worker_json(
        "/workflow/events",
        json!({ "workflow_id": workflow_id }),
        Duration::from_secs(30),
        "workflow events",
    )
}

pub(crate) fn request_workflow_resume(workflow_id: &str, action: Option<&str>) -> StoreResult<Value> {
    let mut body = json!({ "workflow_id": workflow_id });
    if let Some(action) = action.filter(|value| !value.is_empty()) {
        body["action"] = json!(action);
    }
    post_worker_json(
        "/workflow/resume",
        body,
        Duration::from_secs(900),
        "workflow resume",
    )
}

pub(crate) fn request_workflow_start(
    project_id: &str,
    project_name: &str,
    feasibility: Option<&Value>,
    action: Option<&str>,
) -> StoreResult<Value> {
    post_worker_json(
        "/workflow/start",
        workflow_start_body(project_id, project_name, feasibility, action),
        Duration::from_secs(900),
        "workflow start",
    )
}

pub(crate) fn request_workflow_artifact(
    workflow_id: &str,
    artifact_id: &str,
) -> StoreResult<Value> {
    post_worker_json(
        "/workflow/artifact",
        json!({
            "workflow_id": workflow_id,
            "artifact_id": artifact_id,
        }),
        Duration::from_secs(30),
        "workflow artifact",
    )
}

fn post_worker_json(
    path: &str,
    body: Value,
    timeout_read: Duration,
    operation: &str,
) -> StoreResult<Value> {
    let url = format!("{}{}", worker_base_url(), path);
    let agent = make_agent(timeout_read);
    let response = agent
        .post(&url)
        .set("Content-Type", "application/json")
        .send_json(body)
        .map_err(|err| format!("AI Worker {operation} 请求失败: {err}"))?;
    let text = response
        .into_string()
        .map_err(|err| format!("读取 AI Worker {operation} 响应失败: {err}"))?;
    serde_json::from_str(&text)
        .map_err(|err| format!("解析 AI Worker {operation} JSON 失败: {err}"))
}

fn workflow_start_body(
    project_id: &str,
    project_name: &str,
    feasibility: Option<&Value>,
    action: Option<&str>,
) -> Value {
    let report_draft = feasibility
        .and_then(|v| v.get("report_draft"))
        .cloned()
        .unwrap_or_else(|| json!({}));
    let thread_id = feasibility
        .and_then(|v| v.get("thread_id"))
        .and_then(Value::as_str)
        .filter(|s| !s.trim().is_empty())
        .unwrap_or(project_id);
    let user_message = report_draft
        .get("problem_definition")
        .and_then(Value::as_str)
        .or_else(|| {
            report_draft
                .get("feasibility_conclusion")
                .and_then(Value::as_str)
        })
        .filter(|s| !s.trim().is_empty())
        .unwrap_or(project_name);
    let materials = feasibility
        .and_then(|v| v.get("materials"))
        .cloned()
        .unwrap_or_else(|| json!([]));

    let mut body = json!({
        "workflow_id": project_id,
        "thread_id": thread_id,
        "project_id": project_id,
        "project_name": project_name,
        "user_message": user_message,
        "draft": report_draft,
        "messages": [],
        "materials": materials,
    });
    if let Some(action) = action.filter(|value| !value.is_empty()) {
        body["action"] = json!(action);
    }
    body
}

#[cfg(test)]
mod workflow_tests {
    use super::*;

    #[test]
    fn workflow_start_body_reuses_existing_thread_and_report_draft() {
        let feasibility = json!({
            "thread_id": "thread-1",
            "report_draft": {
                "project_name": "Demo",
                "problem_definition": "Build a tool"
            },
            "materials": [{"name": "spec.md"}]
        });

        let body = workflow_start_body("project-1", "Demo", Some(&feasibility), Some("skip"));

        assert_eq!(body["workflow_id"], "project-1");
        assert_eq!(body["thread_id"], "thread-1");
        assert_eq!(body["user_message"], "Build a tool");
        assert_eq!(body["draft"]["project_name"], "Demo");
        assert_eq!(body["materials"][0]["name"], "spec.md");
        assert_eq!(body["action"], "skip");
    }

    #[test]
    fn workflow_start_body_falls_back_to_project_context() {
        let body = workflow_start_body("project-1", "Demo", None, None);

        assert_eq!(body["workflow_id"], "project-1");
        assert_eq!(body["thread_id"], "project-1");
        assert_eq!(body["user_message"], "Demo");
        assert!(body["draft"].as_object().unwrap().is_empty());
        assert!(body["materials"].as_array().unwrap().is_empty());
    }
}

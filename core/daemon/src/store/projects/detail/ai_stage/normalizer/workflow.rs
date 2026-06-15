use crate::store::helpers::{ensure_parent_dir, now_ms, to_json_string};
use crate::store::{Store, StoreResult};
use rusqlite::params;
use serde_json::{json, Value};
use std::fs;
use uuid::Uuid;

use super::sanitize_path_component;

pub(crate) fn persist_workflow_review(
    store: &Store,
    project_id: &str,
    stage_key: &str,
    label: &str,
    content: &Value,
) -> StoreResult<()> {
    let summary = content
        .get("summary")
        .and_then(Value::as_str)
        .unwrap_or("评审已完成");
    let approved = content
        .get("approved")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let requires_user_input = content
        .get("requires_user_input")
        .and_then(Value::as_bool)
        .unwrap_or(false);

    let issue_steps: Vec<Value> = content
        .get("issues")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .map(|issue| {
                    let severity = issue
                        .get("severity")
                        .and_then(Value::as_str)
                        .unwrap_or("major");
                    let area = issue.get("area").and_then(Value::as_str).unwrap_or("");
                    let description = issue
                        .get("description")
                        .and_then(Value::as_str)
                        .unwrap_or("-");
                    let title = if area.is_empty() {
                        format!("[{}] {}", severity, description)
                    } else {
                        format!("[{}] {} — {}", severity, area, description)
                    };
                    json!({
                        "title": title,
                        "status": if approved { "completed" } else { "blocked" }
                    })
                })
                .collect()
        })
        .unwrap_or_default();

    let mut contexts = Vec::new();
    contexts.push(if approved {
        "评审状态：通过".to_string()
    } else if requires_user_input {
        "评审状态：需要用户补充信息".to_string()
    } else {
        "评审状态：需要自动修正".to_string()
    });

    let mut risk_items = string_array(content.get("required_changes"));
    risk_items.extend(string_array(content.get("missing_information")));

    let work_units: Vec<Value> = content
        .get("issues")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .enumerate()
                .map(|(index, issue)| {
                    let recommendation = issue
                        .get("recommendation")
                        .and_then(Value::as_str)
                        .unwrap_or("");
                    json!({
                        "id": format!("review-{}", index),
                        "title": issue.get("description").and_then(Value::as_str).unwrap_or("评审问题"),
                        "agent_role": label,
                        "status": if approved { "completed" } else { "blocked" },
                        "progress": if approved { 1.0 } else { 0.0 },
                        "depends_on": [],
                        "current_output": recommendation,
                        "next_step": if approved { "" } else { "按评审意见进入下一轮修正" }
                    })
                })
                .collect()
        })
        .unwrap_or_default();

    persist_workflow_stage(
        store,
        project_id,
        stage_key,
        label,
        summary,
        json!(contexts),
        json!(issue_steps),
        json!(risk_items),
        content
            .get("required_changes")
            .cloned()
            .unwrap_or_else(|| json!([])),
        if approved {
            "评审通过"
        } else if requires_user_input {
            "等待用户补充"
        } else {
            "进入下一轮修正"
        },
        json!(work_units),
        render_review_markdown(label, content),
    )
}

pub(crate) fn persist_workflow_summary(
    store: &Store,
    project_id: &str,
    content: &Value,
) -> StoreResult<()> {
    let status = content
        .get("status")
        .and_then(Value::as_str)
        .unwrap_or("completed");
    let objective = if status == "completed" {
        "统一开发流程已完成"
    } else {
        "统一开发流程未完成"
    };
    let contexts = json!([
        format!(
            "PRD 评审轮次：{}",
            content
                .get("prd_review_iterations")
                .and_then(Value::as_i64)
                .unwrap_or(0)
        ),
        format!(
            "代码评审轮次：{}",
            content
                .get("code_review_iterations")
                .and_then(Value::as_i64)
                .unwrap_or(0)
        )
    ]);
    let step_progress = json!([
        {"title": content.get("prd_review_summary").and_then(Value::as_str).unwrap_or("PRD 评审完成"), "status": "completed"},
        {"title": content.get("code_review_summary").and_then(Value::as_str).unwrap_or("代码评审完成"), "status": "completed"}
    ]);

    persist_workflow_stage(
        store,
        project_id,
        "development:summary",
        "完成总结",
        objective,
        contexts,
        step_progress,
        json!([]),
        json!([]),
        "流程已归档",
        json!([]),
        render_summary_markdown(content),
    )
}

fn persist_workflow_stage(
    store: &Store,
    project_id: &str,
    stage_key: &str,
    label: &str,
    objective: &str,
    input_contexts: Value,
    step_progress: Value,
    risk_items: Value,
    event_flow: Value,
    primary_action: &str,
    work_units: Value,
    markdown: String,
) -> StoreResult<()> {
    let now = now_ms();
    let safe_project_id = sanitize_path_component(project_id);
    let safe_stage_key = sanitize_path_component(stage_key).replace(':', "-");
    let artifact_dir = store
        .paths
        .blobs_dir()
        .join("stage_artifacts")
        .join(&safe_project_id)
        .join(&safe_stage_key);
    let md_path = artifact_dir.join(format!("{}-snapshot.md", safe_stage_key));
    ensure_parent_dir(&md_path)?;
    fs::write(&md_path, &markdown).map_err(|err| format!("写入 {} 文档失败: {err}", label))?;

    let artifact_id = Uuid::new_v4().to_string();
    let artifact_kind = format!("{}-snapshot", safe_stage_key);
    let artifact_name = format!("{} 文档", label);
    store
        .conn
        .execute(
            "DELETE FROM stage_artifacts WHERE project_id = ?1 AND stage = ?2 AND kind = ?3",
            params![project_id, stage_key, &artifact_kind],
        )
        .map_err(|err| err.to_string())?;
    store
        .conn
        .execute(
            r#"
INSERT INTO stage_artifacts (
  id, project_id, stage, name, kind, updated_at_ms, file_path, content_type
) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, 'text/markdown')
"#,
            params![
                &artifact_id,
                project_id,
                stage_key,
                &artifact_name,
                &artifact_kind,
                now,
                md_path.display().to_string(),
            ],
        )
        .map_err(|err| err.to_string())?;

    let downloads_json = to_json_string(&json!([{
        "id": &artifact_id,
        "title": &artifact_name,
        "category": "stage_snapshot",
        "availability": "ready",
        "file_path": md_path.display().to_string(),
        "updated_at_ms": now,
        "content_type": "text/markdown"
    }]));

    store
        .conn
        .execute(
            r#"
INSERT INTO project_stages (
  project_id, stage, objective, input_contexts_json, step_progress_json,
  risk_items_json, event_flow_json, primary_action, secondary_actions_json,
  downloads_json, work_units_json, updated_at_ms
) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, '[]', ?9, ?10, ?11)
ON CONFLICT(project_id, stage) DO UPDATE SET
  objective = excluded.objective,
  input_contexts_json = excluded.input_contexts_json,
  step_progress_json = excluded.step_progress_json,
  risk_items_json = excluded.risk_items_json,
  event_flow_json = excluded.event_flow_json,
  primary_action = excluded.primary_action,
  secondary_actions_json = excluded.secondary_actions_json,
  downloads_json = excluded.downloads_json,
  work_units_json = excluded.work_units_json,
  updated_at_ms = excluded.updated_at_ms
"#,
            params![
                project_id,
                stage_key,
                objective,
                to_json_string(&input_contexts),
                to_json_string(&step_progress),
                to_json_string(&risk_items),
                to_json_string(&event_flow),
                primary_action,
                &downloads_json,
                to_json_string(&work_units),
                now,
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

fn render_review_markdown(label: &str, content: &Value) -> String {
    let mut md = format!("# {}\n\n", label);
    if let Some(summary) = content.get("summary").and_then(Value::as_str) {
        md.push_str(&format!("## 结论\n\n{}\n\n", summary));
    }
    if let Some(issues) = content.get("issues").and_then(Value::as_array) {
        md.push_str("## 问题\n\n");
        for issue in issues {
            let severity = issue
                .get("severity")
                .and_then(Value::as_str)
                .unwrap_or("major");
            let area = issue.get("area").and_then(Value::as_str).unwrap_or("");
            let description = issue
                .get("description")
                .and_then(Value::as_str)
                .unwrap_or("-");
            let recommendation = issue
                .get("recommendation")
                .and_then(Value::as_str)
                .unwrap_or("");
            md.push_str(&format!("- [{}] {} {}\n", severity, area, description));
            if !recommendation.is_empty() {
                md.push_str(&format!("  - 建议：{}\n", recommendation));
            }
        }
        md.push('\n');
    }
    append_string_list(&mut md, "必要修改", content.get("required_changes"));
    append_string_list(&mut md, "缺失信息", content.get("missing_information"));
    md
}

fn render_summary_markdown(content: &Value) -> String {
    let mut md = "# 统一流程完成总结\n\n".to_string();
    if let Some(status) = content.get("status").and_then(Value::as_str) {
        md.push_str(&format!("- 状态：{}\n", status));
    }
    if let Some(summary) = content.get("prd_review_summary").and_then(Value::as_str) {
        md.push_str(&format!("- PRD 评审：{}\n", summary));
    }
    if let Some(summary) = content.get("code_review_summary").and_then(Value::as_str) {
        md.push_str(&format!("- 代码评审：{}\n", summary));
    }
    md
}

fn append_string_list(md: &mut String, title: &str, value: Option<&Value>) {
    let items = string_array(value);
    if items.is_empty() {
        return;
    }
    md.push_str(&format!("## {}\n\n", title));
    for item in items {
        md.push_str(&format!("- {}\n", item));
    }
    md.push('\n');
}

fn string_array(value: Option<&Value>) -> Vec<String> {
    value
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(Value::as_str)
                .map(ToString::to_string)
                .collect()
        })
        .unwrap_or_default()
}

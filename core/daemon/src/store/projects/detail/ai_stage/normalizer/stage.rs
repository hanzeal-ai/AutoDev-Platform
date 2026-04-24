use crate::store::helpers::{ensure_parent_dir, stage_label, to_json_string};
use crate::store::{StageDefaults, Store, StoreResult};
use rusqlite::params;
use serde_json::{json, Value};
use std::fs;
use uuid::Uuid;

use super::sanitize_path_component;

// Stage content normalization has been moved to the Python AI Worker.
// See: core/ai-worker/autodev_ai/graphs/stage.py (normalizer_node)

pub(crate) fn persist_stage_content(
    store: &Store,
    project_id: &str,
    stage: &str,
    defaults: &StageDefaults,
    content: &Value,
) -> StoreResult<()> {
    let now = crate::store::helpers::now_ms();
    let label = stage_label(stage);

    // Sanitize path components to prevent path traversal
    let safe_project_id = sanitize_path_component(project_id);
    let safe_stage = sanitize_path_component(stage);

    let artifact_dir = store
        .paths
        .blobs_dir()
        .join("stage_artifacts")
        .join(&safe_project_id)
        .join(&safe_stage);
    let file_name = format!("{}-snapshot.md", stage);
    let file_path = artifact_dir.join(&file_name);
    ensure_parent_dir(&file_path)?;

    let markdown = render_stage_markdown(label, content);
    fs::write(&file_path, &markdown)
        .map_err(|err| format!("failed to write stage artifact {}: {}", file_path.display(), err))?;

    let file_path_str = file_path.display().to_string();
    let artifact_id = Uuid::new_v4().to_string();
    let artifact_name = format!("{} 文档", label);
    let artifact_kind = format!("{}-snapshot", stage);

    store
        .conn
        .execute(
            "DELETE FROM stage_artifacts WHERE project_id = ?1 AND stage = ?2 AND kind = ?3",
            params![project_id, stage, &artifact_kind],
        )
        .map_err(|err| err.to_string())?;

    store
        .conn
        .execute(
            r#"
INSERT INTO stage_artifacts (
  id, project_id, stage, name, kind, updated_at_ms, file_path, content_type
) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
"#,
            params![
                &artifact_id,
                project_id,
                stage,
                &artifact_name,
                &artifact_kind,
                now,
                &file_path_str,
                "text/markdown"
            ],
        )
        .map_err(|err| err.to_string())?;

    let downloads_json = to_json_string(&json!([{
        "id": &artifact_id,
        "title": &artifact_name,
        "category": "stage_snapshot",
        "availability": "ready",
        "file_path": &file_path_str,
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
) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
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
                stage,
                content
                    .get("objective")
                    .and_then(Value::as_str)
                    .unwrap_or(defaults.objective),
                to_json_string(
                    content
                        .get("input_contexts")
                        .unwrap_or(&json!(defaults.input_contexts))
                ),
                to_json_string(
                    content
                        .get("step_progress")
                        .unwrap_or(&defaults.step_progress)
                ),
                to_json_string(
                    content
                        .get("risk_items")
                        .unwrap_or(&json!(defaults.risk_items))
                ),
                to_json_string(
                    content
                        .get("event_flow")
                        .unwrap_or(&json!(defaults.event_flow))
                ),
                content
                    .get("primary_action")
                    .and_then(Value::as_str)
                    .unwrap_or(defaults.primary_action),
                to_json_string(
                    content
                        .get("secondary_actions")
                        .unwrap_or(&json!(defaults.secondary_actions))
                ),
                &downloads_json,
                to_json_string(content.get("work_units").unwrap_or(&json!([]))),
                now,
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}


fn render_stage_markdown(label: &str, content: &Value) -> String {
    let mut md = String::new();
    md.push_str(&format!("# {} 阶段文档\n\n", label));

    if let Some(objective) = content.get("objective").and_then(Value::as_str) {
        if !objective.is_empty() {
            md.push_str(&format!("## 目标\n\n{}\n\n", objective));
        }
    }

    if let Some(items) = content.get("input_contexts").and_then(Value::as_array) {
        let items: Vec<&str> = items.iter().filter_map(Value::as_str).collect();
        if !items.is_empty() {
            md.push_str("## 输入上下文\n\n");
            for item in items {
                md.push_str(&format!("- {}\n", item));
            }
            md.push('\n');
        }
    }

    if let Some(steps) = content.get("step_progress").and_then(Value::as_array) {
        if !steps.is_empty() {
            md.push_str("## 执行步骤\n\n");
            for step in steps {
                let title = step.get("title").and_then(Value::as_str).unwrap_or("-");
                let status = step.get("status").and_then(Value::as_str).unwrap_or("queued");
                md.push_str(&format!("- [{}] {}\n", status, title));
            }
            md.push('\n');
        }
    }

    if let Some(items) = content.get("risk_items").and_then(Value::as_array) {
        let items: Vec<&str> = items.iter().filter_map(Value::as_str).collect();
        if !items.is_empty() {
            md.push_str("## 风险项\n\n");
            for item in items {
                md.push_str(&format!("- {}\n", item));
            }
            md.push('\n');
        }
    }

    if let Some(units) = content.get("work_units").and_then(Value::as_array) {
        if !units.is_empty() {
            md.push_str("## 工作单元\n\n");
            for unit in units {
                let title = unit.get("title").and_then(Value::as_str).unwrap_or("-");
                let role = unit.get("agent_role").and_then(Value::as_str).unwrap_or("-");
                let status = unit.get("status").and_then(Value::as_str).unwrap_or("queued");
                md.push_str(&format!("### {}\n\n", title));
                md.push_str(&format!("- Agent: {}\n", role));
                md.push_str(&format!("- 状态: {}\n", status));
                if let Some(next) = unit.get("next_step").and_then(Value::as_str) {
                    md.push_str(&format!("- 下一步: {}\n", next));
                }
                md.push('\n');
            }
        }
    }

    md
}


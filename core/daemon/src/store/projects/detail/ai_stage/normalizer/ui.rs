#![allow(dead_code)]
use crate::store::helpers::{ensure_parent_dir, now_ms, to_json_string};
use crate::store::{StageDefaults, Store, StoreResult};
use rusqlite::params;
use serde_json::{json, Value};
use std::fs;
use uuid::Uuid;

use super::sanitize_path_component;

/// Persist UI stage content split into sub-step compound keys.
///
/// After generic `persist_stage_content` stores everything under the base "ui" key,
/// this function splits relevant content into `ui:page_map` and `ui:interaction`.
///
/// page_map  ← "页面地图" input_context, page-related steps
/// interaction ← "关键组件", "核心交互流", "视觉方向", "待确认设计点"
pub(crate) fn persist_ui_sub_steps(
    store: &Store,
    project_id: &str,
    content: &Value,
    defaults: &StageDefaults,
) -> StoreResult<()> {
    let now = now_ms();

    // --- Shared helpers ---
    let all_contexts = content
        .get("input_contexts")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_else(|| {
            defaults
                .input_contexts
                .iter()
                .map(|s| Value::String(s.to_string()))
                .collect()
        });

    let all_steps = content
        .get("step_progress")
        .cloned()
        .unwrap_or_else(|| defaults.step_progress.clone());

    // --- Sub-step 1: ui:page_map ---
    // page_map gets "页面地图" context and page-structure-related steps
    let page_map_contexts: Vec<Value> = all_contexts
        .iter()
        .filter(|c| {
            let s = c.as_str().unwrap_or("");
            s.starts_with("页面地图")
        })
        .cloned()
        .collect();

    let page_map_steps: Vec<Value> = all_steps
        .as_array()
        .map(|steps| {
            steps
                .iter()
                .filter(|s| {
                    let title = s.get("title").and_then(Value::as_str).unwrap_or("");
                    title.contains("页面") || title.contains("结构")
                })
                .cloned()
                .collect()
        })
        .unwrap_or_default();

    let page_map_objective = content
        .get("objective")
        .and_then(Value::as_str)
        .unwrap_or(defaults.objective);

    store.conn.execute(
        r#"
INSERT INTO project_stages (
  project_id, stage, objective, input_contexts_json, step_progress_json,
  risk_items_json, event_flow_json, primary_action, secondary_actions_json,
  downloads_json, work_units_json, updated_at_ms
) VALUES (?1, 'ui:page_map', ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
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
            page_map_objective,
            to_json_string(&page_map_contexts),
            to_json_string(&page_map_steps),
            to_json_string(content.get("risk_items").unwrap_or(&json!([]))),
            to_json_string(content.get("event_flow").unwrap_or(&json!([]))),
            content.get("primary_action").and_then(Value::as_str).unwrap_or(defaults.primary_action),
            to_json_string(content.get("secondary_actions").unwrap_or(&json!([]))),
            "[]",
            to_json_string(content.get("work_units").unwrap_or(&json!([]))),
            now,
        ],
    ).map_err(|err| err.to_string())?;

    // --- Sub-step 2: ui:interaction ---
    // interaction gets "关键组件", "核心交互流", "视觉方向", "待确认设计点"
    let interaction_contexts: Vec<Value> = all_contexts
        .iter()
        .filter(|c| {
            let s = c.as_str().unwrap_or("");
            s.starts_with("关键组件")
                || s.starts_with("核心交互流")
                || s.starts_with("视觉方向")
                || s.starts_with("待确认设计点")
        })
        .cloned()
        .collect();

    let interaction_steps: Vec<Value> = all_steps
        .as_array()
        .map(|steps| {
            steps
                .iter()
                .filter(|s| {
                    let title = s.get("title").and_then(Value::as_str).unwrap_or("");
                    title.contains("交互") || title.contains("设计") || title.contains("组件")
                })
                .cloned()
                .collect()
        })
        .unwrap_or_default();

    // Write interaction markdown artifact
    let safe_project_id = sanitize_path_component(project_id);
    let artifact_dir = store
        .paths
        .blobs_dir()
        .join("stage_artifacts")
        .join(&safe_project_id)
        .join("ui");
    let md_path = artifact_dir.join("interaction-snapshot.md");
    ensure_parent_dir(&md_path)?;

    let markdown = render_interaction_markdown(&interaction_contexts);
    fs::write(&md_path, &markdown)
        .map_err(|err| format!("写入 interaction-snapshot.md 失败: {err}"))?;

    let artifact_id = Uuid::new_v4().to_string();
    store.conn.execute(
        "DELETE FROM stage_artifacts WHERE project_id = ?1 AND stage = 'ui:interaction' AND kind = 'interaction-snapshot'",
        params![project_id],
    ).map_err(|err| err.to_string())?;

    store.conn.execute(
        r#"INSERT INTO stage_artifacts (id, project_id, stage, name, kind, updated_at_ms, file_path, content_type)
           VALUES (?1, ?2, 'ui:interaction', '交互稿文档', 'interaction-snapshot', ?3, ?4, 'text/markdown')"#,
        params![&artifact_id, project_id, now, md_path.display().to_string()],
    ).map_err(|err| err.to_string())?;

    let downloads_json = to_json_string(&json!([{
        "id": &artifact_id,
        "title": "交互稿文档",
        "category": "stage_snapshot",
        "availability": "ready",
        "file_path": md_path.display().to_string(),
        "updated_at_ms": now,
        "content_type": "text/markdown"
    }]));

    store.conn.execute(
        r#"
INSERT INTO project_stages (
  project_id, stage, objective, input_contexts_json, step_progress_json,
  risk_items_json, event_flow_json, primary_action, secondary_actions_json,
  downloads_json, work_units_json, updated_at_ms
) VALUES (?1, 'ui:interaction', ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
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
            "完成交互方案与关键组件定义",
            to_json_string(&interaction_contexts),
            to_json_string(&interaction_steps),
            to_json_string(content.get("risk_items").unwrap_or(&json!([]))),
            to_json_string(content.get("event_flow").unwrap_or(&json!([]))),
            content.get("primary_action").and_then(Value::as_str).unwrap_or(defaults.primary_action),
            to_json_string(content.get("secondary_actions").unwrap_or(&json!([]))),
            &downloads_json,
            to_json_string(content.get("work_units").unwrap_or(&json!([]))),
            now,
        ],
    ).map_err(|err| err.to_string())?;

    crate::logger::info(&format!(
        "ui_sub_steps: persisted page_map + interaction for project {}",
        project_id
    ));

    Ok(())
}

fn render_interaction_markdown(contexts: &[Value]) -> String {
    let mut md = String::new();
    md.push_str("# 交互稿\n\n");

    for ctx in contexts {
        if let Some(s) = ctx.as_str() {
            // Format: "关键组件：xxx" → section header + content
            if let Some(pos) = s.find('：') {
                let (key, value) = s.split_at(pos);
                let value = &value['：'.len_utf8()..]; // skip the ：
                md.push_str(&format!("## {}\n\n{}\n\n", key, value));
            } else if let Some(pos) = s.find(':') {
                let (key, value) = s.split_at(pos);
                let value = &value[1..];
                md.push_str(&format!("## {}\n\n{}\n\n", key, value.trim()));
            } else {
                md.push_str(&format!("- {}\n", s));
            }
        }
    }

    md
}

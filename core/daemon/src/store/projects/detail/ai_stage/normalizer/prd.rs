#![allow(dead_code)]
use crate::store::helpers::{ensure_parent_dir, now_ms, to_json_string};
use crate::store::{Store, StoreResult};
use rusqlite::params;
use serde_json::{json, Value};
use std::fs;
use uuid::Uuid;

use super::sanitize_path_component;

/// Persist PRD structured content: writes prd.json (kind=prd-structured) + prd.md (kind=prd-snapshot).
/// Also upserts project_stages row with PRD summary as objective.
pub(crate) fn persist_prd_content(
    store: &Store,
    project_id: &str,
    content: &Value,
) -> StoreResult<()> {
    let now = now_ms();
    let safe_project_id = sanitize_path_component(project_id);

    let artifact_dir = store
        .paths
        .blobs_dir()
        .join("stage_artifacts")
        .join(&safe_project_id)
        .join("prd");

    // 1. Write prd.json (structured)
    let json_path = artifact_dir.join("prd.json");
    ensure_parent_dir(&json_path)?;
    let json_content = serde_json::to_string_pretty(content)
        .map_err(|err| format!("PRD JSON 序列化失败: {err}"))?;
    fs::write(&json_path, &json_content).map_err(|err| format!("写入 prd.json 失败: {err}"))?;

    // 2. Write prd.md (human-readable snapshot)
    let md_path = artifact_dir.join("prd.md");
    let markdown = render_prd_markdown(content);
    fs::write(&md_path, &markdown).map_err(|err| format!("写入 prd.md 失败: {err}"))?;

    // 3. Upsert stage_artifacts — structured JSON
    let json_artifact_id = Uuid::new_v4().to_string();
    store.conn.execute(
        "DELETE FROM stage_artifacts WHERE project_id = ?1 AND stage = 'prd' AND kind = 'prd-structured'",
        params![project_id],
    ).map_err(|err| err.to_string())?;

    store.conn.execute(
        r#"INSERT INTO stage_artifacts (id, project_id, stage, name, kind, updated_at_ms, file_path, content_type)
           VALUES (?1, ?2, 'prd', 'PRD 结构化数据', 'prd-structured', ?3, ?4, 'application/json')"#,
        params![&json_artifact_id, project_id, now, json_path.display().to_string()],
    ).map_err(|err| err.to_string())?;

    // 4. Upsert stage_artifacts — markdown snapshot
    let md_artifact_id = Uuid::new_v4().to_string();
    store.conn.execute(
        "DELETE FROM stage_artifacts WHERE project_id = ?1 AND stage = 'prd' AND kind = 'prd-snapshot'",
        params![project_id],
    ).map_err(|err| err.to_string())?;

    store.conn.execute(
        r#"INSERT INTO stage_artifacts (id, project_id, stage, name, kind, updated_at_ms, file_path, content_type)
           VALUES (?1, ?2, 'prd', 'PRD 文档', 'prd-snapshot', ?3, ?4, 'text/markdown')"#,
        params![&md_artifact_id, project_id, now, md_path.display().to_string()],
    ).map_err(|err| err.to_string())?;

    // 5. Upsert project_stages row — format for display pipeline
    let summary = content
        .get("summary")
        .and_then(Value::as_str)
        .unwrap_or("PRD 已生成");

    // input_contexts: goals + non_goals as labeled strings
    let mut display_contexts: Vec<String> = Vec::new();
    if let Some(goals) = content.get("goals").and_then(Value::as_array) {
        for g in goals.iter().filter_map(Value::as_str) {
            display_contexts.push(format!("目标：{}", g));
        }
    }
    if let Some(non_goals) = content.get("non_goals").and_then(Value::as_array) {
        for ng in non_goals.iter().filter_map(Value::as_str) {
            display_contexts.push(format!("非目标：{}", ng));
        }
    }
    let input_contexts_json = to_json_string(&display_contexts);

    // step_progress: scope_items as [{title, status}]
    let step_progress: Vec<Value> = content
        .get("scope_items")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .map(|item| {
                    let priority = item.get("priority").and_then(Value::as_str).unwrap_or("P1");
                    let category = item.get("category").and_then(Value::as_str).unwrap_or("");
                    let name = item.get("name").and_then(Value::as_str).unwrap_or("-");
                    let desc = item
                        .get("description")
                        .and_then(Value::as_str)
                        .unwrap_or("");
                    let title = if desc.is_empty() {
                        format!("[{}/{}] {}", priority, category, name)
                    } else {
                        format!("[{}/{}] {} — {}", priority, category, name, desc)
                    };
                    json!({"title": title, "status": "queued"})
                })
                .collect()
        })
        .unwrap_or_default();
    let step_progress_json = to_json_string(&step_progress);

    // risk_items: technical_constraints as string array (already correct format)
    let constraints_json =
        to_json_string(content.get("technical_constraints").unwrap_or(&json!([])));

    // event_flow: acceptance_criteria as labeled strings
    let event_flow: Vec<String> = content
        .get("acceptance_criteria")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .map(|ac| {
                    let criticality = ac
                        .get("criticality")
                        .and_then(Value::as_str)
                        .unwrap_or("must");
                    let statement = ac.get("statement").and_then(Value::as_str).unwrap_or("-");
                    format!("[{}] {}", criticality, statement)
                })
                .collect()
        })
        .unwrap_or_default();
    let event_flow_json = to_json_string(&event_flow);

    // secondary_actions: milestones as labeled strings
    let milestones: Vec<String> = content
        .get("milestones")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .map(|ms| {
                    let title = ms.get("title").and_then(Value::as_str).unwrap_or("-");
                    let desc = ms
                        .get("target_description")
                        .and_then(Value::as_str)
                        .unwrap_or("");
                    if desc.is_empty() {
                        title.to_string()
                    } else {
                        format!("{} — {}", title, desc)
                    }
                })
                .collect()
        })
        .unwrap_or_default();
    let milestones_json = to_json_string(&milestones);

    let downloads_json = to_json_string(&json!([
        {
            "id": &json_artifact_id,
            "title": "PRD 结构化数据",
            "category": "prd_structured",
            "availability": "ready",
            "file_path": json_path.display().to_string(),
            "updated_at_ms": now,
            "content_type": "application/json"
        },
        {
            "id": &md_artifact_id,
            "title": "PRD 文档",
            "category": "stage_snapshot",
            "availability": "ready",
            "file_path": md_path.display().to_string(),
            "updated_at_ms": now,
            "content_type": "text/markdown"
        }
    ]));

    store
        .conn
        .execute(
            r#"
INSERT INTO project_stages (
  project_id, stage, objective, input_contexts_json, step_progress_json,
  risk_items_json, event_flow_json, primary_action, secondary_actions_json,
  downloads_json, work_units_json, updated_at_ms
) VALUES (?1, 'prd', ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
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
                summary,
                &input_contexts_json, // goals + non_goals
                &step_progress_json,  // scope_items as [{title, status}]
                &constraints_json,    // technical_constraints
                &event_flow_json,     // acceptance_criteria as strings
                "PRD 已完成",
                &milestones_json, // milestones as strings
                &downloads_json,
                "[]", // work_units — empty for PRD
                now,
            ],
        )
        .map_err(|err| err.to_string())?;

    Ok(())
}

fn render_prd_markdown(content: &Value) -> String {
    let mut md = String::new();
    let name = content
        .get("project_name")
        .and_then(Value::as_str)
        .unwrap_or("项目");
    md.push_str(&format!("# {} — PRD\n\n", name));

    if let Some(summary) = content.get("summary").and_then(Value::as_str) {
        md.push_str(&format!("## 概述\n\n{}\n\n", summary));
    }

    if let Some(goals) = content.get("goals").and_then(Value::as_array) {
        md.push_str("## 目标\n\n");
        for g in goals.iter().filter_map(Value::as_str) {
            md.push_str(&format!("- {}\n", g));
        }
        md.push('\n');
    }

    if let Some(non_goals) = content.get("non_goals").and_then(Value::as_array) {
        md.push_str("## 不做的事\n\n");
        for g in non_goals.iter().filter_map(Value::as_str) {
            md.push_str(&format!("- {}\n", g));
        }
        md.push('\n');
    }

    if let Some(items) = content.get("scope_items").and_then(Value::as_array) {
        md.push_str("## 功能清单\n\n");
        md.push_str("| ID | 名称 | 优先级 | 类别 | 描述 |\n");
        md.push_str("|---|---|---|---|---|\n");
        for item in items {
            let id = item.get("id").and_then(Value::as_str).unwrap_or("-");
            let name = item.get("name").and_then(Value::as_str).unwrap_or("-");
            let priority = item.get("priority").and_then(Value::as_str).unwrap_or("P1");
            let category = item.get("category").and_then(Value::as_str).unwrap_or("-");
            let desc = item
                .get("description")
                .and_then(Value::as_str)
                .unwrap_or("");
            md.push_str(&format!(
                "| {} | {} | {} | {} | {} |\n",
                id, name, priority, category, desc
            ));
        }
        md.push('\n');
    }

    if let Some(constraints) = content
        .get("technical_constraints")
        .and_then(Value::as_array)
    {
        md.push_str("## 技术约束\n\n");
        for c in constraints.iter().filter_map(Value::as_str) {
            md.push_str(&format!("- {}\n", c));
        }
        md.push('\n');
    }

    if let Some(criteria) = content.get("acceptance_criteria").and_then(Value::as_array) {
        md.push_str("## 验收标准\n\n");
        for ac in criteria {
            let statement = ac.get("statement").and_then(Value::as_str).unwrap_or("-");
            let crit = ac
                .get("criticality")
                .and_then(Value::as_str)
                .unwrap_or("must");
            md.push_str(&format!("- [{}] {}\n", crit, statement));
        }
        md.push('\n');
    }

    if let Some(milestones) = content.get("milestones").and_then(Value::as_array) {
        md.push_str("## 里程碑\n\n");
        for ms in milestones {
            let title = ms.get("title").and_then(Value::as_str).unwrap_or("-");
            let desc = ms
                .get("target_description")
                .and_then(Value::as_str)
                .unwrap_or("");
            md.push_str(&format!("### {}\n\n{}\n\n", title, desc));
        }
    }

    md
}

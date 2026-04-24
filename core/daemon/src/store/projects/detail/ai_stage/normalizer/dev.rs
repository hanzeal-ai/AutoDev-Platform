#![allow(dead_code)]
use crate::store::helpers::{ensure_parent_dir, now_ms, to_json_string};
use crate::store::{Store, StoreResult};
use rusqlite::params;
use serde_json::{json, Value};
use std::fs;
use uuid::Uuid;

use super::sanitize_path_component;

/// Persist development task breakdown (sub-step 1): architecture, modules, API contracts, scaffold.
/// Stores data under stage key `development:task_breakdown`.
pub(crate) fn persist_development_task_breakdown(
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
        .join("development");

    // 1. Write dev-plan.json (structured)
    let json_path = artifact_dir.join("dev-plan.json");
    ensure_parent_dir(&json_path)?;
    let json_content = serde_json::to_string_pretty(content)
        .map_err(|err| format!("开发方案 JSON 序列化失败: {err}"))?;
    fs::write(&json_path, &json_content)
        .map_err(|err| format!("写入 dev-plan.json 失败: {err}"))?;

    // 2. Write scaffold files to disk
    let scaffold_dir = artifact_dir.join("scaffold");
    if let Some(files) = content.get("scaffold_files").and_then(Value::as_array) {
        for file in files {
            let path = file.get("path").and_then(Value::as_str).unwrap_or("");
            let file_content = file.get("content").and_then(Value::as_str).unwrap_or("");
            if path.is_empty() || file_content.is_empty() {
                continue;
            }
            // Sanitize path to prevent traversal
            let safe_path = path
                .replace("..", "")
                .replace('\0', "")
                .trim_start_matches('/').trim_start_matches('\\').to_string();

            let full_path = scaffold_dir.join(&safe_path);
            if let Err(err) = ensure_parent_dir(&full_path) {
                crate::logger::error_fields(
                    "scaffold_write_parent_dir_failed",
                    &[("path", safe_path.clone()), ("err", err)],
                );
                continue;
            }
            if let Err(err) = fs::write(&full_path, file_content) {
                crate::logger::error_fields(
                    "scaffold_write_failed",
                    &[("path", safe_path), ("err", err.to_string())],
                );
            }
        }
    }

    // 3. Write dev-plan.md (human-readable)
    let md_path = artifact_dir.join("dev-plan.md");
    let markdown = render_dev_markdown(content);
    fs::write(&md_path, &markdown)
        .map_err(|err| format!("写入 dev-plan.md 失败: {err}"))?;

    // 4. Upsert stage_artifacts — structured JSON
    let json_artifact_id = Uuid::new_v4().to_string();
    store.conn.execute(
        "DELETE FROM stage_artifacts WHERE project_id = ?1 AND stage = 'development:task_breakdown' AND kind = 'dev-structured'",
        params![project_id],
    ).map_err(|err| err.to_string())?;

    store.conn.execute(
        r#"INSERT INTO stage_artifacts (id, project_id, stage, name, kind, updated_at_ms, file_path, content_type)
           VALUES (?1, ?2, 'development:task_breakdown', '研发方案', 'dev-structured', ?3, ?4, 'application/json')"#,
        params![&json_artifact_id, project_id, now, json_path.display().to_string()],
    ).map_err(|err| err.to_string())?;

    // 5. Upsert stage_artifacts — markdown snapshot
    let md_artifact_id = Uuid::new_v4().to_string();
    store.conn.execute(
        "DELETE FROM stage_artifacts WHERE project_id = ?1 AND stage = 'development:task_breakdown' AND kind = 'dev-snapshot'",
        params![project_id],
    ).map_err(|err| err.to_string())?;

    store.conn.execute(
        r#"INSERT INTO stage_artifacts (id, project_id, stage, name, kind, updated_at_ms, file_path, content_type)
           VALUES (?1, ?2, 'development:task_breakdown', '研发方案文档', 'dev-snapshot', ?3, ?4, 'text/markdown')"#,
        params![&md_artifact_id, project_id, now, md_path.display().to_string()],
    ).map_err(|err| err.to_string())?;

    // 6. Upsert project_stages row — format for display pipeline
    let arch_summary = content.get("architecture_summary").and_then(Value::as_str).unwrap_or("研发方案已生成");

    // input_contexts: tech_stack as labeled strings
    let mut tech_lines: Vec<String> = Vec::new();
    if let Some(ts) = content.get("tech_stack") {
        if let Some(lang) = ts.get("language").and_then(Value::as_str) {
            if !lang.is_empty() { tech_lines.push(format!("语言：{}", lang)); }
        }
        if let Some(fw) = ts.get("framework").and_then(Value::as_str) {
            if !fw.is_empty() { tech_lines.push(format!("框架：{}", fw)); }
        }
        if let Some(bt) = ts.get("build_tool").and_then(Value::as_str) {
            if !bt.is_empty() { tech_lines.push(format!("构建工具：{}", bt)); }
        }
        if let Some(pm) = ts.get("package_manager").and_then(Value::as_str) {
            if !pm.is_empty() { tech_lines.push(format!("包管理器：{}", pm)); }
        }
        if let Some(rt) = ts.get("runtime").and_then(Value::as_str) {
            if !rt.is_empty() { tech_lines.push(format!("运行时：{}", rt)); }
        }
        if let Some(additional) = ts.get("additional").and_then(Value::as_array) {
            for a in additional.iter().filter_map(Value::as_str) {
                tech_lines.push(format!("附加：{}", a));
            }
        }
    }
    let tech_display_json = to_json_string(&tech_lines);

    // step_progress: modules as [{title, status}]
    let module_steps: Vec<Value> = content
        .get("modules")
        .and_then(Value::as_array)
        .map(|items| {
            items.iter().map(|m| {
                let name = m.get("name").and_then(Value::as_str).unwrap_or("-");
                let resp = m.get("responsibility").and_then(Value::as_str).unwrap_or("");
                let title = if resp.is_empty() {
                    name.to_string()
                } else {
                    format!("{} — {}", name, resp)
                };
                json!({"title": title, "status": "queued"})
            }).collect()
        })
        .unwrap_or_default();
    let modules_display_json = to_json_string(&module_steps);

    // risk_items: api_contracts as labeled strings
    let api_lines: Vec<String> = content
        .get("api_contracts")
        .and_then(Value::as_array)
        .map(|items| {
            items.iter().map(|api| {
                let method = api.get("method").and_then(Value::as_str).unwrap_or("GET");
                let path = api.get("path").and_then(Value::as_str).unwrap_or("-");
                let desc = api.get("description").and_then(Value::as_str).unwrap_or("");
                if desc.is_empty() {
                    format!("{} {}", method, path)
                } else {
                    format!("{} {} — {}", method, path, desc)
                }
            }).collect()
        })
        .unwrap_or_default();
    let apis_display_json = to_json_string(&api_lines);

    // work_units: scaffold_files as work unit objects
    let scaffold_units: Vec<Value> = content
        .get("scaffold_files")
        .and_then(Value::as_array)
        .map(|items| {
            items.iter().enumerate().map(|(i, sf)| {
                let path = sf.get("path").and_then(Value::as_str).unwrap_or("-");
                let purpose = sf.get("purpose").and_then(Value::as_str).unwrap_or("");
                let lang = sf.get("language").and_then(Value::as_str).unwrap_or("");
                let agent_role = if lang.is_empty() {
                    "脚手架".to_string()
                } else {
                    format!("脚手架 ({})", lang)
                };
                json!({
                    "id": format!("scaffold-{}", i),
                    "title": path,
                    "agent_role": agent_role,
                    "status": "completed",
                    "progress": 1.0,
                    "depends_on": [],
                    "current_output": purpose,
                    "next_step": ""
                })
            }).collect()
        })
        .unwrap_or_default();
    let scaffold_display_json = to_json_string(&scaffold_units);

    let downloads_json = to_json_string(&json!([
        {
            "id": &json_artifact_id,
            "title": "研发方案",
            "category": "dev_structured",
            "availability": "ready",
            "file_path": json_path.display().to_string(),
            "updated_at_ms": now,
            "content_type": "application/json"
        },
        {
            "id": &md_artifact_id,
            "title": "研发方案文档",
            "category": "stage_snapshot",
            "availability": "ready",
            "file_path": md_path.display().to_string(),
            "updated_at_ms": now,
            "content_type": "text/markdown"
        }
    ]));

    store.conn.execute(
        r#"
INSERT INTO project_stages (
  project_id, stage, objective, input_contexts_json, step_progress_json,
  risk_items_json, event_flow_json, primary_action, secondary_actions_json,
  downloads_json, work_units_json, updated_at_ms
) VALUES (?1, 'development:task_breakdown', ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
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
            arch_summary,
            &tech_display_json,     // tech_stack as strings
            &modules_display_json,  // modules as [{title, status}]
            &apis_display_json,     // api_contracts as strings
            "[]",                   // event_flow
            "任务拆分已完成",
            "[]",                   // secondary_actions
            &downloads_json,
            &scaffold_display_json, // scaffold_files as work units
            now,
        ],
    ).map_err(|err| err.to_string())?;

    Ok(())
}

/// Persist development coding result (sub-step 2): implementation code files.

/// Stores data under stage key `development:coding`.
pub(crate) fn persist_development_coding(
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
        .join("development")
        .join("code");

    // 1. Write code files to disk
    let mut code_units: Vec<Value> = Vec::new();
    if let Some(files) = content.get("code_files").and_then(Value::as_array) {
        for (i, file) in files.iter().enumerate() {
            let path = file.get("path").and_then(Value::as_str).unwrap_or("");
            let file_content = file.get("content").and_then(Value::as_str).unwrap_or("");
            let purpose = file.get("purpose").and_then(Value::as_str).unwrap_or("");
            let lang = file.get("language").and_then(Value::as_str).unwrap_or("");
            let module_id = file.get("module_id").and_then(Value::as_str).unwrap_or("");

            if path.is_empty() || file_content.is_empty() {
                continue;
            }

            let safe_path = path.replace("..", "").replace('\0', "").trim_start_matches('/').trim_start_matches('\\').to_string();
            let full_path = artifact_dir.join(&safe_path);
            if let Err(err) = ensure_parent_dir(&full_path) {
                crate::logger::error_fields(
                    "code_write_parent_dir_failed",
                    &[("path", safe_path.clone()), ("err", err)],
                );
                continue;
            }
            if let Err(err) = fs::write(&full_path, file_content) {
                crate::logger::error_fields(
                    "code_write_failed",
                    &[("path", safe_path.clone()), ("err", err.to_string())],
                );
                continue;
            }

            let agent_role = if lang.is_empty() {
                "编码".to_string()
            } else {
                format!("编码 ({})", lang)
            };
            code_units.push(json!({
                "id": format!("code-{}", i),
                "title": path,
                "agent_role": agent_role,
                "status": "completed",
                "progress": 1.0,
                "depends_on": [],
                "current_output": if !module_id.is_empty() {
                    format!("模块: {} — {}", module_id, purpose)
                } else {
                    purpose.to_string()
                },
                "next_step": ""
            }));
        }
    }

    // 2. Write coding summary markdown
    let md_path = artifact_dir.join("coding-summary.md");
    ensure_parent_dir(&md_path)?;
    let markdown = render_coding_markdown(content);
    fs::write(&md_path, &markdown)
        .map_err(|err| format!("写入 coding-summary.md 失败: {err}"))?;

    // 3. Upsert stage_artifacts — coding snapshot
    let md_artifact_id = Uuid::new_v4().to_string();
    store.conn.execute(
        "DELETE FROM stage_artifacts WHERE project_id = ?1 AND stage = 'development:coding' AND kind = 'coding-snapshot'",
        params![project_id],
    ).map_err(|err| err.to_string())?;

    store.conn.execute(
        r#"INSERT INTO stage_artifacts (id, project_id, stage, name, kind, updated_at_ms, file_path, content_type)
           VALUES (?1, ?2, 'development:coding', '代码生成文档', 'coding-snapshot', ?3, ?4, 'text/markdown')"#,
        params![&md_artifact_id, project_id, now, md_path.display().to_string()],
    ).map_err(|err| err.to_string())?;

    // 4. Upsert project_stages row
    let summary = content.get("summary").and_then(Value::as_str).unwrap_or("代码生成已完成");

    // step_progress: modules/files as step items
    let step_items: Vec<Value> = content
        .get("code_files")
        .and_then(Value::as_array)
        .map(|items| {
            items.iter().map(|f| {
                let path = f.get("path").and_then(Value::as_str).unwrap_or("-");
                let module_id = f.get("module_id").and_then(Value::as_str).unwrap_or("");
                let title = if module_id.is_empty() {
                    path.to_string()
                } else {
                    format!("[{}] {}", module_id, path)
                };
                json!({"title": title, "status": "completed"})
            }).collect()
        })
        .unwrap_or_default();
    let step_progress_json = to_json_string(&step_items);

    let downloads_json = to_json_string(&json!([{
        "id": &md_artifact_id,
        "title": "代码生成文档",
        "category": "stage_snapshot",
        "availability": "ready",
        "file_path": md_path.display().to_string(),
        "updated_at_ms": now,
        "content_type": "text/markdown"
    }]));

    let code_units_json = to_json_string(&code_units);

    store.conn.execute(
        r#"
INSERT INTO project_stages (
  project_id, stage, objective, input_contexts_json, step_progress_json,
  risk_items_json, event_flow_json, primary_action, secondary_actions_json,
  downloads_json, work_units_json, updated_at_ms
) VALUES (?1, 'development:coding', ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
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
            "[]",               // input_contexts
            &step_progress_json, // code files as step items
            "[]",               // risk_items
            "[]",               // event_flow
            "代码生成已完成",
            "[]",               // secondary_actions
            &downloads_json,
            &code_units_json,   // code files as work units
            now,
        ],
    ).map_err(|err| err.to_string())?;

    Ok(())
}

fn render_coding_markdown(content: &Value) -> String {
    let mut md = String::new();
    md.push_str("# 代码生成结果\n\n");

    if let Some(summary) = content.get("summary").and_then(Value::as_str) {
        md.push_str(&format!("## 概述\n\n{}\n\n", summary));
    }

    if let Some(files) = content.get("code_files").and_then(Value::as_array) {
        md.push_str("## 生成的文件\n\n");
        for f in files {
            let path = f.get("path").and_then(Value::as_str).unwrap_or("-");
            let purpose = f.get("purpose").and_then(Value::as_str).unwrap_or("");
            let lang = f.get("language").and_then(Value::as_str).unwrap_or("");
            let module_id = f.get("module_id").and_then(Value::as_str).unwrap_or("");

            md.push_str(&format!("### `{}`\n\n", path));
            if !module_id.is_empty() {
                md.push_str(&format!("模块: {}\n\n", module_id));
            }
            if !purpose.is_empty() {
                md.push_str(&format!("用途: {}\n\n", purpose));
            }
            if let Some(code) = f.get("content").and_then(Value::as_str) {
                if !code.is_empty() {
                    md.push_str(&format!("```{}\n{}\n```\n\n", lang, code));
                }
            }
        }
    }

    md
}

fn render_dev_markdown(content: &Value) -> String {
    let mut md = String::new();
    md.push_str("# 研发方案\n\n");

    if let Some(summary) = content.get("architecture_summary").and_then(Value::as_str) {
        md.push_str(&format!("## 架构概述\n\n{}\n\n", summary));
    }

    if let Some(ts) = content.get("tech_stack") {
        md.push_str("## 技术栈\n\n");
        if let Some(lang) = ts.get("language").and_then(Value::as_str) {
            md.push_str(&format!("- 语言: {}\n", lang));
        }
        if let Some(fw) = ts.get("framework").and_then(Value::as_str) {
            if !fw.is_empty() { md.push_str(&format!("- 框架: {}\n", fw)); }
        }
        if let Some(bt) = ts.get("build_tool").and_then(Value::as_str) {
            if !bt.is_empty() { md.push_str(&format!("- 构建工具: {}\n", bt)); }
        }
        if let Some(pm) = ts.get("package_manager").and_then(Value::as_str) {
            if !pm.is_empty() { md.push_str(&format!("- 包管理器: {}\n", pm)); }
        }
        if let Some(rt) = ts.get("runtime").and_then(Value::as_str) {
            if !rt.is_empty() { md.push_str(&format!("- 运行时: {}\n", rt)); }
        }
        md.push('\n');
    }

    if let Some(modules) = content.get("modules").and_then(Value::as_array) {
        md.push_str("## 模块设计\n\n");
        for m in modules {
            let name = m.get("name").and_then(Value::as_str).unwrap_or("-");
            let resp = m.get("responsibility").and_then(Value::as_str).unwrap_or("");
            md.push_str(&format!("### {}\n\n{}\n\n", name, resp));
            if let Some(files) = m.get("files").and_then(Value::as_array) {
                md.push_str("文件:\n");
                for f in files.iter().filter_map(Value::as_str) {
                    md.push_str(&format!("- `{}`\n", f));
                }
                md.push('\n');
            }
        }
    }

    if let Some(apis) = content.get("api_contracts").and_then(Value::as_array) {
        md.push_str("## 接口契约\n\n");
        md.push_str("| 方法 | 路径 | 描述 |\n");
        md.push_str("|---|---|---|\n");
        for api in apis {
            let method = api.get("method").and_then(Value::as_str).unwrap_or("GET");
            let path = api.get("path").and_then(Value::as_str).unwrap_or("-");
            let desc = api.get("description").and_then(Value::as_str).unwrap_or("");
            md.push_str(&format!("| {} | {} | {} |\n", method, path, desc));
        }
        md.push('\n');
    }

    if let Some(files) = content.get("scaffold_files").and_then(Value::as_array) {
        md.push_str("## 脚手架文件\n\n");
        for f in files {
            let path = f.get("path").and_then(Value::as_str).unwrap_or("-");
            let purpose = f.get("purpose").and_then(Value::as_str).unwrap_or("");
            let lang = f.get("language").and_then(Value::as_str).unwrap_or("");
            md.push_str(&format!("### `{}`\n\n", path));
            if !purpose.is_empty() {
                md.push_str(&format!("用途: {}\n\n", purpose));
            }
            if let Some(content) = f.get("content").and_then(Value::as_str) {
                if !content.is_empty() {
                    md.push_str(&format!("```{}\n{}\n```\n\n", lang, content));
                }
            }
        }
    }

    md
}

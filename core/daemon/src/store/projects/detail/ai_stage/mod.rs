mod normalizer;

use super::super::super::helpers::now_ms;
use super::super::super::reports::llm::worker;
use super::super::super::{StageDefaults, Store, StoreResult};
use crate::logger;
use rusqlite::params;
use serde_json::Value;
use uuid::Uuid;

pub(super) fn generate_stage_ai_content(
    store: &Store,
    run_id: &str,
    project_id: &str,
    project_name: &str,
    stage: &str,
    defaults: &StageDefaults,
    feasibility: Option<&Value>,
    feedback: Option<&str>,
    action: Option<&str>,
) -> StoreResult<bool> {
    request_and_persist_stage_ai_content(
        store,
        run_id,
        project_id,
        project_name,
        stage,
        defaults,
        feasibility,
        feedback,
        action,
    )
}

pub(super) fn create_stage_ai_run(
    store: &Store,
    project_id: &str,
    stage: &str,
) -> StoreResult<String> {
    let run_id = Uuid::new_v4().to_string();
    upsert_ai_run(store, &run_id, project_id, stage, "dispatched", None)?;
    Ok(run_id)
}

fn request_and_persist_stage_ai_content(
    store: &Store,
    run_id: &str,
    project_id: &str,
    project_name: &str,
    stage: &str,
    _defaults: &StageDefaults,
    feasibility: Option<&Value>,
    _feedback: Option<&str>,
    action: Option<&str>,
) -> StoreResult<bool> {
    request_via_workflow(store, run_id, project_id, project_name, stage, feasibility, action)
}

fn request_via_workflow(
    store: &Store,
    run_id: &str,
    project_id: &str,
    project_name: &str,
    stage: &str,
    feasibility: Option<&Value>,
    action: Option<&str>,
) -> StoreResult<bool> {
    insert_stage_event(
        store,
        project_id,
        stage,
        "系统：启动统一 Workflow",
        "已切换到 Python 统一 workflow，包含需求澄清、可行性报告、PRD、需求评审、研发计划、编码、代码评审与完成总结。",
    )?;
    upsert_ai_run(
        store,
        run_id,
        project_id,
        stage,
        "waiting_first_delta",
        None,
    )?;

    let workflow_id = project_id;
    let status = worker::request_workflow_status(workflow_id).unwrap_or_else(|_| Value::Null);
    let not_started = status
        .get("status")
        .and_then(Value::as_str)
        .map(|status| status == "not_started")
        .unwrap_or_else(|| status.as_object().map(|obj| obj.is_empty()).unwrap_or(true));
    let workflow_status = if not_started {
        worker::request_workflow_start(project_id, project_name, feasibility, action)
    } else {
        worker::request_workflow_resume(workflow_id, action)
    };

    let workflow_status = match workflow_status {
        Ok(value) => value,
        Err(reason) => {
            if let Ok(partial_status) = worker::request_workflow_status(workflow_id) {
                let _ = update_project_from_workflow_status(store, project_id, &partial_status);
                let _ = persist_workflow_outputs(store, project_id, workflow_id, &partial_status);
            }
            upsert_ai_run(store, run_id, project_id, stage, "failed", Some(&reason))?;
            insert_stage_event(
                store,
                project_id,
                stage,
                "统一 Workflow 执行失败",
                &format!("AI Worker 请求失败：{}", reason),
            )?;
            logger::error_fields(
                "ai_worker workflow failed",
                &[
                    ("project_id", project_id.to_string()),
                    ("stage", stage.to_string()),
                    ("reason", reason),
                ],
            );
            return Ok(false);
        }
    };

    update_project_from_workflow_status(store, project_id, &workflow_status)?;
    persist_workflow_outputs(store, project_id, workflow_id, &workflow_status)?;
    let workflow_run_status = workflow_status
        .get("status")
        .and_then(Value::as_str)
        .unwrap_or("running");
    match workflow_run_status {
        "completed" => {
            insert_stage_event(
                store,
                project_id,
                stage,
                "统一 Workflow 已完成",
                "需求澄清、可行性报告、PRD、需求评审、研发计划、编码、代码评审与完成总结已写入项目数据。",
            )?;
            upsert_ai_run(store, run_id, project_id, stage, "completed", None)?;
            Ok(true)
        }
        "awaiting_user_input" => {
            insert_stage_event(
                store,
                project_id,
                stage,
                "统一 Workflow 等待补充信息",
                "需求澄清阶段判断现有信息不足，补充信息后可继续执行。",
            )?;
            upsert_ai_run(store, run_id, project_id, stage, "awaiting_user_input", None)?;
            Ok(false)
        }
        "failed" | "blocked" => {
            let reason = workflow_status
                .get("error")
                .and_then(Value::as_str)
                .unwrap_or("Workflow 未完成");
            insert_stage_event(store, project_id, stage, "统一 Workflow 未完成", reason)?;
            upsert_ai_run(store, run_id, project_id, stage, workflow_run_status, Some(reason))?;
            Ok(false)
        }
        _ => {
            insert_stage_event(
                store,
                project_id,
                stage,
                "统一 Workflow 已更新状态",
                "Workflow 已返回最新状态，后续可继续刷新查看进度。",
            )?;
            upsert_ai_run(store, run_id, project_id, stage, workflow_run_status, None)?;
            Ok(false)
        }
    }
}

fn update_project_from_workflow_status(
    store: &Store,
    project_id: &str,
    workflow_status: &Value,
) -> StoreResult<()> {
    let current_step = workflow_status
        .get("current_step")
        .and_then(Value::as_str)
        .unwrap_or("development");
    let current_phase = workflow_status
        .get("current_phase")
        .and_then(Value::as_str)
        .unwrap_or(current_step);
    let workflow_run_status = workflow_status
        .get("status")
        .and_then(Value::as_str)
        .unwrap_or("running");
    let lifecycle_stage = match current_step {
        "chat" | "report" => "feasibility",
        "prd" | "prd_review" => "prd",
        _ => "development",
    };
    let project_status = match workflow_run_status {
        "completed" => "completed",
        "failed" => "failed",
        "blocked" => "blocked",
        "awaiting_user_input" => "awaiting_confirmation",
        _ => "running",
    };
    let progress = match current_step {
        "chat" => 0.08,
        "report" => 0.16,
        "prd" => 0.28,
        "prd_review" => 0.36,
        "development" => 0.52,
        "coding" => 0.72,
        "code_review" => 0.88,
        "summary" => 1.0,
        _ => 0.2,
    };
    store
        .conn
        .execute(
            r#"
UPDATE projects
SET lifecycle_stage = ?2,
    current_phase = ?3,
    status = ?4,
    progress = CASE WHEN progress > ?5 THEN progress ELSE ?5 END,
    next_action = ?6,
    updated_at_ms = ?7
WHERE id = ?1
"#,
            params![
                project_id,
                lifecycle_stage,
                current_phase,
                project_status,
                progress,
                workflow_next_action(workflow_run_status, current_step),
                now_ms()
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

fn workflow_next_action(status: &str, current_step: &str) -> String {
    match status {
        "completed" => "查看完成总结".to_string(),
        "failed" => format!("重试 workflow 当前步骤：{}", current_step),
        "blocked" => "查看阻塞原因并处理".to_string(),
        "awaiting_user_input" => "补充需求信息后重试".to_string(),
        _ => format!("等待 workflow 执行：{}", current_step),
    }
}

fn persist_workflow_outputs(
    store: &Store,
    project_id: &str,
    workflow_id: &str,
    workflow_status: &Value,
) -> StoreResult<()> {
    let artifacts = workflow_status
        .get("artifacts")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    for artifact_meta in artifacts {
        let artifact_id = match artifact_meta.get("artifact_id").and_then(Value::as_str) {
            Some(id) if !id.trim().is_empty() => id,
            _ => continue,
        };
        let artifact = worker::request_workflow_artifact(workflow_id, artifact_id)?;
        persist_workflow_artifact(store, project_id, &artifact)?;
    }
    Ok(())
}

fn persist_workflow_artifact(
    store: &Store,
    project_id: &str,
    artifact: &Value,
) -> StoreResult<()> {
    let stage = artifact.get("stage").and_then(Value::as_str).unwrap_or("");
    let name = artifact
        .get("name")
        .and_then(Value::as_str)
        .unwrap_or("Workflow 产物");
    let kind = artifact
        .get("kind")
        .and_then(Value::as_str)
        .unwrap_or("workflow-artifact");
    let content = artifact.get("content").unwrap_or(&Value::Null);
    match stage {
        "chat" => normalizer::persist_generic_workflow_artifact(
            store,
            project_id,
            "feasibility:clarification",
            name,
            kind,
            content,
        ),
        "report" => normalizer::persist_generic_workflow_artifact(
            store,
            project_id,
            "feasibility:report",
            name,
            kind,
            content,
        ),
        "prd" => normalizer::persist_prd_content(store, project_id, content),
        "prd_review" => {
            normalizer::persist_workflow_review(store, project_id, "prd:prd_review", name, content)
        }
        "development" => normalizer::persist_development_task_breakdown(store, project_id, content),
        "coding" => normalizer::persist_development_coding(store, project_id, content),
        "code_review" => normalizer::persist_workflow_review(
            store,
            project_id,
            "development:code_review",
            name,
            content,
        ),
        "summary" => normalizer::persist_workflow_summary(store, project_id, content),
        _ => Ok(()),
    }
}

fn insert_stage_event(
    store: &Store,
    project_id: &str,
    stage: &str,
    title: &str,
    detail: &str,
) -> StoreResult<()> {
    store
        .conn
        .execute(
            "INSERT INTO stage_events (id, project_id, stage, title, detail, created_at_ms) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                Uuid::new_v4().to_string(),
                project_id,
                stage,
                title,
                detail,
                now_ms()
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

fn upsert_ai_run(
    store: &Store,
    id: &str,
    project_id: &str,
    stage: &str,
    status: &str,
    error_message: Option<&str>,
) -> StoreResult<()> {
    let now = now_ms();
    store
        .conn
        .execute(
            r#"
INSERT INTO stage_ai_runs (
  id, project_id, stage, status, started_at_ms, updated_at_ms, error_message
) VALUES (?1, ?2, ?3, ?4, ?5, ?5, ?6)
ON CONFLICT(id) DO UPDATE SET
  status = excluded.status,
  updated_at_ms = excluded.updated_at_ms,
  error_message = excluded.error_message
"#,
            params![id, project_id, stage, status, now, error_message],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

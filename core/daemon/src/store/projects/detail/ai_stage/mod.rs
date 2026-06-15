mod normalizer;

use super::super::super::helpers::{now_ms, stage_label};
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
    defaults: &StageDefaults,
    feasibility: Option<&Value>,
    _feedback: Option<&str>,
) -> StoreResult<bool> {
    if matches!(stage, "prd" | "development") {
        return request_via_workflow(store, run_id, project_id, project_name, stage, feasibility);
    }

    logger::info("stage_ai: routing through AI Worker (LangGraph)");
    request_via_worker(
        store,
        run_id,
        project_id,
        project_name,
        stage,
        defaults,
        feasibility,
    )
}

fn request_via_workflow(
    store: &Store,
    run_id: &str,
    project_id: &str,
    project_name: &str,
    stage: &str,
    feasibility: Option<&Value>,
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
    let workflow_state = if status.as_object().map(|obj| obj.is_empty()).unwrap_or(true) {
        worker::request_workflow_start(project_id, project_name, feasibility)
    } else {
        worker::request_workflow_resume(workflow_id)
    };

    let workflow_state = match workflow_state {
        Ok(value) => value,
        Err(reason) => {
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

    persist_workflow_outputs(store, project_id, &workflow_state)?;
    insert_stage_event(
        store,
        project_id,
        stage,
        "统一 Workflow 已写入结果",
        "PRD、需求评审、研发计划、编码结果、代码评审与完成总结已写入项目阶段数据。",
    )?;
    upsert_ai_run(store, run_id, project_id, stage, "completed", None)?;
    Ok(true)
}

fn persist_workflow_outputs(
    store: &Store,
    project_id: &str,
    workflow_state: &Value,
) -> StoreResult<()> {
    if let Some(prd) = workflow_state.get("prd_result") {
        normalizer::persist_prd_content(store, project_id, prd)?;
    }
    if let Some(review) = workflow_state.get("prd_review_result") {
        normalizer::persist_workflow_review(
            store,
            project_id,
            "prd:prd_review",
            "需求评审",
            review,
        )?;
    }
    if let Some(plan) = workflow_state.get("development_plan") {
        normalizer::persist_development_task_breakdown(store, project_id, plan)?;
    }
    if let Some(coding) = workflow_state.get("coding_result") {
        normalizer::persist_development_coding(store, project_id, coding)?;
    }
    if let Some(review) = workflow_state.get("code_review_result") {
        normalizer::persist_workflow_review(
            store,
            project_id,
            "development:code_review",
            "代码评审",
            review,
        )?;
    }
    if let Some(summary) = workflow_state.get("workflow_summary") {
        normalizer::persist_workflow_summary(store, project_id, summary)?;
    }
    Ok(())
}

/// Route stage generation through the Python AI worker (LangGraph).
fn request_via_worker(
    store: &Store,
    run_id: &str,
    project_id: &str,
    project_name: &str,
    stage: &str,
    defaults: &StageDefaults,
    feasibility: Option<&Value>,
) -> StoreResult<bool> {
    insert_stage_event(
        store,
        project_id,
        stage,
        "系统：创建阶段 Agent (LangGraph)",
        &format!("已为 {} 阶段创建 LangGraph Agent。", stage_label(stage)),
    )?;

    upsert_ai_run(
        store,
        run_id,
        project_id,
        stage,
        "waiting_first_delta",
        None,
    )?;

    let reply_event_id = Uuid::new_v4().to_string();
    insert_stage_event_with_id(
        store,
        &reply_event_id,
        project_id,
        stage,
        "Agent：阶段回复",
        "",
    )?;

    let mut streamed_reply = String::new();
    let mut delta_count: i64 = 0;

    let stage_content = match worker::request_stage_generation(
        project_id,
        project_name,
        stage,
        defaults,
        feasibility,
        |delta| {
            streamed_reply.push_str(delta);
            delta_count += 1;
            update_stage_event_detail(store, &reply_event_id, &streamed_reply)?;
            mark_ai_run_streaming(store, run_id, delta_count)
        },
    ) {
        Ok(result) => result,
        Err(reason) => {
            upsert_ai_run(store, run_id, project_id, stage, "failed", Some(&reason))?;
            insert_stage_event(
                store,
                project_id,
                stage,
                "后台 AI 生成失败",
                &format!("AI Worker 请求失败：{}", reason),
            )?;
            logger::error_fields(
                "ai_worker stage generation failed",
                &[
                    ("project_id", project_id.to_string()),
                    ("stage", stage.to_string()),
                    ("reason", reason),
                ],
            );
            return Ok(false);
        }
    };

    // Worker already returns normalized structured JSON — persist directly.
    // UI also needs sub-step stage rows so page_map / interaction can render independently.
    normalizer::persist_stage_content(store, project_id, stage, defaults, &stage_content)?;
    if stage == "ui" {
        normalizer::persist_ui_sub_steps(store, project_id, &stage_content, defaults)?;
        insert_stage_event(
            store,
            project_id,
            "ui:page_map",
            "AI：页面地图已生成",
            "页面结构与页面地图内容已拆分并写入，可继续查看交互稿。",
        )?;
        insert_stage_event(
            store,
            project_id,
            "ui:interaction",
            "AI：交互稿已生成",
            "核心交互流、关键组件与交互稿文档已拆分并写入。",
        )?;
    }
    insert_stage_event(
        store,
        project_id,
        stage,
        "后台 AI 已写入阶段结果",
        "阶段目标、执行步骤、风险与工作单元已由 LangGraph Agent 返回并写入。",
    )?;
    upsert_ai_run(store, run_id, project_id, stage, "completed", None)?;
    Ok(true)
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

fn insert_stage_event_with_id(
    store: &Store,
    id: &str,
    project_id: &str,
    stage: &str,
    title: &str,
    detail: &str,
) -> StoreResult<()> {
    store
        .conn
        .execute(
            "INSERT INTO stage_events (id, project_id, stage, title, detail, created_at_ms) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![id, project_id, stage, title, detail, now_ms()],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

fn update_stage_event_detail(store: &Store, id: &str, detail: &str) -> StoreResult<()> {
    store
        .conn
        .execute(
            "UPDATE stage_events SET detail = ?2 WHERE id = ?1",
            params![id, detail],
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

fn mark_ai_run_streaming(store: &Store, id: &str, delta_count: i64) -> StoreResult<()> {
    let now = now_ms();
    store
        .conn
        .execute(
            r#"
UPDATE stage_ai_runs
SET status = 'streaming',
    updated_at_ms = ?2,
    first_delta_at_ms = COALESCE(first_delta_at_ms, ?2),
    last_delta_at_ms = ?2,
    delta_count = ?3,
    error_message = NULL
WHERE id = ?1
"#,
            params![id, now, delta_count],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

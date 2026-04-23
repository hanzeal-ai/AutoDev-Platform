mod normalizer;
mod prompt;

use super::super::super::helpers::now_ms;
use super::super::super::reports::llm::{request_chat_message_streaming, request_json_object};
use super::super::super::{StageDefaults, Store, StoreResult};
use crate::logger;
use crate::runtime::DeepSeekConfig;
use prompt::{
    stage_agent_instruction, stage_agent_system_prompt, stage_prompt_label,
    system_prompt, user_prompt,
};
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
) -> StoreResult<bool> {
    request_and_persist_stage_ai_content(
        store,
        run_id,
        project_id,
        project_name,
        stage,
        defaults,
        feasibility,
    )
}

pub(super) fn create_stage_ai_run(store: &Store, project_id: &str, stage: &str) -> StoreResult<String> {
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
) -> StoreResult<bool> {
    let config = match DeepSeekConfig::from_env() {
        Ok(config) => config,
        Err(reason) => {
            upsert_ai_run(store, run_id, project_id, stage, "failed", Some(&reason))?;
            insert_stage_event(
                store,
                project_id,
                stage,
                "后台 AI 生成失败",
                &format!("模型配置不可用：{}", reason),
            )?;
            logger::error_fields(
                "stage detail model unavailable",
                &[
                    ("project_id", project_id.to_string()),
                    ("stage", stage.to_string()),
                    ("reason", reason),
                ],
            );
            return Ok(false);
        }
    };

    insert_stage_event(
        store,
        project_id,
        stage,
        "系统：创建阶段 Agent",
        &format!(
            "已为 {} 阶段创建后台 Agent，模型：{}。",
            stage_prompt_label(stage),
            config.model()
        ),
    )?;

    let agent_instruction = stage_agent_instruction(project_name, stage, defaults, feasibility);
    insert_stage_event(
        store,
        project_id,
        stage,
        "系统：发送任务指令",
        &agent_instruction,
    )?;

    insert_stage_event(
        store,
        project_id,
        stage,
        "后台 AI 正在等待 Agent 回复",
        "任务指令已发送，正在等待后台 Agent 返回可见消息。",
    )?;
    upsert_ai_run(store, run_id, project_id, stage, "waiting_first_delta", None)?;

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
    let agent_reply = match request_chat_message_streaming(
        &config,
        stage_agent_system_prompt(stage),
        &agent_instruction,
        0.2,
        1800,
        |delta| {
            streamed_reply.push_str(delta);
            delta_count += 1;
            update_stage_event_detail(store, &reply_event_id, &streamed_reply)?;
            mark_ai_run_streaming(store, run_id, delta_count)
        },
    ) {
        Ok(reply) => reply,
        Err(reason) => {
            upsert_ai_run(store, run_id, project_id, stage, "failed", Some(&reason))?;
            insert_stage_event(
                store,
                project_id,
                stage,
                "后台 AI 生成失败",
                &format!("Agent 请求失败：{}", reason),
            )?;
            logger::error_fields(
                "stage agent request failed",
                &[
                    ("project_id", project_id.to_string()),
                    ("stage", stage.to_string()),
                    ("reason", reason),
                ],
            );
            return Ok(false);
        }
    };

    upsert_ai_run(store, run_id, project_id, stage, "post_processing", None)?;
    let candidate = match request_json_object(
        &config,
        system_prompt(),
        &user_prompt(project_name, stage, defaults, feasibility, &agent_reply),
        0.2,
        1200,
    ) {
        Ok(value) => value,
        Err(reason) => {
            upsert_ai_run(store, run_id, project_id, stage, "failed", Some(&reason))?;
            insert_stage_event(
                store,
                project_id,
                stage,
                "后台 AI 生成失败",
                &format!("模型请求失败：{}", reason),
            )?;
            logger::error_fields(
                "stage detail model request failed",
                &[
                    ("project_id", project_id.to_string()),
                    ("stage", stage.to_string()),
                    ("reason", reason),
                ],
            );
            return Ok(false);
        }
    };

    let stage_content = normalizer::normalize_stage_content(candidate, stage, defaults, &config);
    normalizer::persist_stage_content(store, project_id, stage, defaults, &stage_content)?;
    insert_stage_event(
        store,
        project_id,
        stage,
        "后台 AI 已写入阶段结果",
        "阶段目标、执行步骤、风险与工作单元已由真实 AI 返回并写入。",
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

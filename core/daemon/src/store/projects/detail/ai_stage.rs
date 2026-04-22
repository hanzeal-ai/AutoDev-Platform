use super::super::super::helpers::{now_ms, to_json_string};
use super::super::super::reports::llm::{
    request_chat_message_streaming, request_json_object, truncate_text,
};
use super::super::super::{StageDefaults, Store, StoreResult};
use crate::logger;
use crate::runtime::DeepSeekConfig;
use rusqlite::params;
use serde_json::{json, Value};
use uuid::Uuid;

const MAX_INPUT_CONTEXTS: usize = 8;
const MAX_RISK_ITEMS: usize = 6;
const MAX_EVENT_FLOW: usize = 6;
const MAX_SECONDARY_ACTIONS: usize = 4;
const MAX_WORK_UNITS: usize = 6;

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
            stage_label(stage),
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

    let stage_content = normalize_stage_content(candidate, stage, defaults, &config);
    persist_stage_content(store, project_id, stage, defaults, &stage_content)?;
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

fn stage_agent_system_prompt(stage: &str) -> &'static str {
    match stage {
        "prd" => "你是 AI AutoDev 的 PRD 阶段后台 Agent。你收到任务后，需要直接用中文回复用户可见的工作过程和产出，不要输出 JSON。",
        "ui" => "你是 AI AutoDev 的 UI 阶段后台 Agent。你收到任务后，需要直接用中文回复用户可见的工作过程和产出，不要输出 JSON。",
        "development" => "你是 AI AutoDev 的研发阶段后台 Agent。你收到任务后，需要直接用中文回复用户可见的工作过程和产出，不要输出 JSON。",
        "testing" => "你是 AI AutoDev 的测试阶段后台 Agent。你收到任务后，需要直接用中文回复用户可见的工作过程和产出，不要输出 JSON。",
        "release" => "你是 AI AutoDev 的发布阶段后台 Agent。你收到任务后，需要直接用中文回复用户可见的工作过程和产出，不要输出 JSON。",
        "maintenance" => "你是 AI AutoDev 的维护阶段后台 Agent。你收到任务后，需要直接用中文回复用户可见的工作过程和产出，不要输出 JSON。",
        _ => "你是 AI AutoDev 后台阶段 Agent。你收到任务后，需要直接用中文回复用户可见的工作过程和产出，不要输出 JSON。",
    }
}

fn system_prompt() -> &'static str {
    "你是 AI AutoDev 后台阶段编排器。仅输出一个 JSON 对象，不要解释、不要 markdown、不要代码块。\
字段必须完整：objective(string)、input_contexts(string[])、step_progress(array)、risk_items(string[])、\
event_flow(string[])、primary_action(string)、secondary_actions(string[])、work_units(array)。\
step_progress 每项包含 title(string)、status(string)。work_units 每项包含 id(string)、title(string)、\
agent_role(string)、status(string)、progress(number 0..1)、depends_on(string[])、current_output(string|null)、next_step(string)。\
status 只允许 queued、running、completed、awaiting_confirmation、blocked、failed。\
必须按实际工作规则拆分 Agent：默认当前 Agent 直接完成；只有独立、可并行、边界清晰且更省上下文时才拆；\
同一阶段最多 1 个实现 Agent + 1 个验证 Agent，不允许重复功能 Agent。"
}

fn user_prompt(
    project_name: &str,
    stage: &str,
    defaults: &StageDefaults,
    feasibility: Option<&Value>,
    agent_reply: &str,
) -> String {
    let feasibility_text = feasibility
        .map(|value| serde_json::to_string(value).unwrap_or_else(|_| "{}".to_string()))
        .unwrap_or_else(|| "{}".to_string());

    format!(
        "请为阶段详情生成真实 AI 执行方案。\n\n\
项目：{}\n\
阶段：{} ({})\n\n\
当前默认模板(JSON)：\n{}\n\n\
立项上下文(JSON，可为空)：\n{}\n\n\
阶段 Agent 原始回复：\n{}\n\n\
要求：\n\
1) 抽象 AI 完成任务过程的共性：目标收口、证据收集、约束核验、最小执行、最小验证、结果归档。\n\
2) 让内容贴合当前阶段，不要照抄默认模板。\n\
3) work_units 体现后台真实 AI 编排和必要 Agent 边界；不要虚构超过规则的 Agent。\n\
4) 结构化字段必须从 Agent 原始回复归纳，不要编造 Agent 没提到的结论。\n\
5) 中文简洁，列表每项可执行。",
        project_name,
        stage,
        stage_label(stage),
        defaults_json(defaults),
        truncate_text(&feasibility_text, 1800),
        truncate_text(agent_reply, 2400)
    )
}

fn stage_agent_instruction(
    project_name: &str,
    stage: &str,
    defaults: &StageDefaults,
    feasibility: Option<&Value>,
) -> String {
    let feasibility_text = feasibility
        .map(|value| serde_json::to_string(value).unwrap_or_else(|_| "{}".to_string()))
        .unwrap_or_else(|| "{}".to_string());

    format!(
        "你是 {} 阶段后台 Agent。\n\n\
项目：{}\n\
阶段：{} ({})\n\n\
你需要完成：{}\n\n\
上游上下文：\n{}\n\n\
工作规则：\n\
1. 先确认任务边界和可用证据。\n\
2. 说明你将如何完成当前阶段，不要写空泛口号。\n\
3. 输出当前阶段的核心结果、风险和下一步。\n\
4. 按实际规则拆分 Agent：默认自己完成；只有独立、可并行、边界清晰且更省上下文时才拆；同一阶段最多 1 个实现 Agent + 1 个验证 Agent。\n\
5. 直接返回给 App 展示的中文消息，不要 JSON，不要 markdown 代码块。",
        stage_label(stage),
        project_name,
        stage,
        stage_label(stage),
        defaults.objective,
        truncate_text(&feasibility_text, 2200)
    )
}

fn defaults_json(defaults: &StageDefaults) -> String {
    serde_json::to_string(&json!({
        "objective": defaults.objective,
        "input_contexts": defaults.input_contexts,
        "step_progress": defaults.step_progress,
        "risk_items": defaults.risk_items,
        "event_flow": defaults.event_flow,
        "primary_action": defaults.primary_action,
        "secondary_actions": defaults.secondary_actions,
        "work_units": defaults.work_units.iter().map(|unit| {
            json!({
                "id": unit.id,
                "title": unit.title,
                "agent_role": unit.agent_role,
                "status": unit.status,
                "progress": unit.progress,
                "depends_on": unit.depends_on,
                "current_output": unit.current_output,
                "next_step": unit.next_step
            })
        }).collect::<Vec<Value>>()
    }))
    .unwrap_or_else(|_| "{}".to_string())
}

fn normalize_stage_content(
    candidate: Value,
    stage: &str,
    defaults: &StageDefaults,
    config: &DeepSeekConfig,
) -> Value {
    let objective = text_field(&candidate, "objective", "");
    let input_contexts = capped_string_list(
        candidate.get("input_contexts"),
        &[],
        MAX_INPUT_CONTEXTS,
    );
    let mut input_contexts = input_contexts;
    input_contexts.insert(
        0,
        format!("真实 AI：{} / {}", config.model(), stage_label(stage)),
    );

    json!({
        "objective": objective,
        "input_contexts": input_contexts,
        "step_progress": normalize_step_progress(candidate.get("step_progress"), &json!([])),
        "risk_items": capped_string_list(candidate.get("risk_items"), &[], MAX_RISK_ITEMS),
        "event_flow": capped_string_list(candidate.get("event_flow"), &[], MAX_EVENT_FLOW),
        "primary_action": text_field(&candidate, "primary_action", ""),
        "secondary_actions": capped_string_list(candidate.get("secondary_actions"), &[], MAX_SECONDARY_ACTIONS),
        "work_units": normalize_work_units(candidate.get("work_units"), defaults)
    })
}

fn persist_stage_content(
    store: &Store,
    project_id: &str,
    stage: &str,
    defaults: &StageDefaults,
    content: &Value,
) -> StoreResult<()> {
    let now = now_ms();
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
                "[]",
                to_json_string(content.get("work_units").unwrap_or(&json!([]))),
                now,
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

fn text_field(candidate: &Value, key: &str, fallback: &str) -> String {
    candidate
        .get(key)
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .unwrap_or(fallback)
        .to_string()
}

fn capped_string_list(candidate: Option<&Value>, fallback: &[String], max: usize) -> Vec<String> {
    let mut out = match candidate {
        Some(Value::Array(items)) => items
            .iter()
            .filter_map(Value::as_str)
            .map(str::trim)
            .filter(|item| !item.is_empty())
            .map(ToString::to_string)
            .collect::<Vec<_>>(),
        Some(Value::String(value)) => vec![value.trim().to_string()],
        _ => fallback.to_vec(),
    };
    if out.is_empty() {
        out = fallback.to_vec();
    }
    out.truncate(max);
    out
}

fn normalize_step_progress(candidate: Option<&Value>, fallback: &Value) -> Value {
    let items = candidate
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(|item| {
                    let title = item.get("title").and_then(Value::as_str)?.trim();
                    if title.is_empty() {
                        return None;
                    }
                    Some(json!({
                        "title": title,
                        "status": normalize_status(item.get("status").and_then(Value::as_str), "queued")
                    }))
                })
                .collect::<Vec<Value>>()
        })
        .unwrap_or_default();

    if items.is_empty() {
        fallback.clone()
    } else {
        Value::Array(items)
    }
}

fn normalize_work_units(candidate: Option<&Value>, _defaults: &StageDefaults) -> Value {
    let mut units = candidate
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(normalize_work_unit)
                .collect::<Vec<Value>>()
        })
        .unwrap_or_default();

    units.truncate(MAX_WORK_UNITS);
    Value::Array(units)
}

fn normalize_work_unit(item: &Value) -> Option<Value> {
    let id = item.get("id").and_then(Value::as_str)?.trim();
    let title = item.get("title").and_then(Value::as_str)?.trim();
    let agent_role = item.get("agent_role").and_then(Value::as_str)?.trim();
    if id.is_empty() || title.is_empty() || agent_role.is_empty() {
        return None;
    }
    let progress = item
        .get("progress")
        .and_then(Value::as_f64)
        .unwrap_or(0.0)
        .clamp(0.0, 1.0);
    let depends_on = item
        .get("depends_on")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(Value::as_str)
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(ToString::to_string)
                .collect::<Vec<String>>()
        })
        .unwrap_or_default();

    Some(json!({
        "id": id,
        "title": title,
        "agent_role": agent_role,
        "status": normalize_status(item.get("status").and_then(Value::as_str), "queued"),
        "progress": progress,
        "depends_on": depends_on,
        "current_output": item.get("current_output").and_then(Value::as_str),
        "next_step": text_field(item, "next_step", "继续推进"),
        "downloads": []
    }))
}

fn normalize_status(candidate: Option<&str>, fallback: &str) -> String {
    match candidate.unwrap_or(fallback).trim() {
        "queued" | "running" | "completed" | "awaiting_confirmation" | "blocked" | "failed" => {
            candidate.unwrap_or(fallback).trim().to_string()
        }
        _ => fallback.to_string(),
    }
}

fn stage_label(stage: &str) -> &'static str {
    match stage {
        "feasibility" => "可行性",
        "prd" => "PRD",
        "ui" => "UI",
        "development" => "研发",
        "testing" => "测试",
        "release" => "发布",
        "maintenance" => "维护",
        _ => "阶段",
    }
}

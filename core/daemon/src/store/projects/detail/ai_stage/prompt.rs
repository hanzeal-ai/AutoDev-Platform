use super::super::super::super::reports::llm::truncate_text;
use super::super::super::super::StageDefaults;
use serde_json::{json, Value};

pub(super) fn stage_prompt_label(stage: &str) -> &'static str {
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

pub(super) fn stage_agent_system_prompt(stage: &str) -> &'static str {
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

pub(super) fn system_prompt() -> &'static str {
    "你是 AI AutoDev 后台阶段编排器。仅输出一个 JSON 对象，不要解释、不要 markdown、不要代码块。\
字段必须完整：objective(string)、input_contexts(string[])、step_progress(array)、risk_items(string[])、\
event_flow(string[])、primary_action(string)、secondary_actions(string[])、work_units(array)。\
step_progress 每项包含 title(string)、status(string)。work_units 每项包含 id(string)、title(string)、\
agent_role(string)、status(string)、progress(number 0..1)、depends_on(string[])、current_output(string|null)、next_step(string)。\
status 只允许 queued、running、completed、awaiting_confirmation、blocked、failed。\
必须按实际工作规则拆分 Agent：默认当前 Agent 直接完成；只有独立、可并行、边界清晰且更省上下文时才拆；\
同一阶段最多 1 个实现 Agent + 1 个验证 Agent，不允许重复功能 Agent。"
}

pub(super) fn user_prompt(
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
        stage_prompt_label(stage),
        defaults_json(defaults),
        truncate_text(&feasibility_text, 1800),
        truncate_text(agent_reply, 2400)
    )
}

pub(super) fn stage_agent_instruction(
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
        stage_prompt_label(stage),
        project_name,
        stage,
        stage_prompt_label(stage),
        defaults.objective,
        truncate_text(&feasibility_text, 2200)
    )
}

pub(super) fn defaults_json(defaults: &StageDefaults) -> String {
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

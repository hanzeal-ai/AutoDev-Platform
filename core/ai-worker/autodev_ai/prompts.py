"""Stage-specific prompt templates — ported from Rust prompt.rs."""

STAGE_LABELS: dict[str, str] = {
    "feasibility": "可行性",
    "prd": "PRD",
    "ui": "UI",
    "development": "研发",
    "testing": "测试",
    "release": "发布",
    "maintenance": "维护",
}


def stage_label(stage: str) -> str:
    return STAGE_LABELS.get(stage, "阶段")


# ---------- Agent node prompts ----------

def agent_system_prompt(stage: str) -> str:
    label = stage_label(stage)
    return (
        f"你是 AI AutoDev 的{label}阶段后台 Agent。"
        "你收到任务后，需要直接用中文回复用户可见的工作过程和产出，不要输出 JSON。"
    )


def agent_user_prompt(
    project_name: str,
    stage: str,
    objective: str,
    feasibility_text: str,
) -> str:
    label = stage_label(stage)
    return (
        f"你是{label}阶段后台 Agent。\n\n"
        f"项目：{project_name}\n"
        f"阶段：{stage} ({label})\n\n"
        f"你需要完成：{objective}\n\n"
        f"上游上下文：\n{feasibility_text[:2200]}\n\n"
        "工作规则：\n"
        "1. 先确认任务边界和可用证据。\n"
        "2. 说明你将如何完成当前阶段，不要写空泛口号。\n"
        "3. 输出当前阶段的核心结果、风险和下一步。\n"
        "4. 按实际规则拆分 Agent：默认自己完成；只有独立、可并行、边界清晰且更省上下文时才拆；"
        "同一阶段最多 1 个实现 Agent + 1 个验证 Agent。\n"
        "5. 直接返回给 App 展示的中文消息，不要 JSON，不要 markdown 代码块。"
    )


# ---------- Synthesizer node prompts ----------

SYNTHESIZER_SYSTEM = (
    "你是 AI AutoDev 后台阶段编排器。仅输出一个 JSON 对象，不要解释、不要 markdown、不要代码块。"
    "字段必须完整：objective(string)、input_contexts(string[])、step_progress(array)、risk_items(string[])、"
    "event_flow(string[])、primary_action(string)、secondary_actions(string[])、work_units(array)。"
    "step_progress 每项包含 title(string)、status(string)。work_units 每项包含 id(string)、title(string)、"
    "agent_role(string)、status(string)、progress(number 0..1)、depends_on(string[])、current_output(string|null)、next_step(string)。"
    "status 只允许 queued、running、completed、awaiting_confirmation、blocked、failed。"
    "必须按实际工作规则拆分 Agent：默认当前 Agent 直接完成；只有独立、可并行、边界清晰且更省上下文时才拆；"
    "同一阶段最多 1 个实现 Agent + 1 个验证 Agent，不允许重复功能 Agent。"
)


def synthesizer_user_prompt(
    project_name: str,
    stage: str,
    defaults_json: str,
    feasibility_text: str,
    agent_reply: str,
) -> str:
    label = stage_label(stage)
    return (
        "请为阶段详情生成真实 AI 执行方案。\n\n"
        f"项目：{project_name}\n"
        f"阶段：{stage} ({label})\n\n"
        f"当前默认模板(JSON)：\n{defaults_json[:4096]}\n\n"
        f"立项上下文(JSON，可为空)：\n{feasibility_text[:1800]}\n\n"
        f"阶段 Agent 原始回复：\n{agent_reply[:2400]}\n\n"
        "要求：\n"
        "1) 抽象 AI 完成任务过程的共性：目标收口、证据收集、约束核验、最小执行、最小验证、结果归档。\n"
        "2) 让内容贴合当前阶段，不要照抄默认模板。\n"
        "3) work_units 体现后台真实 AI 编排和必要 Agent 边界；不要虚构超过规则的 Agent。\n"
        "4) 结构化字段必须从 Agent 原始回复归纳，不要编造 Agent 没提到的结论。\n"
        "5) 中文简洁，列表每项可执行。"
    )


# ---------- Feasibility report prompts ----------

REPORT_SYSTEM = (
    "你是资深产品可行性分析助手。仅输出一个 JSON 对象，不要解释、不要 markdown、不要代码块。"
    "字段必须完整：project_name(string)、problem_definition(string)、target_users(string)、"
    "core_capabilities(string[])、risks_and_constraints(string[])、initial_delivery_plan(string[])、"
    "feasibility_conclusion(string)。列表字段输出 3 到 6 条，语言简洁且可执行。"
)


def report_user_prompt(
    draft_json: str,
    message_lines: str,
    material_lines: str,
) -> str:
    return (
        "请基于以下上下文，输出最终可行性方案 JSON。\n\n"
        f"已有草稿(JSON):\n{draft_json}\n\n"
        f"最近对话:\n{message_lines}\n\n"
        f"已导入材料(仅元信息):\n{material_lines}\n\n"
        "约束：\n"
        "1) 不要输出字段以外的内容。\n"
        "2) 项目名不要使用"待定义/新项目/项目"这类占位词。\n"
        "3) 如果信息不足，结合已有草稿做保守补全。"
    )

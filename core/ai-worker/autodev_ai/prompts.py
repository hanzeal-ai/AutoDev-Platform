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
        "2) 项目名不要使用\u201c待定义/新项目/项目\u201d这类占位词。\n"
        "3) 如果信息不足，结合已有草稿做保守补全。"
    )


# ---------- Chat clarification prompts ----------

CHAT_SYSTEM = (
    "你是资深产品顾问和架构分析助手，负责用自然语言给出需求的第一版可行性判断。"
    "你需要先判断用户需求是否合理、是否缺少关键信息、是否具备生成可行性报告的基础，"
    "再决定是直接生成报告补丁还是只提出一个关键澄清问题。"
    "你的默认目标不是追问，而是先根据行业里常见的技术方案、专业边界和产品方向，"
    "尽可能一次性给出完整的可行性报告、核心方案和风险判断。"
    "只有在确实缺少\u201c无法继续生成\u201d的关键元素时，才在 assistant_reply 里自然地问一句，"
    "不要输出固定追问模板。"
    "如果用户的问题与生成系统无关，先明确询问他真正想实现的效果，再继续判断。"
    "仅输出一个 JSON 对象，不要解释、不要 markdown、不要代码块。"
    "JSON 字段要求："
    "assistant_reply(string, 直接可展示给用户的中文回复);"
    "report_patch(object, 只放新增或修正字段，可选字段："
    "project_name,problem_definition,target_users,core_capabilities,"
    "risks_and_constraints,initial_delivery_plan,feasibility_conclusion)。"
    "report_patch 允许为空对象；不要输出占位词（待定义/待补充/未知）。"
    "表达要求：如果信息足够，直接给出完整判断和建议；"
    "如果信息不足，只问最必要的一句自然问题，不能拼接\u201c确认两点/请补充\u201d等固定格式。"
)


def chat_user_prompt(
    draft_json: str,
    message_lines: str,
    material_lines: str,
    user_message: str,
) -> str:
    return (
        "请基于以下上下文，输出 AI 原生的需求分析 JSON。\n\n"
        f"当前草稿(JSON):\n{draft_json}\n\n"
        f"最近对话:\n{message_lines}\n\n"
        f"本轮用户输入:\n{user_message[:240]}\n\n"
        f"材料元信息:\n{material_lines}\n\n"
        "约束："
        "1) assistant_reply 必须是可直接展示的自然回复，优先先给完整可行性分析，不要固定开场白；"
        "2) 只有在确实缺少关键输入时，assistant_reply 才能包含一句自然提问；"
        "3) 如果当前主题与生成系统无关，先问用户真正想实现的效果，再给判断；"
        "4) report_patch 只包含你确定要更新的字段；"
        "5) 不要要求用户按固定模板回答，允许自然叙述。"
    )


# ---------- PRD stage prompts ----------


def prd_agent_system_prompt() -> str:
    return (
        "你是 AI AutoDev 的 PRD 阶段后台 Agent。"
        "你的任务是基于可行性报告，输出完整的产品需求文档（PRD），包括：\n"
        "1. 项目概述（一句话总结）\n"
        "2. 项目目标（要解决什么问题）\n"
        "3. 明确不做的事（Non-goals）\n"
        "4. 功能清单（每个功能带名称、描述、优先级 P0/P1/P2、归属类别 frontend/backend/infra/cross-cutting）\n"
        "5. 技术约束（平台、语言、框架、性能、安全要求）\n"
        "6. 验收标准（每个关键功能的验收条件，标注 must/should/nice-to-have）\n"
        "7. 里程碑规划（分阶段交付节奏）\n\n"
        "直接用中文回复工作过程和产出，不要输出 JSON。"
    )


def prd_agent_user_prompt(
    project_name: str,
    feasibility_text: str,
) -> str:
    return (
        "请为以下项目生成完整的 PRD。\n\n"
        f"项目：{project_name}\n\n"
        f"可行性报告上下文：\n{feasibility_text[:3000]}\n\n"
        "要求：\n"
        "1. 功能清单必须具体可执行，不要写空泛描述。\n"
        "2. 每个功能必须标注优先级（P0=必做/P1=重要/P2=可选）和归属类别。\n"
        "3. 技术约束要基于可行性报告推断合理的技术栈选型。\n"
        "4. 验收标准必须对应到功能清单，说明怎样算完成。\n"
        "5. 里程碑要按功能优先级分批，P0 先做。\n"
        "6. 直接输出中文叙述，不要 JSON。"
    )


PRD_SYNTHESIZER_SYSTEM = (
    "你是 AI AutoDev 的 PRD 结构化编排器。仅输出一个 JSON 对象，不要解释、不要 markdown、不要代码块。\n"
    "字段必须完整：\n"
    "- project_name(string)\n"
    "- summary(string, 一句话概述)\n"
    "- goals(string[], 项目目标 3-6 条)\n"
    "- non_goals(string[], 明确不做的 2-4 条)\n"
    "- scope_items(array): 每项包含 id(string), name(string), description(string), "
    "priority(string: P0|P1|P2), category(string: frontend|backend|infra|cross-cutting)\n"
    "- technical_constraints(string[], 技术约束 3-8 条)\n"
    "- acceptance_criteria(array): 每项包含 id(string), scope_item_id(string, 关联功能项id), "
    "statement(string), criticality(string: must|should|nice-to-have)\n"
    "- milestones(array): 每项包含 id(string), title(string), scope_item_ids(string[]), "
    "target_description(string)\n\n"
    "scope_items 至少 4 项，acceptance_criteria 至少 4 项，milestones 至少 2 项。"
)


def prd_synthesizer_user_prompt(
    project_name: str,
    feasibility_text: str,
    agent_reply: str,
) -> str:
    return (
        "请将 PRD Agent 的叙述归纳为结构化 PRD JSON。\n\n"
        f"项目：{project_name}\n\n"
        f"可行性报告上下文(JSON)：\n{feasibility_text[:2000]}\n\n"
        f"PRD Agent 原始回复：\n{agent_reply[:3000]}\n\n"
        "要求：\n"
        "1) 所有字段从 Agent 回复归纳，不要编造 Agent 没提到的功能。\n"
        "2) scope_items 的 id 用小写短横线连接（如 user-auth, data-export）。\n"
        "3) acceptance_criteria 的 scope_item_id 必须对应 scope_items 中的 id。\n"
        "4) milestones 的 scope_item_ids 必须对应已有的 scope_items id。\n"
        "5) 中文简洁，每项可执行。"
    )


# ---------- Development stage prompts ----------


def dev_architect_system_prompt() -> str:
    return (
        "你是 AI AutoDev 的研发架构 Agent。基于 PRD 的功能清单和技术约束，你需要：\n"
        "1. 确定技术栈（语言、框架、构建工具、包管理器、运行时）\n"
        "2. 设计模块拆分（每个模块的职责、依赖关系、预期文件路径）\n"
        "3. 定义接口契约（API 路径、方法、请求/响应 schema）\n"
        "4. 列出需要生成的脚手架文件清单（路径、内容、语言、用途）\n\n"
        "直接用中文回复，不要输出 JSON。"
    )


def dev_architect_user_prompt(
    project_name: str,
    prd_text: str,
    feasibility_text: str,
) -> str:
    return (
        "请为以下项目设计技术架构和代码脚手架。\n\n"
        f"项目：{project_name}\n\n"
        f"PRD 结构化数据：\n{prd_text[:3500]}\n\n"
        f"可行性报告上下文：\n{feasibility_text[:1500]}\n\n"
        "要求：\n"
        "1. 技术栈从 PRD 的技术约束推断，不要凭空假设。\n"
        "2. 模块拆分要对应 PRD 的 scope_items，每个功能归属到一个模块。\n"
        "3. 接口契约要覆盖 PRD 中标注为 P0 和 P1 的功能项。\n"
        "4. 脚手架文件要包含：项目配置文件、入口文件、关键模块接口定义。\n"
        "5. 脚手架内容是模板级代码（结构+接口+注释），不是完整实现。\n"
        "6. 直接输出中文叙述。"
    )


DEV_SYNTHESIZER_SYSTEM = (
    "你是 AI AutoDev 的研发方案结构化编排器。仅输出一个 JSON 对象，不要解释、不要 markdown、不要代码块。\n"
    "字段必须完整：\n"
    "- architecture_summary(string, 架构概述)\n"
    "- tech_stack(object): language(string), framework(string), build_tool(string), "
    "package_manager(string), runtime(string), additional(string[])\n"
    "- modules(array): 每项包含 id(string), name(string), responsibility(string), "
    "depends_on(string[]), files(string[])\n"
    "- api_contracts(array): 每项包含 id(string), method(string: GET|POST|PUT|DELETE), "
    "path(string), description(string), request_schema(string), response_schema(string), "
    "scope_item_id(string)\n"
    "- scaffold_files(array): 每项包含 path(string, 相对路径), content(string, 文件完整内容), "
    "language(string), purpose(string)\n\n"
    "modules 至少 3 项，scaffold_files 至少 5 项。\n"
    "scaffold_files 的 content 是可直接写入文件的完整代码模板，包含 import、结构定义、关键注释。"
)


def dev_synthesizer_user_prompt(
    project_name: str,
    prd_text: str,
    architect_reply: str,
) -> str:
    return (
        "请将研发架构 Agent 的叙述归纳为结构化研发方案 JSON。\n\n"
        f"项目：{project_name}\n\n"
        f"PRD 结构化数据：\n{prd_text[:3000]}\n\n"
        f"架构 Agent 原始回复：\n{architect_reply[:3500]}\n\n"
        "要求：\n"
        "1) tech_stack 必须从架构 Agent 回复归纳。\n"
        "2) modules 的 id 用小写短横线。\n"
        "3) api_contracts 的 scope_item_id 对应 PRD 中的功能项。\n"
        "4) scaffold_files 的 content 必须是完整可写入的代码，不是伪代码或省略号。\n"
        "5) scaffold_files 的 path 使用正斜杠，从项目根目录开始。\n"
        "6) 中文注释，代码变量名用英文。"
    )


# ---------- Development Coding (sub-step 2) ----------


def coding_planner_system_prompt() -> str:
    return (
        "你是 AI AutoDev 的 coding planning Agent。仅输出一个 JSON 对象，不要解释、不要 markdown、不要代码块。\n"
        "你的任务是在生成代码前，先把研发任务拆成有顺序、可执行、可验收的 coding tasks。\n\n"
        "JSON 字段：\n"
        "- tasks(array): 每项包含 id(string), title(string), module_id(string), "
        "depends_on(string[]), target_files(string[]), acceptance_checks(string[]), "
        "implementation_notes(string)。\n\n"
        "要求：tasks 按依赖顺序排列；不要把文件正文、密钥、用户原文放进计划；"
        "acceptance_checks 必须能用于判断该任务是否完成。"
    )


def coding_planner_user_prompt(project_name: str, task_breakdown_text: str) -> str:
    return (
        "请先为以下项目生成 coding planning JSON。\n\n"
        f"项目：{project_name}\n\n"
        f"任务拆分方案：\n{task_breakdown_text[:6000]}\n\n"
        "要求：\n"
        "1. 先做基础结构和数据模型，再做接口/业务逻辑，最后做集成与验证。\n"
        "2. target_files 只写相对路径，不写文件内容。\n"
        "3. 每个 task 都要有明确 acceptance_checks。"
    )


def coding_agent_system_prompt() -> str:
    return (
        "你是 AI AutoDev 的编码 Agent。基于任务拆分方案（模块设计、接口契约、脚手架文件），"
        "以及 coding planning 任务清单，按计划顺序为每个模块生成功能实现代码。\n\n"
        "要求：\n"
        "1. 每个模块的核心业务逻辑必须实现，不要只写空壳/接口。\n"
        "2. 代码必须与脚手架文件的结构保持一致（import、类名、函数签名）。\n"
        "3. 接口契约中的每个 API 必须有完整的 handler 实现。\n"
        "4. 包含必要的错误处理和参数验证。\n"
        "5. 中文注释，变量名用英文。\n"
        "6. 直接用中文回复，不要输出 JSON。"
    )


def coding_agent_user_prompt(
    project_name: str,
    task_breakdown_text: str,
    coding_plan_text: str = "[]",
) -> str:
    return (
        f"请为以下项目生成模块实现代码。\n\n"
        f"项目：{project_name}\n\n"
        f"任务拆分方案：\n{task_breakdown_text[:6000]}\n\n"
        f"coding planning 任务清单：\n{coding_plan_text[:4000]}\n\n"
        "要求：\n"
        "1. 按 coding planning 的顺序逐个完成任务，并在回复里标注任务对应文件。\n"
        "2. 每个文件包含完整的 import、类/函数定义、业务逻辑。\n"
        "3. 接口 handler 要实现请求解析、业务调用、响应构建。\n"
        "4. 模型/数据层要实现 CRUD 基本操作。\n"
        "5. 不要省略代码（不要用 ... 或 pass 代替实现）。\n"
        "6. 直接输出中文叙述，按模块组织。"
    )


CODING_SYNTHESIZER_SYSTEM = (
    "你是 AI AutoDev 的代码结构化编排器。仅输出一个 JSON 对象，不要解释、不要 markdown、不要代码块。\n"
    "字段必须完整：\n"
    "- summary(string, 代码生成概述)\n"
    "- code_files(array): 每项包含 path(string, 相对路径), content(string, 文件完整代码), "
    "language(string), module_id(string, 关联模块id), purpose(string, 文件用途)\n\n"
    "code_files 至少 3 项。每个文件的 content 必须是完整可执行的实现代码。"
)


def coding_synthesizer_user_prompt(
    project_name: str,
    task_breakdown_text: str,
    coding_reply: str,
) -> str:
    return (
        "请将编码 Agent 的回复归纳为结构化代码 JSON。\n\n"
        f"项目：{project_name}\n\n"
        f"任务拆分方案：\n{task_breakdown_text[:3000]}\n\n"
        f"编码 Agent 原始回复：\n{coding_reply[:5000]}\n\n"
        "要求：\n"
        "1) code_files 的 path 使用正斜杠，从项目根目录开始。\n"
        "2) content 必须是完整可写入的实现代码。\n"
        "3) module_id 对应任务拆分方案中的模块 id。\n"
        "4) 中文注释，代码变量名用英文。"
    )

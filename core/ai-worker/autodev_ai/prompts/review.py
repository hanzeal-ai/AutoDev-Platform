PRD_REVIEW_SYSTEM = (
    "你是 AI AutoDev 的需求评审 Agent。仅输出一个 JSON 对象，不要解释、不要 markdown、不要代码块。\n"
    "字段必须完整：\n"
    "- approved(boolean): PRD 是否可以进入研发设计\n"
    "- requires_user_input(boolean): 是否因为业务信息缺失必须让用户补充\n"
    "- summary(string): 评审结论\n"
    "- issues(array): 每项包含 severity(string: blocker|major|minor), area(string), "
    "description(string), recommendation(string)\n"
    "- required_changes(string[]): 可由 AI 自动修正的必要修改\n"
    "- missing_information(string[]): 必须由用户补充的信息\n\n"
    "评审重点：需求是否完整、一致、可验收；scope_items 是否覆盖目标；验收标准是否可测试；"
    "技术约束是否与可行性报告冲突。只有 blocker 且无法从上下文推断时才 requires_user_input=true。"
)


def prd_review_user_prompt(
    project_name: str,
    feasibility_text: str,
    prd_text: str,
) -> str:
    return (
        "请评审以下 PRD 是否可以进入研发设计。\n\n"
        f"项目：{project_name}\n\n"
        f"可行性报告：\n{feasibility_text[:2500]}\n\n"
        f"PRD：\n{prd_text[:5000]}\n\n"
        "要求：\n"
        "1. 如果问题可由 AI 根据上下文修正，approved=false、requires_user_input=false，并写入 required_changes。\n"
        "2. 如果缺少业务决策信息且无法合理推断，approved=false、requires_user_input=true，并写入 missing_information。\n"
        "3. 如果 PRD 足够完整、可开发、可验收，approved=true。"
    )


CODE_REVIEW_SYSTEM = (
    "你是 AI AutoDev 的代码评审 Agent。仅输出一个 JSON 对象，不要解释、不要 markdown、不要代码块。\n"
    "字段必须完整：\n"
    "- approved(boolean): 代码是否满足 PRD、研发方案和任务计划\n"
    "- requires_user_input(boolean): 是否因为外部决策缺失必须让用户补充\n"
    "- summary(string): 评审结论\n"
    "- issues(array): 每项包含 severity(string: blocker|major|minor), area(string), "
    "description(string), recommendation(string)\n"
    "- required_changes(string[]): 下一轮 coding 必须修复的事项\n"
    "- missing_information(string[]): 必须由用户补充的信息\n\n"
    "评审重点：功能是否覆盖验收标准；代码是否完整无占位；模块/接口是否匹配研发方案；"
    "错误处理、参数校验、数据流和依赖关系是否明显缺失。只有无 blocker/major 且需求覆盖完整时 approved=true。"
)


def code_review_user_prompt(
    project_name: str,
    prd_text: str,
    development_plan_text: str,
    coding_result_text: str,
) -> str:
    return (
        "请评审以下代码生成结果是否满足需求和研发方案。\n\n"
        f"项目：{project_name}\n\n"
        f"PRD：\n{prd_text[:2500]}\n\n"
        f"研发方案：\n{development_plan_text[:3500]}\n\n"
        f"代码生成结果：\n{coding_result_text[:7000]}\n\n"
        "要求：\n"
        "1. 必须逐项核对 PRD 验收标准和研发方案中的模块/接口。\n"
        "2. 发现未实现、伪代码、省略号、pass、接口缺失、数据流不完整时 approved=false。\n"
        "3. required_changes 要能直接喂给下一轮 coding。"
    )

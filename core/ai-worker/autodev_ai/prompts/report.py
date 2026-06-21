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

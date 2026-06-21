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

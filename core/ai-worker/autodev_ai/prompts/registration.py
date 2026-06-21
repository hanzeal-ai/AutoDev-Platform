from ..prompt_registry import PromptSpec, register_prompt
from .chat import CHAT_SYSTEM
from .coding import (
    CODING_SYNTHESIZER_SYSTEM,
    coding_agent_system_prompt,
    coding_planner_system_prompt,
)
from .common import PROMPT_VERSION
from .development import DEV_SYNTHESIZER_SYSTEM, dev_architect_system_prompt
from .prd import PRD_SYNTHESIZER_SYSTEM, prd_agent_system_prompt
from .report import REPORT_SYSTEM
from .review import CODE_REVIEW_SYSTEM, PRD_REVIEW_SYSTEM
from .stage import SYNTHESIZER_SYSTEM


def register_all_prompts() -> None:
    specs = [
        PromptSpec(
            key="stage.agent.system",
            version=PROMPT_VERSION,
            stage="stage",
            role="system",
            content=(
                "你是 AI AutoDev 的{label}阶段后台 Agent。"
                "你收到任务后，需要直接用中文回复用户可见的工作过程和产出，不要输出 JSON。"
            ),
        ),
        PromptSpec(
            key="stage.agent.user",
            version=PROMPT_VERSION,
            stage="stage",
            role="user",
            content="阶段 Agent 用户提示词模板，包含项目、阶段、目标和上游上下文。",
        ),
        PromptSpec(
            key="stage.synthesizer.system",
            version=PROMPT_VERSION,
            stage="stage",
            role="system",
            content=SYNTHESIZER_SYSTEM,
        ),
        PromptSpec(
            key="stage.synthesizer.user",
            version=PROMPT_VERSION,
            stage="stage",
            role="user",
            content="阶段结构化编排用户提示词模板，包含默认模板、上下文和 Agent 回复。",
        ),
        PromptSpec(
            key="report.system",
            version=PROMPT_VERSION,
            stage="report",
            role="system",
            content=REPORT_SYSTEM,
        ),
        PromptSpec(
            key="report.user",
            version=PROMPT_VERSION,
            stage="report",
            role="user",
            content="可行性报告用户提示词模板，包含草稿、最近对话和材料元信息。",
        ),
        PromptSpec(
            key="chat.system",
            version=PROMPT_VERSION,
            stage="chat",
            role="system",
            content=CHAT_SYSTEM,
        ),
        PromptSpec(
            key="chat.user",
            version=PROMPT_VERSION,
            stage="chat",
            role="user",
            content="需求澄清用户提示词模板，包含草稿、历史消息、本轮输入和材料元信息。",
        ),
        PromptSpec(
            key="prd.agent.system",
            version=PROMPT_VERSION,
            stage="prd",
            role="system",
            content=prd_agent_system_prompt(),
        ),
        PromptSpec(
            key="prd.agent.user",
            version=PROMPT_VERSION,
            stage="prd",
            role="user",
            content="PRD Agent 用户提示词模板，包含项目和可行性报告上下文。",
        ),
        PromptSpec(
            key="prd.synthesizer.system",
            version=PROMPT_VERSION,
            stage="prd",
            role="system",
            content=PRD_SYNTHESIZER_SYSTEM,
        ),
        PromptSpec(
            key="prd.synthesizer.user",
            version=PROMPT_VERSION,
            stage="prd",
            role="user",
            content="PRD 结构化用户提示词模板，包含项目、可行性报告和 Agent 回复。",
        ),
        PromptSpec(
            key="development.architect.system",
            version=PROMPT_VERSION,
            stage="development",
            role="system",
            content=dev_architect_system_prompt(),
        ),
        PromptSpec(
            key="development.architect.user",
            version=PROMPT_VERSION,
            stage="development",
            role="user",
            content="研发架构用户提示词模板，包含项目、PRD 和可行性报告上下文。",
        ),
        PromptSpec(
            key="development.synthesizer.system",
            version=PROMPT_VERSION,
            stage="development",
            role="system",
            content=DEV_SYNTHESIZER_SYSTEM,
        ),
        PromptSpec(
            key="development.synthesizer.user",
            version=PROMPT_VERSION,
            stage="development",
            role="user",
            content="研发方案结构化用户提示词模板，包含项目、PRD 和架构 Agent 回复。",
        ),
        PromptSpec(
            key="coding.planner.system",
            version=PROMPT_VERSION,
            stage="coding",
            role="system",
            content=coding_planner_system_prompt(),
        ),
        PromptSpec(
            key="coding.planner.user",
            version=PROMPT_VERSION,
            stage="coding",
            role="user",
            content="编码计划用户提示词模板，包含项目和任务拆分方案。",
        ),
        PromptSpec(
            key="coding.agent.system",
            version=PROMPT_VERSION,
            stage="coding",
            role="system",
            content=coding_agent_system_prompt(),
        ),
        PromptSpec(
            key="coding.agent.user",
            version=PROMPT_VERSION,
            stage="coding",
            role="user",
            content="编码 Agent 用户提示词模板，包含项目、任务拆分和 coding planning。",
        ),
        PromptSpec(
            key="coding.synthesizer.system",
            version=PROMPT_VERSION,
            stage="coding",
            role="system",
            content=CODING_SYNTHESIZER_SYSTEM,
        ),
        PromptSpec(
            key="coding.synthesizer.user",
            version=PROMPT_VERSION,
            stage="coding",
            role="user",
            content="代码结构化用户提示词模板，包含项目、任务拆分和编码 Agent 回复。",
        ),
        PromptSpec(
            key="prd_review.system",
            version=PROMPT_VERSION,
            stage="prd_review",
            role="system",
            content=PRD_REVIEW_SYSTEM,
        ),
        PromptSpec(
            key="prd_review.user",
            version=PROMPT_VERSION,
            stage="prd_review",
            role="user",
            content="PRD 评审用户提示词模板，包含项目、可行性报告和 PRD。",
        ),
        PromptSpec(
            key="code_review.system",
            version=PROMPT_VERSION,
            stage="code_review",
            role="system",
            content=CODE_REVIEW_SYSTEM,
        ),
        PromptSpec(
            key="code_review.user",
            version=PROMPT_VERSION,
            stage="code_review",
            role="user",
            content="代码评审用户提示词模板，包含项目、PRD、研发方案和代码生成结果。",
        ),
    ]
    for spec in specs:
        register_prompt(spec)

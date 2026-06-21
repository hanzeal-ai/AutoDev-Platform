"""Versioned prompt templates grouped by workflow domain."""

from .chat import CHAT_SYSTEM, chat_user_prompt
from .coding import (
    CODING_SYNTHESIZER_SYSTEM,
    coding_agent_system_prompt,
    coding_agent_user_prompt,
    coding_planner_system_prompt,
    coding_planner_user_prompt,
    coding_synthesizer_user_prompt,
)
from .common import PROMPT_VERSION, STAGE_LABELS, stage_label
from .development import (
    DEV_SYNTHESIZER_SYSTEM,
    dev_architect_system_prompt,
    dev_architect_user_prompt,
    dev_synthesizer_user_prompt,
)
from .prd import PRD_SYNTHESIZER_SYSTEM, prd_agent_system_prompt, prd_agent_user_prompt, prd_synthesizer_user_prompt
from .registration import register_all_prompts
from .report import REPORT_SYSTEM, report_user_prompt
from .review import (
    CODE_REVIEW_SYSTEM,
    PRD_REVIEW_SYSTEM,
    code_review_user_prompt,
    prd_review_user_prompt,
)
from .stage import SYNTHESIZER_SYSTEM, agent_system_prompt, agent_user_prompt, synthesizer_user_prompt

register_all_prompts()

__all__ = [
    "CHAT_SYSTEM",
    "CODE_REVIEW_SYSTEM",
    "CODING_SYNTHESIZER_SYSTEM",
    "DEV_SYNTHESIZER_SYSTEM",
    "PRD_REVIEW_SYSTEM",
    "PRD_SYNTHESIZER_SYSTEM",
    "PROMPT_VERSION",
    "REPORT_SYSTEM",
    "STAGE_LABELS",
    "SYNTHESIZER_SYSTEM",
    "agent_system_prompt",
    "agent_user_prompt",
    "chat_user_prompt",
    "code_review_user_prompt",
    "coding_agent_system_prompt",
    "coding_agent_user_prompt",
    "coding_planner_system_prompt",
    "coding_planner_user_prompt",
    "coding_synthesizer_user_prompt",
    "dev_architect_system_prompt",
    "dev_architect_user_prompt",
    "dev_synthesizer_user_prompt",
    "prd_agent_system_prompt",
    "prd_agent_user_prompt",
    "prd_review_user_prompt",
    "prd_synthesizer_user_prompt",
    "register_all_prompts",
    "report_user_prompt",
    "stage_label",
    "synthesizer_user_prompt",
]

"""Chat clarification — single-step LLM call returning assistant_reply + report_patch.

Replaces Rust store/reports/chat/mod.rs direct DeepSeek call.
"""

from __future__ import annotations

import json
import logging

from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, SystemMessage

from ..config import ModelConfig
from ..models import ChatContext, ClarificationResult
from ..prompts import CHAT_SYSTEM, chat_user_prompt

logger = logging.getLogger(__name__)

PLACEHOLDER_NAMES = {"待定义", "新项目", "项目", ""}
REPORT_PATCH_FIELDS = {
    "project_name",
    "problem_definition",
    "target_users",
    "core_capabilities",
    "risks_and_constraints",
    "initial_delivery_plan",
    "feasibility_conclusion",
}


async def generate_chat(ctx: ChatContext, cfg: ModelConfig) -> ClarificationResult:
    """Run a single clarification turn and return assistant_reply + report_patch."""

    draft_json = json.dumps(ctx.draft, ensure_ascii=False)

    message_lines = "- 无历史消息"
    if ctx.messages:
        lines = []
        for i, msg in enumerate(ctx.messages[:8], 1):
            content = msg.content[:220]
            lines.append(f"- {i}. [{msg.role}] {content}")
        message_lines = "\n".join(lines)

    material_lines = "- 无材料"
    if ctx.materials:
        lines = []
        for i, mat in enumerate(ctx.materials[:6], 1):
            lines.append(f"- {i}. {mat.name} | {mat.type_hint} | {mat.size_hint} | {mat.status}")
        material_lines = "\n".join(lines)

    llm = ChatOpenAI(
        model=cfg.model,
        api_key=cfg.api_key,
        base_url=cfg.base_url,
        temperature=0.2,
        max_tokens=520,
        model_kwargs={"response_format": {"type": "json_object"}},
    )

    messages = [
        SystemMessage(content=CHAT_SYSTEM),
        HumanMessage(content=chat_user_prompt(
            draft_json, message_lines, material_lines, ctx.user_message,
        )),
    ]

    response = await llm.ainvoke(messages)

    try:
        raw = json.loads(response.content)
    except json.JSONDecodeError:
        logger.warning("Chat JSON parse failed, returning generic reply")
        return ClarificationResult(
            assistant_reply="抱歉，AI 解析失败，请重新描述您的需求。",
            report_patch={},
        )

    return _normalize(raw)


def _normalize(raw: dict) -> ClarificationResult:
    assistant_reply = str(raw.get("assistant_reply", "")).strip()
    if not assistant_reply:
        assistant_reply = "抱歉，AI 未能生成有效回复，请重新描述您的需求。"

    patch = _normalize_report_patch(raw.get("report_patch"))

    return ClarificationResult(assistant_reply=assistant_reply, report_patch=patch)


def _normalize_report_patch(raw_patch) -> dict:
    if not isinstance(raw_patch, dict):
        return {}

    patch: dict = {}

    for field in ("problem_definition", "target_users", "feasibility_conclusion"):
        val = raw_patch.get(field)
        if isinstance(val, str) and val.strip():
            patch[field] = val.strip()

    # project_name: reject placeholders
    pn = raw_patch.get("project_name")
    if isinstance(pn, str) and pn.strip() and pn.strip() not in PLACEHOLDER_NAMES:
        patch["project_name"] = pn.strip()

    for field in ("core_capabilities", "risks_and_constraints", "initial_delivery_plan"):
        val = raw_patch.get(field)
        items: list[str] = []
        if isinstance(val, list):
            items = [str(s).strip() for s in val if str(s).strip()]
        elif isinstance(val, str) and val.strip():
            items = [val.strip()]
        if items:
            # deduplicate, cap at 6
            seen: set[str] = set()
            unique: list[str] = []
            for item in items:
                if item not in seen:
                    seen.add(item)
                    unique.append(item)
            patch[field] = unique[:6]

    return patch

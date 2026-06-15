"""Feasibility report generation — single-step LLM call.

Replaces Rust store/reports/deepseek.rs.
"""

from __future__ import annotations

import json
import logging

from langchain_core.messages import HumanMessage, SystemMessage

from ..config import ModelConfig
from ..llm import create_llm
from ..models import FeasibilityReport, ReportContext
from ..prompts import REPORT_SYSTEM, report_user_prompt
from ..tracing import build_trace_config

logger = logging.getLogger(__name__)

PLACEHOLDER_NAMES = {"待定义", "新项目", "项目", ""}


async def generate_report(ctx: ReportContext, cfg: ModelConfig) -> FeasibilityReport:
    """Generate a feasibility report from thread context."""

    draft_json = json.dumps(ctx.draft, ensure_ascii=False)

    message_lines = "- 无历史消息"
    if ctx.messages:
        lines = []
        for i, msg in enumerate(ctx.messages[:8], 1):
            role = msg.get("role", "user")
            content = str(msg.get("content", ""))[:240]
            lines.append(f"- {i}. [{role}] {content}")
        message_lines = "\n".join(lines)

    material_lines = "- 无材料"
    if ctx.materials:
        lines = []
        for i, mat in enumerate(ctx.materials[:6], 1):
            name = mat.get("name", "")
            type_hint = mat.get("type_hint", "")
            size_hint = mat.get("size_hint", "")
            status = mat.get("status", "")
            lines.append(f"- {i}. {name} | {type_hint} | {size_hint} | {status}")
        material_lines = "\n".join(lines)

    llm = create_llm(cfg, max_tokens=900, json_mode=True)

    messages = [
        SystemMessage(content=REPORT_SYSTEM),
        HumanMessage(content=report_user_prompt(draft_json, message_lines, material_lines)),
    ]

    response = await llm.ainvoke(
        messages,
        config=build_trace_config("feasibility_report", "report", ctx),
    )

    try:
        raw = json.loads(response.content)
    except json.JSONDecodeError:
        logger.warning("Report JSON parse failed, returning draft fallback")
        return _fallback_report(ctx.draft)

    return _normalize_report(raw, ctx.draft)


def _normalize_report(raw: dict, fallback: dict) -> FeasibilityReport:
    """Normalize and sanitize the report output."""
    project_name = raw.get("project_name", "")
    if project_name in PLACEHOLDER_NAMES:
        project_name = fallback.get("project_name", "")

    def capped_list(key: str, limit: int = 6) -> list[str]:
        items = raw.get(key, fallback.get(key, []))
        if not isinstance(items, list):
            return []
        return [str(s).strip() for s in items[:limit] if str(s).strip()]

    return FeasibilityReport(
        project_name=project_name,
        problem_definition=raw.get("problem_definition", fallback.get("problem_definition", "")),
        target_users=raw.get("target_users", fallback.get("target_users", "")),
        core_capabilities=capped_list("core_capabilities"),
        risks_and_constraints=capped_list("risks_and_constraints"),
        initial_delivery_plan=capped_list("initial_delivery_plan"),
        feasibility_conclusion=raw.get(
            "feasibility_conclusion", fallback.get("feasibility_conclusion", "")
        ),
    )


def _fallback_report(draft: dict) -> FeasibilityReport:
    return FeasibilityReport(**{
        k: draft.get(k, "" if isinstance(FeasibilityReport.model_fields[k].default, str) else [])
        for k in FeasibilityReport.model_fields
        if k in draft
    })

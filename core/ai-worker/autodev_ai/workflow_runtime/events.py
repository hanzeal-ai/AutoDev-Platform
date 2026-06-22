"""Workflow event helpers shared by service and graph nodes."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any


def agent_title(stage: str) -> str:
    return {
        "chat": "需求澄清",
        "report": "可行性分析",
        "prd": "产品需求",
        "prd_review": "需求评审",
        "development": "研发规划",
        "coding": "代码生成",
        "code_review": "代码评审",
        "summary": "项目总结",
    }.get(stage, "Workflow")


def prepare_event(stage: str) -> str:
    return f"{stage}: 准备执行{agent_title(stage)} Agent"


def append_event(state: Mapping[str, Any], detail: str) -> list[str]:
    events = list(state.get("events") or [])
    events.append(detail)
    return events


def append_event_once(state: Mapping[str, Any], detail: str) -> list[str]:
    events = list(state.get("events") or [])
    if not events or events[-1] != detail:
        events.append(detail)
    return events

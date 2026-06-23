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
    detail = {
        "chat": "正在思考用户需求是否清晰，并判断是否需要补充信息",
        "report": "正在分析需求可行性并生成可行性报告",
        "prd": "正在梳理产品目标、用户场景和需求边界",
        "prd_review": "正在评审 PRD 是否完整、可实现、可验收",
        "development": "正在拆解研发任务和模块实现顺序",
        "coding": "正在拆解编码任务，并通过 OpenSpec 流程准备写入代码",
        "code_review": "正在检查代码实现是否满足 PRD 和研发计划",
        "summary": "正在汇总项目完成情况和交付产物",
    }.get(stage, f"正在执行{agent_title(stage)} Agent")
    return f"{stage}: {detail}"


def append_event(state: Mapping[str, Any], detail: str) -> list[str]:
    events = list(state.get("events") or [])
    events.append(detail)
    return events


def append_event_once(state: Mapping[str, Any], detail: str) -> list[str]:
    events = list(state.get("events") or [])
    if not events or events[-1] != detail:
        events.append(detail)
    return events

"""Shared workflow type definitions."""

from __future__ import annotations

from collections.abc import Awaitable, Callable
from typing import Any, Literal, TypedDict


class AutoDevWorkflowState(TypedDict, total=False):
    workflow_id: str
    thread_id: str
    project_id: str
    project_name: str
    user_message: str
    draft: dict[str, Any]
    messages: list[dict[str, Any]]
    materials: list[dict[str, Any]]
    current_phase: str
    awaiting_user_input: bool
    error: str | None
    chat_result: dict[str, Any]
    feasibility_report: dict[str, Any]
    prd_result: dict[str, Any]
    prd_review_result: dict[str, Any]
    prd_review_iteration: int
    max_prd_review_iterations: int
    development_plan: dict[str, Any]
    coding_result: dict[str, Any]
    code_review_result: dict[str, Any]
    code_review_iteration: int
    max_code_review_iterations: int
    workflow_summary: dict[str, Any]
    events: list[str]


NodeName = Literal[
    "chat",
    "report",
    "prd",
    "prd_review",
    "development",
    "coding",
    "code_review",
    "summary",
]

WorkflowNode = Callable[[AutoDevWorkflowState], Awaitable[dict[str, Any]]]

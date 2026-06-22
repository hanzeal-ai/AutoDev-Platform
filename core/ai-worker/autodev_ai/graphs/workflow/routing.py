"""Routing functions for the unified workflow graph."""

from __future__ import annotations

from ...workflow_runtime.schema import (
    DEFAULT_MAX_CODE_REVIEW_ITERATIONS,
    DEFAULT_MAX_PRD_REVIEW_ITERATIONS,
)
from ...workflow_runtime.types import AutoDevWorkflowState


def route_after_chat(state: AutoDevWorkflowState) -> str:
    if state.get("awaiting_user_input"):
        return "awaiting_user_input"
    return "report"


def route_after_phase(state: AutoDevWorkflowState) -> str:
    if state.get("error"):
        return "stop"
    return "continue"


def route_after_prd_review(state: AutoDevWorkflowState) -> str:
    if state.get("error") or state.get("awaiting_user_input"):
        return "stop"
    review = state.get("prd_review_result") or {}
    if bool(review.get("approved")):
        return "development"
    if state.get("current_phase") == "prd_review_blocked":
        return "stop"
    if int(state.get("prd_review_iteration", 0)) >= int(
        state.get("max_prd_review_iterations", DEFAULT_MAX_PRD_REVIEW_ITERATIONS)
    ):
        return "stop"
    return "prd"


def route_after_code_review(state: AutoDevWorkflowState) -> str:
    if state.get("error") or state.get("awaiting_user_input"):
        return "stop"
    review = state.get("code_review_result") or {}
    if bool(review.get("approved")):
        return "summary"
    if state.get("current_phase") == "code_review_blocked":
        return "stop"
    if int(state.get("code_review_iteration", 0)) >= int(
        state.get("max_code_review_iterations", DEFAULT_MAX_CODE_REVIEW_ITERATIONS)
    ):
        return "stop"
    return "coding"

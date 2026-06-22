"""Workflow progress helpers shared by execution and projection."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

from .schema import WORKFLOW_ARTIFACTS, WORKFLOW_ORDER


def active_step_from_state(state: Mapping[str, Any]) -> str:
    current_phase = str(state.get("current_phase") or "").strip()
    if not current_phase:
        return "not_started"
    if (
        state.get("error")
        or state.get("awaiting_user_input")
        or current_phase == "workflow_complete"
        or current_phase.endswith("_failed")
        or current_phase.endswith("_blocked")
    ):
        return step_from_phase(current_phase)

    if current_phase == "prd_review_revision_required":
        return "prd"
    if current_phase == "code_review_revision_required":
        return "coding"
    phase_step = step_from_phase(current_phase)
    if current_phase.endswith("_complete") and phase_step in WORKFLOW_ORDER:
        phase_index = WORKFLOW_ORDER.index(phase_step)
        for stage in WORKFLOW_ORDER[phase_index + 1 :]:
            spec = WORKFLOW_ARTIFACTS[stage]
            artifact = state.get(spec["state_key"])
            if not artifact:
                return stage
            if stage == "prd_review" and needs_revision(artifact):
                return "prd"
            if stage == "code_review" and needs_revision(artifact):
                return "coding"
        return "summary"

    for stage in WORKFLOW_ORDER:
        spec = WORKFLOW_ARTIFACTS[stage]
        artifact = state.get(spec["state_key"])
        if not artifact:
            return stage
        if stage == "prd_review" and needs_revision(artifact):
            return "prd"
        if stage == "code_review" and needs_revision(artifact):
            return "coding"
    return "summary"


def step_from_phase(current_phase: str) -> str:
    if not current_phase:
        return "not_started"
    if current_phase == "workflow_complete":
        return "summary"
    if current_phase == "awaiting_user_input":
        return "chat"
    if current_phase.startswith("chat"):
        return "chat"
    if current_phase.startswith("report"):
        return "report"
    if current_phase.startswith("prd_review"):
        return "prd_review"
    if current_phase.startswith("prd"):
        return "prd"
    if current_phase.startswith("development"):
        return "development"
    if current_phase.startswith("code_review"):
        return "code_review"
    if current_phase.startswith("coding"):
        return "coding"
    if current_phase.startswith("summary"):
        return "summary"
    return current_phase.split("_", 1)[0]


def needs_revision(review: dict[str, Any] | None) -> bool:
    return bool(review) and not bool((review or {}).get("approved"))

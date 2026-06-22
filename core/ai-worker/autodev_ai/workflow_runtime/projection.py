"""Workflow status, event, and artifact projection helpers."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

from ..text_tools import string_list as _string_list
from .progress import active_step_from_state, needs_revision
from .schema import (
    DEFAULT_MAX_CODE_REVIEW_ITERATIONS,
    DEFAULT_MAX_PRD_REVIEW_ITERATIONS,
    WORKFLOW_ARTIFACTS,
    WORKFLOW_ORDER,
)


def build_workflow_status(state: Mapping[str, Any]) -> dict[str, Any]:
    """Return workflow progress metadata without embedding large artifact payloads."""
    workflow_id = str(state.get("workflow_id") or state.get("project_id") or "").strip()
    current_phase = str(state.get("current_phase") or "").strip()
    current_step = active_step_from_state(state)
    error = state.get("error")
    awaiting_user_input = bool(state.get("awaiting_user_input"))
    status = workflow_status(current_phase, error, awaiting_user_input)
    phases = {
        stage: _phase_status(state, workflow_id, stage)
        for stage in WORKFLOW_ARTIFACTS
    }
    artifacts = [
        {
            "artifact_id": phase["artifact_id"],
            "stage": stage,
            "name": phase["name"],
            "kind": phase["kind"],
            "status": phase["status"],
        }
        for stage, phase in phases.items()
        if phase.get("artifact_id")
    ]
    return {
        "workflow_id": workflow_id,
        "thread_id": state.get("thread_id", ""),
        "project_id": state.get("project_id", ""),
        "project_name": state.get("project_name", ""),
        "current_phase": current_phase,
        "current_step": current_step,
        "status": status,
        "awaiting_user_input": awaiting_user_input,
        "error": error,
        "phases": phases,
        "artifacts": artifacts,
    }


def build_workflow_events(state: Mapping[str, Any]) -> dict[str, Any]:
    """Return detailed workflow progress events without artifact payloads."""
    status = build_workflow_status(state)
    workflow_id = str(status.get("workflow_id") or "").strip()
    events: list[dict[str, Any]] = []

    for sequence, (stage, phase) in enumerate(status["phases"].items(), start=1):
        phase_status = str(phase.get("status") or "pending")
        events.append(
            {
                "id": f"{workflow_id}:{stage}:phase" if workflow_id else f"{stage}:phase",
                "sequence": sequence,
                "type": "phase",
                "stage": stage,
                "title": phase["name"],
                "detail": _phase_event_detail(stage, phase_status, state),
                "status": phase_status,
                "artifact_id": phase.get("artifact_id"),
            }
        )

    sequence = len(events) + 1
    for index, raw_event in enumerate(state.get("events") or [], start=0):
        detail = str(raw_event).strip()
        if not detail:
            continue
        events.append(
            {
                "id": f"{workflow_id}:log:{index}" if workflow_id else f"log:{index}",
                "sequence": sequence,
                "type": "log",
                "stage": _event_stage(detail, str(status["current_step"])),
                "title": "过程事件",
                "detail": detail[:2048],
                "status": _workflow_log_status(detail),
                "artifact_id": None,
            }
        )
        sequence += 1

    return {
        "workflow_id": workflow_id,
        "thread_id": status["thread_id"],
        "project_id": status["project_id"],
        "project_name": status["project_name"],
        "current_phase": status["current_phase"],
        "current_step": status["current_step"],
        "status": status["status"],
        "awaiting_user_input": status["awaiting_user_input"],
        "error": status["error"],
        "events": events,
    }


def build_workflow_artifact(
    state: Mapping[str, Any],
    artifact_id: str,
) -> dict[str, Any] | None:
    workflow_id = str(state.get("workflow_id") or state.get("project_id") or "").strip()
    if not workflow_id or not artifact_id.startswith(f"{workflow_id}:"):
        return None
    stage = artifact_id.removeprefix(f"{workflow_id}:")
    spec = WORKFLOW_ARTIFACTS.get(stage)
    if spec is None:
        return None
    content = state.get(spec["state_key"])
    if not content:
        return None
    return {
        "artifact_id": artifact_id,
        "workflow_id": workflow_id,
        "project_id": state.get("project_id", ""),
        "stage": stage,
        "name": spec["name"],
        "kind": spec["kind"],
        "content_type": "application/json",
        "content": content,
    }


def workflow_status(
    current_phase: str,
    error: Any,
    awaiting_user_input: bool,
) -> str:
    if error:
        return "failed"
    if awaiting_user_input or current_phase == "awaiting_user_input":
        return "awaiting_user_input"
    if current_phase == "workflow_complete":
        return "completed"
    if current_phase.endswith("_blocked"):
        return "blocked"
    if not current_phase:
        return "not_started"
    return "running"


def _phase_status(state: Mapping[str, Any], workflow_id: str, stage: str) -> dict[str, Any]:
    spec = WORKFLOW_ARTIFACTS[stage]
    current_step = active_step_from_state(state)
    has_artifact = bool(state.get(spec["state_key"]))
    if _stage_is_stale_after_revision(state, stage, current_step):
        has_artifact = False
    status = "completed" if has_artifact else "pending"
    if current_step == stage and workflow_status(
        str(state.get("current_phase") or ""),
        state.get("error"),
        bool(state.get("awaiting_user_input")),
    ) == "running":
        status = "running"
    if current_step == stage and state.get("error"):
        status = "failed"
    if current_step == stage and state.get("awaiting_user_input"):
        status = "awaiting_user_input"
    if current_step == stage and str(state.get("current_phase") or "").endswith("_blocked"):
        status = "blocked"
    artifact_id = f"{workflow_id}:{stage}" if workflow_id and has_artifact else None
    return {
        "status": status,
        "artifact_id": artifact_id,
        "name": _phase_name(state, stage, str(spec["name"])),
        "kind": spec["kind"],
    }


def _phase_event_detail(stage: str, status: str, state: Mapping[str, Any]) -> str:
    if status == "completed":
        return "阶段产物已生成"
    if status == "running":
        return "正在执行当前阶段"
    if status == "awaiting_user_input":
        return "等待用户补充信息"
    if status == "failed":
        return str(state.get("error") or "阶段执行失败")
    if status == "blocked":
        return _blocked_reason(stage, state)
    if stage == "chat":
        return "等待启动需求澄清"
    return "等待上游阶段完成"


def _stage_is_stale_after_revision(
    state: Mapping[str, Any],
    stage: str,
    current_step: str,
) -> bool:
    if stage not in WORKFLOW_ORDER or current_step not in WORKFLOW_ORDER:
        return False
    stage_index = WORKFLOW_ORDER.index(stage)
    current_index = WORKFLOW_ORDER.index(current_step)
    if needs_revision(state.get("prd_review_result")) and current_step == "prd":
        return stage_index > current_index
    if needs_revision(state.get("code_review_result")) and current_step == "coding":
        return stage_index > current_index
    return False


def _phase_name(state: Mapping[str, Any], stage: str, fallback: str) -> str:
    if stage == "prd":
        return f"第 {_prd_round(state)} 轮产品需求文档"
    if stage == "prd_review":
        return f"第 {_prd_review_round(state)} 轮需求评审"
    if stage == "coding":
        return f"第 {_coding_round(state)} 轮代码开发"
    if stage == "code_review":
        return f"第 {_code_review_round(state)} 轮代码评审"
    return fallback


def _prd_round(state: Mapping[str, Any]) -> int:
    return max(1, int(state.get("prd_review_iteration") or 0) + 1)


def _prd_review_round(state: Mapping[str, Any]) -> int:
    completed_reviews = int(state.get("prd_review_iteration") or 0)
    if active_step_from_state(state) == "prd_review" and not state.get("prd_review_result"):
        return max(1, completed_reviews + 1)
    return max(1, completed_reviews)


def _coding_round(state: Mapping[str, Any]) -> int:
    return max(1, int(state.get("code_review_iteration") or 0) + 1)


def _code_review_round(state: Mapping[str, Any]) -> int:
    completed_reviews = int(state.get("code_review_iteration") or 0)
    if active_step_from_state(state) == "code_review" and not state.get("code_review_result"):
        return max(1, completed_reviews + 1)
    return max(1, completed_reviews)


def _blocked_reason(stage: str, state: Mapping[str, Any]) -> str:
    if stage == "prd_review":
        reason = _review_reason(state.get("prd_review_result"), "需求评审未通过")
        if _review_reached_limit(state, "prd_review"):
            return f"已达到最大需求评审次数（{_review_limit(state, 'prd_review')} 次），需求评审不通过。{reason}"
        return reason
    if stage == "code_review":
        reason = _review_reason(state.get("code_review_result"), "代码审核不通过")
        if _review_reached_limit(state, "code_review"):
            return f"已达到最大代码评审次数（{_review_limit(state, 'code_review')} 次），代码审核不通过。{reason}"
        return reason
    return "流程阻塞，等待人工确认或补充处理。"


def _review_reached_limit(state: Mapping[str, Any], stage: str) -> bool:
    iteration_key = f"{stage}_iteration"
    return int(state.get(iteration_key) or 0) >= _review_limit(state, stage)


def _review_limit(state: Mapping[str, Any], stage: str) -> int:
    if stage == "prd_review":
        return int(state.get("max_prd_review_iterations") or DEFAULT_MAX_PRD_REVIEW_ITERATIONS)
    if stage == "code_review":
        return int(state.get("max_code_review_iterations") or DEFAULT_MAX_CODE_REVIEW_ITERATIONS)
    return 0


def _review_reason(review: Any, fallback: str) -> str:
    if not isinstance(review, dict):
        return fallback
    summary = str(review.get("summary") or "").strip()
    changes = _string_list(review.get("required_changes"), 3, 160)
    issues = [
        str(issue.get("description") or "").strip()
        for issue in review.get("issues", [])[:3]
        if isinstance(issue, dict) and str(issue.get("description") or "").strip()
    ]
    parts = [summary, *changes, *issues]
    reason = "；".join(part for part in parts if part)
    return reason or fallback


def _workflow_log_status(detail: str) -> str:
    if "准备执行" in detail:
        return "running"
    if "正在使用 OpenSpec" in detail or "正在初始化 OpenSpec" in detail:
        return "running"
    if "执行失败" in detail:
        return "failed"
    if "阻塞" in detail:
        return "blocked"
    if "补充" in detail:
        return "awaiting_user_input"
    return "completed"


def _event_stage(detail: str, fallback: str) -> str:
    prefix = detail.split(":", 1)[0].strip()
    return prefix if prefix in WORKFLOW_ARTIFACTS else fallback

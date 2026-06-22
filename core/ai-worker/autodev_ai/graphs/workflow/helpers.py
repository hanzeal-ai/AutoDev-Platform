"""Internal helpers for workflow graph nodes."""

from __future__ import annotations

import json
from collections.abc import Awaitable, Callable, Mapping
from typing import Any

from ...json_tools import extract_json_fallback as _extract_json_fallback
from ...text_tools import string_list as _string_list
from ...workflow_runtime.events import append_event, append_event_once, prepare_event
from ...workflow_runtime.types import AutoDevWorkflowState


def _phase_result(worker_state: dict[str, Any], result_key: str, phase: str) -> dict[str, Any]:
    if worker_state.get("error"):
        raise RuntimeError(str(worker_state["error"]))
    result = worker_state.get("result")
    if result is None:
        raise RuntimeError(f"{phase} completed without result")
    if hasattr(result, "model_dump"):
        result = result.model_dump()
    return {result_key: result, "current_phase": phase, "error": None}


async def _with_node_errors(
    state: AutoDevWorkflowState,
    stage: str,
    run: Callable[[], Awaitable[dict[str, Any]]],
) -> dict[str, Any]:
    started_events = append_event_once(state, prepare_event(stage))
    try:
        result = await run()
        result["events"] = _merge_node_events(state, started_events, result.get("events"))
        return result
    except Exception as exc:
        failed_state = dict(state)
        failed_state["events"] = started_events
        return _node_error(failed_state, stage, exc)


def _merge_node_events(
    state: Mapping[str, Any],
    started_events: list[str],
    result_events: Any,
) -> list[str]:
    if not isinstance(result_events, list):
        return started_events
    base_count = len(state.get("events") or [])
    merged = list(started_events)
    for event in result_events[base_count:]:
        if event not in merged:
            merged.append(str(event))
    return merged


def _node_error(
    state: Mapping[str, Any],
    stage: str,
    exc: Exception,
) -> dict[str, Any]:
    message = _exception_message(exc)
    return {
        "current_phase": f"{stage}_failed",
        "awaiting_user_input": False,
        "error": message,
        "events": append_event(state, f"{stage}: 执行失败：{message}"),
    }


def _exception_message(exc: Exception) -> str:
    message = str(exc).strip()
    normalized = message.lower()
    if "insufficient balance" in normalized or "error code: 402" in normalized:
        return "模型服务余额不足，请检查 API Key 对应账户余额或更换可用 Key。"
    if "401" in normalized or "unauthorized" in normalized or "invalid api key" in normalized:
        return "模型服务鉴权失败，请检查 .env 中的 API Key 是否正确。"
    if "rate limit" in normalized or "too many requests" in normalized:
        return "模型服务请求频率受限，请稍后重试或调整调用频率。"
    if "timeout" in normalized or "timed out" in normalized:
        return "模型服务请求超时，请稍后重试。"
    return message[:2048] if message else exc.__class__.__name__


def _parse_review_response(raw_text: str, *, default_summary: str) -> dict[str, Any]:
    try:
        raw = json.loads(raw_text)
    except json.JSONDecodeError:
        raw = _extract_json_fallback(raw_text) or {}
    return _normalize_review(raw, default_summary=default_summary)


def _normalize_review(raw: dict[str, Any], *, default_summary: str) -> dict[str, Any]:
    if not isinstance(raw, dict):
        raw = {}
    issues = []
    for issue in raw.get("issues", [])[:20]:
        if not isinstance(issue, dict):
            continue
        description = str(issue.get("description", "")).strip()
        if not description:
            continue
        severity = str(issue.get("severity", "major")).strip().lower()
        if severity not in {"blocker", "major", "minor"}:
            severity = "major"
        issues.append(
            {
                "severity": severity,
                "area": str(issue.get("area", "")).strip()[:128],
                "description": description[:1024],
                "recommendation": str(issue.get("recommendation", "")).strip()[:1024],
            }
        )

    required_changes = _string_list(raw.get("required_changes"), 20, 1024)
    missing_information = _string_list(raw.get("missing_information"), 10, 512)
    requires_user_input = bool(raw.get("requires_user_input")) or bool(missing_information)
    approved = bool(raw.get("approved")) and not requires_user_input
    return {
        "approved": approved,
        "requires_user_input": requires_user_input,
        "summary": str(raw.get("summary") or default_summary).strip()[:2048],
        "issues": issues,
        "required_changes": required_changes,
        "missing_information": missing_information,
    }


def _review_phase(
    review: dict[str, Any],
    *,
    iteration: int,
    max_iterations: int,
    passed_phase: str,
    revision_phase: str,
    blocked_phase: str,
) -> str:
    if review.get("approved"):
        return passed_phase
    if review.get("requires_user_input"):
        return "awaiting_user_input"
    if iteration >= max_iterations:
        return blocked_phase
    return revision_phase


def _review_event_suffix(review: dict[str, Any], phase: str) -> str:
    if review.get("approved"):
        return "通过"
    if review.get("requires_user_input"):
        return "需要用户补充信息"
    if phase.endswith("_blocked"):
        return "阻塞"
    return "需要修订"


def _review_feedback(review: dict[str, Any]) -> dict[str, Any]:
    return {
        "summary": str(review.get("summary", ""))[:1000],
        "required_changes": _string_list(review.get("required_changes"), 20, 512),
        "missing_information": _string_list(review.get("missing_information"), 10, 512),
        "issues": [
            {
                "severity": issue.get("severity", ""),
                "area": issue.get("area", ""),
                "description": issue.get("description", ""),
                "recommendation": issue.get("recommendation", ""),
            }
            for issue in review.get("issues", [])[:10]
            if isinstance(issue, dict)
        ],
    }


def _merge_report_patch(draft: dict[str, Any], patch: dict[str, Any]) -> dict[str, Any]:
    merged = dict(draft)
    for key, value in patch.items():
        if value not in ("", None, []):
            merged[key] = value
    return merged


def _draft_ready_for_report(draft: Mapping[str, Any]) -> bool:
    required_fields = (
        "project_name",
        "problem_definition",
        "target_users",
        "core_capabilities",
    )
    return all(_has_meaningful_value(draft.get(field)) for field in required_fields)


def _has_meaningful_value(value: Any) -> bool:
    if value is None:
        return False
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, list):
        return any(_has_meaningful_value(item) for item in value)
    if isinstance(value, dict):
        return any(_has_meaningful_value(item) for item in value.values())
    return True


def _project_name(state: AutoDevWorkflowState, candidate: dict[str, Any]) -> str:
    value = str(candidate.get("project_name") or state.get("project_name") or "").strip()
    return value or "AutoDev 项目"


def _required(state: AutoDevWorkflowState, field: str) -> str:
    value = str(state.get(field, "")).strip()
    if not value:
        raise ValueError(f"workflow state missing required field: {field}")
    return value

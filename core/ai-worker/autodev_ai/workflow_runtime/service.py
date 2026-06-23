"""Workflow service facade around the unified LangGraph graph."""

from __future__ import annotations

import os
import time
from collections.abc import AsyncIterator, Mapping
from pathlib import Path
from typing import Any

from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver

from ..graphs.workflow import build_workflow_graph
from ..models import WorkflowStartContext, WorkflowStreamContext
from .events import agent_title, append_event, append_event_once, prepare_event
from .progress import active_step_from_state as _active_step_from_state
from .progress import step_from_phase as _step_from_phase
from .projection import (
    build_workflow_artifact,
    build_workflow_events,
    build_workflow_status,
)
from .schema import (
    WORKFLOW_ARTIFACTS,
    WORKFLOW_NODE_COMPLETE_PHASE,
    WORKFLOW_ORDER,
    WORKFLOW_PREVIOUS_NODE,
)
from .types import AutoDevWorkflowState, NodeName


def workflow_config(workflow_id: str) -> dict[str, Any]:
    """Return the LangGraph config that scopes checkpoints to one workflow."""
    return {"configurable": {"thread_id": workflow_id}, "recursion_limit": 100}


def get_workflow_checkpoint_path() -> Path:
    configured = os.environ.get("AI_WORKFLOW_CHECKPOINT_PATH", "").strip()
    if configured:
        return Path(configured).expanduser()
    return Path(__file__).resolve().parents[2] / ".checkpoints" / "autodev_workflow.sqlite"


async def start_workflow(ctx: WorkflowStartContext) -> dict[str, Any]:
    workflow_id = ctx.workflow_id or ctx.thread_id
    state = ctx.model_dump()
    action = _normalize_workflow_action(str(state.pop("action", "continue")))
    state["workflow_id"] = workflow_id
    if action == "skip":
        return await _skip_current_step(state, workflow_id)
    if _draft_ready_for_report(state.get("draft") or {}):
        state = _prepare_from_confirmed_feasibility(state)
        return await _resume_persistent_workflow_after_node(state, workflow_id, "report")
    state = _prepare_node_state(state, "chat")
    return await _invoke_persistent_workflow(state, workflow_id)


async def resume_workflow(workflow_id: str, *, action: str = "continue") -> dict[str, Any]:
    state = await _get_checkpoint_state(workflow_id)
    action = _normalize_workflow_action(action)
    if action == "skip":
        return await _skip_current_step(state, workflow_id)
    if action == "rerun":
        return await _rerun_current_step(state, workflow_id)
    if _can_continue_from_awaiting_chat(state):
        next_state = dict(state)
        next_state["awaiting_user_input"] = False
        next_state["current_phase"] = "chat_complete"
        return await _resume_persistent_workflow_after_node(next_state, workflow_id, "chat")
    retry = _retry_from_failed_phase(state)
    if retry:
        retry_state, retry_after = retry
        return await _resume_persistent_workflow_after_node(
            retry_state,
            workflow_id,
            retry_after,
        )
    if action == "retry":
        return await _rerun_current_step(state, workflow_id)
    resume_after = _resume_node_from_completed_phase(state)
    if resume_after:
        return await _resume_persistent_workflow_after_node(state, workflow_id, resume_after)
    return await _invoke_persistent_workflow(None, workflow_id)


async def get_workflow_status(workflow_id: str) -> dict[str, Any]:
    return build_workflow_status(await _get_checkpoint_state(workflow_id))


async def get_workflow_events(workflow_id: str) -> dict[str, Any]:
    return build_workflow_events(await _get_checkpoint_state(workflow_id))


async def get_workflow_artifact(workflow_id: str, artifact_id: str) -> dict[str, Any] | None:
    return build_workflow_artifact(await _get_checkpoint_state(workflow_id), artifact_id)


async def stream_workflow(ctx: WorkflowStreamContext) -> AsyncIterator[dict[str, Any]]:
    """Stream workflow snapshots while executing the checkpointed graph."""
    workflow_id = ctx.workflow_id or ctx.thread_id
    yield _stream_event("workflow_started", workflow_id, detail="workflow stream started")
    try:
        if ctx.mode == "start":
            async for event in _stream_start_workflow(ctx, workflow_id):
                yield event
        else:
            async for event in _stream_resume_workflow(ctx, workflow_id):
                yield event
    except Exception as exc:
        yield {
            "type": "workflow_error",
            "workflow_id": workflow_id,
            "detail": str(exc),
        }


async def _get_checkpoint_state(workflow_id: str) -> dict[str, Any]:
    checkpoint_path = get_workflow_checkpoint_path()
    checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
    async with AsyncSqliteSaver.from_conn_string(str(checkpoint_path)) as checkpointer:
        graph = build_workflow_graph(checkpointer=checkpointer)
        snapshot = await graph.aget_state(workflow_config(workflow_id))
    return dict(snapshot.values or {})


async def _invoke_persistent_workflow(
    state: AutoDevWorkflowState | None,
    workflow_id: str,
) -> dict[str, Any]:
    checkpoint_path = get_workflow_checkpoint_path()
    checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
    async with AsyncSqliteSaver.from_conn_string(str(checkpoint_path)) as checkpointer:
        graph = build_workflow_graph(checkpointer=checkpointer)
        result = await graph.ainvoke(state, config=workflow_config(workflow_id))
    return build_workflow_status(dict(result or {}))


async def _stream_start_workflow(
    ctx: WorkflowStreamContext,
    workflow_id: str,
) -> AsyncIterator[dict[str, Any]]:
    state = ctx.model_dump()
    mode = state.pop("mode", "start")
    action = _normalize_workflow_action(str(state.pop("action", "continue")))
    state["workflow_id"] = workflow_id
    if action == "skip":
        status = await _skip_current_step(state, workflow_id)
        yield _stream_event("workflow_done", workflow_id, status=status, detail=f"{mode}: skip")
        return
    if action in {"rerun", "retry"}:
        async for event in _stream_rerun_current_step(state, workflow_id):
            yield event
        return
    if _draft_ready_for_report(state.get("draft") or {}):
        state = _prepare_from_confirmed_feasibility(state)
        async for event in _stream_resume_persistent_workflow_after_node(state, workflow_id, "report"):
            yield event
        return
    state = _prepare_node_state(state, "chat")
    async for event in _stream_invoke_persistent_workflow(state, workflow_id):
        yield event


async def _stream_resume_workflow(
    ctx: WorkflowStreamContext,
    workflow_id: str,
) -> AsyncIterator[dict[str, Any]]:
    state = await _get_checkpoint_state(workflow_id)
    action = _normalize_workflow_action(ctx.action)
    if action == "skip":
        status = await _skip_current_step(state, workflow_id)
        yield _stream_event("workflow_done", workflow_id, status=status, detail="resume: skip")
        return
    if action == "rerun":
        async for event in _stream_rerun_current_step(state, workflow_id):
            yield event
        return
    if _can_continue_from_awaiting_chat(state):
        next_state = dict(state)
        next_state["awaiting_user_input"] = False
        next_state["current_phase"] = "chat_complete"
        async for event in _stream_resume_persistent_workflow_after_node(next_state, workflow_id, "chat"):
            yield event
        return
    retry = _retry_from_failed_phase(state)
    if retry:
        retry_state, retry_after = retry
        async for event in _stream_resume_persistent_workflow_after_node(retry_state, workflow_id, retry_after):
            yield event
        return
    if action == "retry":
        async for event in _stream_rerun_current_step(state, workflow_id):
            yield event
        return
    resume_after = _resume_node_from_completed_phase(state)
    if resume_after:
        async for event in _stream_resume_persistent_workflow_after_node(state, workflow_id, resume_after):
            yield event
        return
    async for event in _stream_invoke_persistent_workflow(None, workflow_id):
        yield event


async def _stream_invoke_persistent_workflow(
    state: AutoDevWorkflowState | None,
    workflow_id: str,
) -> AsyncIterator[dict[str, Any]]:
    checkpoint_path = get_workflow_checkpoint_path()
    checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
    async with AsyncSqliteSaver.from_conn_string(str(checkpoint_path)) as checkpointer:
        graph = build_workflow_graph(checkpointer=checkpointer)
        config = workflow_config(workflow_id)
        merged_state: dict[str, Any] = dict(state or {})
        status = build_workflow_status(merged_state)
        yield _stream_event(
            "workflow_update",
            workflow_id,
            status=status,
            event=_latest_stream_log(merged_state, workflow_id, status),
        )
        async for chunk in graph.astream(state, config=config, stream_mode=["updates", "custom"]):
            custom_event = _merge_custom_stream_event(merged_state, chunk, workflow_id)
            if custom_event is not None:
                yield custom_event
                continue
            _merge_stream_update(merged_state, chunk)
            status = build_workflow_status(merged_state)
            yield _stream_event(
                "workflow_update",
                workflow_id,
                status=status,
                event=_latest_stream_log(merged_state, workflow_id, status),
            )
        snapshot = await graph.aget_state(config)
        final_state = dict(snapshot.values or merged_state)
    status = build_workflow_status(final_state)
    yield _stream_event(
        "workflow_done",
        workflow_id,
        status=status,
        event=_latest_stream_log(final_state, workflow_id, status),
    )


async def _stream_resume_persistent_workflow_after_node(
    state: AutoDevWorkflowState,
    workflow_id: str,
    node: NodeName,
) -> AsyncIterator[dict[str, Any]]:
    checkpoint_path = get_workflow_checkpoint_path()
    checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
    async with AsyncSqliteSaver.from_conn_string(str(checkpoint_path)) as checkpointer:
        graph = build_workflow_graph(checkpointer=checkpointer)
        config = workflow_config(workflow_id)
        prepared = _prepare_node_state(state, _active_step_from_state(state))
        await graph.aupdate_state(config, prepared, as_node=node)
        merged_state: dict[str, Any] = dict(prepared)
        status = build_workflow_status(merged_state)
        yield _stream_event(
            "workflow_update",
            workflow_id,
            status=status,
            event=_latest_stream_log(merged_state, workflow_id, status),
        )
        async for chunk in graph.astream(None, config=config, stream_mode=["updates", "custom"]):
            custom_event = _merge_custom_stream_event(merged_state, chunk, workflow_id)
            if custom_event is not None:
                yield custom_event
                continue
            _merge_stream_update(merged_state, chunk)
            status = build_workflow_status(merged_state)
            yield _stream_event(
                "workflow_update",
                workflow_id,
                status=status,
                event=_latest_stream_log(merged_state, workflow_id, status),
            )
        snapshot = await graph.aget_state(config)
        final_state = dict(snapshot.values or merged_state)
    status = build_workflow_status(final_state)
    yield _stream_event(
        "workflow_done",
        workflow_id,
        status=status,
        event=_latest_stream_log(final_state, workflow_id, status),
    )


async def _stream_rerun_current_step(
    state: Mapping[str, Any],
    workflow_id: str,
) -> AsyncIterator[dict[str, Any]]:
    stage = _action_stage(state)
    next_state = _reset_from_stage(state, stage)
    next_state["awaiting_user_input"] = False
    next_state["error"] = None
    next_state["events"] = _events_without_stage(next_state, stage)
    next_state["events"] = append_event(next_state, f"{stage}: 重新执行")
    if stage == "chat":
        next_state["current_phase"] = ""
        async for event in _stream_invoke_persistent_workflow(_prepare_node_state(next_state, "chat"), workflow_id):
            yield event
        return
    previous_node = WORKFLOW_PREVIOUS_NODE[stage]
    next_state["current_phase"] = WORKFLOW_NODE_COMPLETE_PHASE[previous_node]
    async for event in _stream_resume_persistent_workflow_after_node(next_state, workflow_id, previous_node):
        yield event


def _merge_stream_update(state: dict[str, Any], chunk: Any) -> None:
    if isinstance(chunk, tuple) and len(chunk) == 2:
        mode, payload = chunk
        if mode != "updates":
            return
        chunk = payload
    if not isinstance(chunk, Mapping):
        return
    for value in chunk.values():
        if isinstance(value, Mapping):
            state.update(value)


def _merge_custom_stream_event(
    state: dict[str, Any],
    chunk: Any,
    workflow_id: str,
) -> dict[str, Any] | None:
    if not (isinstance(chunk, tuple) and len(chunk) == 2 and chunk[0] == "custom"):
        return None
    payload = chunk[1]
    if not isinstance(payload, Mapping) or payload.get("type") != "workflow_log":
        return None
    detail = str(payload.get("detail") or "").strip()
    if not detail:
        return None
    events = list(state.get("events") or [])
    if not events or events[-1] != detail:
        events.append(detail)
    state["events"] = events
    stage = str(payload.get("stage") or _stage_from_event_detail(detail, str(state.get("current_step") or "")))
    if stage in WORKFLOW_ARTIFACTS:
        event_status = _stream_log_status(detail)
        if event_status == "failed":
            state["current_phase"] = f"{stage}_failed"
            state["error"] = _event_error_message(detail)
        elif event_status == "blocked":
            state["current_phase"] = f"{stage}_blocked"
            state["error"] = None
        else:
            state["current_phase"] = f"{stage}_running"
            state["error"] = None
    status = build_workflow_status(state)
    return _stream_event(
        "workflow_update",
        workflow_id,
        status=status,
        event=_stream_log_event(
            workflow_id,
            sequence=len(events),
            stage=stage,
            detail=detail,
        ),
    )


def _stream_event(
    event_type: str,
    workflow_id: str,
    *,
    status: dict[str, Any] | None = None,
    detail: str = "",
    event: dict[str, Any] | None = None,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "type": event_type,
        "workflow_id": workflow_id,
    }
    if detail:
        payload["detail"] = detail
    if status is not None:
        payload["status"] = status
        payload["current_step"] = status.get("current_step")
        payload["workflow_status"] = status.get("status")
    if event is not None:
        payload["event"] = event
    return payload


def _latest_stream_log(
    state: Mapping[str, Any],
    workflow_id: str,
    status: Mapping[str, Any],
) -> dict[str, Any] | None:
    events = [str(item).strip() for item in state.get("events") or [] if str(item).strip()]
    active_stage = str(status.get("current_step") or "")
    if status.get("status") == "running" and active_stage in WORKFLOW_ARTIFACTS:
        if not events or _stage_from_event_detail(events[-1], active_stage) != active_stage:
            return _stream_log_event(
                workflow_id,
                sequence=len(events) + 1,
                stage=active_stage,
                detail=prepare_event(active_stage),
            )
    if not events:
        return None
    detail = events[-1]
    stage = _stage_from_event_detail(detail, active_stage)
    return _stream_log_event(
        workflow_id,
        sequence=len(events),
        stage=stage,
        detail=detail,
    )


def _stream_log_event(
    workflow_id: str,
    *,
    sequence: int,
    stage: str,
    detail: str,
) -> dict[str, Any]:
    return {
        "id": f"{workflow_id}:stream:{sequence}",
        "sequence": sequence,
        "type": "log",
        "stage": stage,
        "title": "过程事件",
        "detail": detail[:2048],
        "status": _stream_log_status(detail),
        "artifact_id": None,
        "created_at_ms": _now_ms(),
    }


def _stage_from_event_detail(detail: str, fallback: str) -> str:
    prefix = detail.split(":", 1)[0].strip()
    if prefix in WORKFLOW_ARTIFACTS:
        return prefix
    return fallback or "workflow"


def _stream_log_status(detail: str) -> str:
    if "失败" in detail:
        return "failed"
    if "阻塞" in detail:
        return "blocked"
    if "补充" in detail:
        return "awaiting_user_input"
    if "准备" in detail or "正在" in detail or "重新执行" in detail:
        return "running"
    return "completed"


def _now_ms() -> int:
    return int(time.time() * 1000)


async def _resume_persistent_workflow_after_node(
    state: AutoDevWorkflowState,
    workflow_id: str,
    node: NodeName,
) -> dict[str, Any]:
    checkpoint_path = get_workflow_checkpoint_path()
    checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
    async with AsyncSqliteSaver.from_conn_string(str(checkpoint_path)) as checkpointer:
        graph = build_workflow_graph(checkpointer=checkpointer)
        config = workflow_config(workflow_id)
        await graph.aupdate_state(
            config,
            _prepare_node_state(state, _active_step_from_state(state)),
            as_node=node,
        )
        result = await graph.ainvoke(None, config=config)
    return build_workflow_status(dict(result or {}))


async def _skip_current_step(
    state: Mapping[str, Any],
    workflow_id: str,
) -> dict[str, Any]:
    stage = _action_stage(state)
    next_state = _reset_from_stage(state, stage)
    next_state[WORKFLOW_ARTIFACTS[stage]["state_key"]] = _skipped_artifact(stage, state)
    next_state["current_phase"] = WORKFLOW_NODE_COMPLETE_PHASE[stage]  # type: ignore[index]
    next_state["awaiting_user_input"] = False
    next_state["error"] = None
    next_state["events"] = append_event(next_state, f"{stage}: 已跳过")
    if stage == "summary":
        return await _save_workflow_state(next_state, workflow_id, "summary")
    return await _resume_persistent_workflow_after_node(next_state, workflow_id, stage)  # type: ignore[arg-type]


async def _rerun_current_step(
    state: Mapping[str, Any],
    workflow_id: str,
) -> dict[str, Any]:
    stage = _action_stage(state)
    next_state = _reset_from_stage(state, stage)
    next_state["awaiting_user_input"] = False
    next_state["error"] = None
    next_state["events"] = _events_without_stage(next_state, stage)
    next_state["events"] = append_event(next_state, f"{stage}: 重新执行")
    if stage == "chat":
        next_state["current_phase"] = ""
        return await _invoke_persistent_workflow(_prepare_node_state(next_state, "chat"), workflow_id)
    previous_node = WORKFLOW_PREVIOUS_NODE[stage]
    next_state["current_phase"] = WORKFLOW_NODE_COMPLETE_PHASE[previous_node]
    return await _resume_persistent_workflow_after_node(next_state, workflow_id, previous_node)


async def _save_workflow_state(
    state: AutoDevWorkflowState,
    workflow_id: str,
    node: NodeName,
) -> dict[str, Any]:
    checkpoint_path = get_workflow_checkpoint_path()
    checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
    async with AsyncSqliteSaver.from_conn_string(str(checkpoint_path)) as checkpointer:
        graph = build_workflow_graph(checkpointer=checkpointer)
        await graph.aupdate_state(workflow_config(workflow_id), dict(state), as_node=node)
    return build_workflow_status(state)


def _normalize_workflow_action(action: str) -> str:
    normalized = (action or "continue").strip().lower()
    if normalized in {"continue", "retry", "rerun", "skip"}:
        return normalized
    return "continue"


def _prepare_from_confirmed_feasibility(state: Mapping[str, Any]) -> AutoDevWorkflowState:
    next_state: AutoDevWorkflowState = dict(state)
    draft = dict(next_state.get("draft") or {})
    project_name = str(next_state.get("project_name") or draft.get("project_name") or "项目")
    feasibility_report = dict(next_state.get("feasibility_report") or draft)
    feasibility_report.setdefault("project_name", project_name)
    feasibility_report.setdefault("summary", draft.get("feasibility_conclusion") or "可行性报告已确认")
    next_state["project_name"] = project_name
    next_state["feasibility_report"] = feasibility_report
    next_state["current_phase"] = "report_complete"
    next_state["awaiting_user_input"] = False
    next_state["error"] = None
    next_state["events"] = append_event_once(next_state, "report: 可行性分析报告已确认")
    return next_state


def _action_stage(state: Mapping[str, Any]) -> NodeName:
    stage = _active_step_from_state(state)
    if stage in WORKFLOW_ARTIFACTS:
        return stage  # type: ignore[return-value]
    return "chat"


def _reset_from_stage(state: Mapping[str, Any], stage: str) -> AutoDevWorkflowState:
    next_state: AutoDevWorkflowState = dict(state)
    stage_index = WORKFLOW_ORDER.index(stage)
    for downstream in WORKFLOW_ORDER[stage_index:]:
        next_state.pop(WORKFLOW_ARTIFACTS[downstream]["state_key"], None)
    if stage_index <= WORKFLOW_ORDER.index("prd_review"):
        next_state.pop("prd_review_iteration", None)
    if stage_index <= WORKFLOW_ORDER.index("code_review"):
        next_state.pop("code_review_iteration", None)
    return next_state


def _skipped_artifact(stage: str, state: Mapping[str, Any]) -> dict[str, Any]:
    summary = f"{agent_title(stage)} Agent 已由用户跳过。"
    project_name = str(state.get("project_name") or "项目")
    base: dict[str, Any] = {
        "status": "skipped",
        "skipped": True,
        "summary": summary,
        "project_name": project_name,
    }
    if stage == "chat":
        return {"assistant_reply": summary, "report_patch": {}, **base}
    if stage in {"prd_review", "code_review"}:
        return {
            **base,
            "approved": True,
            "requires_user_input": False,
            "issues": [],
            "required_changes": [],
            "risks": [],
        }
    if stage == "coding":
        return {**base, "code_files": [], "notes": [summary]}
    if stage == "summary":
        return {
            **base,
            "final_phase": "workflow_complete",
            "project_id": state.get("project_id", ""),
        }
    return base


def _prepare_node_state(
    state: Mapping[str, Any] | None,
    fallback_stage: str,
) -> AutoDevWorkflowState:
    prepared: AutoDevWorkflowState = dict(state or {})
    stage = _active_step_from_state(prepared)
    if stage not in WORKFLOW_ARTIFACTS:
        stage = fallback_stage
    prepared["events"] = append_event_once(prepared, prepare_event(stage))
    return prepared


def _resume_node_from_completed_phase(state: Mapping[str, Any]) -> NodeName | None:
    current_phase = str(state.get("current_phase") or "").strip()
    if state.get("error") or state.get("awaiting_user_input"):
        return None
    if current_phase == "prd_review_revision_required":
        return "report"
    if current_phase == "code_review_revision_required":
        return "development"
    if not current_phase.endswith("_complete") or current_phase == "workflow_complete":
        return None
    node = _step_from_phase(current_phase)
    if node in WORKFLOW_ORDER:
        return node  # type: ignore[return-value]
    return None


def _retry_from_failed_phase(
    state: Mapping[str, Any],
) -> tuple[AutoDevWorkflowState, NodeName] | None:
    current_phase = str(state.get("current_phase") or "").strip()
    if current_phase.endswith("_failed"):
        failed_stage = current_phase.removesuffix("_failed")
    elif current_phase.endswith("_blocked"):
        failed_stage = current_phase.removesuffix("_blocked")
    else:
        return None
    previous_node = WORKFLOW_PREVIOUS_NODE.get(failed_stage)
    if previous_node is None:
        return None
    retry_state: AutoDevWorkflowState = dict(state)
    retry_state["error"] = None
    retry_state["awaiting_user_input"] = False
    retry_state["current_phase"] = WORKFLOW_NODE_COMPLETE_PHASE[previous_node]
    retry_state["events"] = _events_without_stage(retry_state, failed_stage)
    retry_state["events"] = append_event(retry_state, f"{failed_stage}: 重新执行")
    return retry_state, previous_node


def _events_without_stage(state: Mapping[str, Any], stage: str) -> list[str]:
    prefix = f"{stage}:"
    return [
        str(event)
        for event in state.get("events") or []
        if not str(event).strip().startswith(prefix)
    ]


def _event_error_message(detail: str) -> str:
    marker = "执行失败："
    if marker in detail:
        return detail.split(marker, 1)[1].strip()[:2048]
    return detail.strip()[:2048]


def _can_continue_from_awaiting_chat(state: Mapping[str, Any]) -> bool:
    current_phase = str(state.get("current_phase") or "")
    current_step = _step_from_phase(current_phase)
    if current_step != "chat" or current_phase != "awaiting_user_input":
        return False
    return _draft_ready_for_report(state.get("draft") or {})


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

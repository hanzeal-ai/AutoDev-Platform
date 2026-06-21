"""Unified AutoDev workflow graph with persistent checkpoint support."""

from __future__ import annotations

import json
import os
from collections.abc import Awaitable, Callable, Mapping
from pathlib import Path
from typing import Any, Literal, TypedDict

from langchain_core.messages import HumanMessage, SystemMessage
from langgraph.checkpoint.base import BaseCheckpointSaver
from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver
from langgraph.graph import END, START, StateGraph

from .config import ModelConfig
from .graphs.chat import generate_chat
from .graphs.coding import CodingState, build_coding_graph
from .graphs.development import DevState, build_development_graph
from .graphs.prd import PRDState, build_prd_graph
from .graphs.report import generate_report
from .json_tools import extract_json_fallback as _extract_json_fallback
from .llm import create_llm
from .models import (
    ChatContext,
    CodingContext,
    DevelopmentContext,
    PRDContext,
    ReportContext,
    WorkflowStartContext,
)
from .prompts import (
    CODE_REVIEW_SYSTEM,
    PRD_REVIEW_SYSTEM,
    code_review_user_prompt,
    prd_review_user_prompt,
)
from .retry import retry_async
from .text_tools import string_list as _string_list
from .tracing import build_trace_config


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


WorkflowNode = Callable[[AutoDevWorkflowState], Awaitable[dict[str, Any]]]
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

DEFAULT_MAX_PRD_REVIEW_ITERATIONS = 2
DEFAULT_MAX_CODE_REVIEW_ITERATIONS = 3

WORKFLOW_ARTIFACTS: dict[str, dict[str, str]] = {
    "chat": {
        "state_key": "chat_result",
        "name": "需求澄清结果",
        "kind": "workflow-chat",
    },
    "report": {
        "state_key": "feasibility_report",
        "name": "可行性分析报告",
        "kind": "workflow-report",
    },
    "prd": {
        "state_key": "prd_result",
        "name": "产品需求文档",
        "kind": "workflow-prd",
    },
    "prd_review": {
        "state_key": "prd_review_result",
        "name": "需求评审",
        "kind": "workflow-prd-review",
    },
    "development": {
        "state_key": "development_plan",
        "name": "研发计划",
        "kind": "workflow-development-plan",
    },
    "coding": {
        "state_key": "coding_result",
        "name": "代码生成结果",
        "kind": "workflow-coding",
    },
    "code_review": {
        "state_key": "code_review_result",
        "name": "代码评审",
        "kind": "workflow-code-review",
    },
    "summary": {
        "state_key": "workflow_summary",
        "name": "项目完成总结",
        "kind": "workflow-summary",
    },
}

WORKFLOW_ORDER = tuple(WORKFLOW_ARTIFACTS.keys())
WORKFLOW_PREVIOUS_NODE: dict[str, NodeName] = {
    "report": "chat",
    "prd": "report",
    "prd_review": "prd",
    "development": "prd_review",
    "coding": "development",
    "code_review": "coding",
    "summary": "code_review",
}
WORKFLOW_NODE_COMPLETE_PHASE: dict[NodeName, str] = {
    "chat": "chat_complete",
    "report": "report_complete",
    "prd": "prd_complete",
    "prd_review": "prd_review_complete",
    "development": "development_complete",
    "coding": "coding_complete",
    "code_review": "code_review_complete",
    "summary": "workflow_complete",
}


_prd_graph = build_prd_graph()
_development_graph = build_development_graph()
_coding_graph = build_coding_graph()


def workflow_config(workflow_id: str) -> dict[str, Any]:
    """Return the LangGraph config that scopes checkpoints to one workflow."""
    return {"configurable": {"thread_id": workflow_id}, "recursion_limit": 100}


def get_workflow_checkpoint_path() -> Path:
    configured = os.environ.get("AI_WORKFLOW_CHECKPOINT_PATH", "").strip()
    if configured:
        return Path(configured).expanduser()
    return Path(__file__).resolve().parents[1] / ".checkpoints" / "autodev_workflow.sqlite"


async def start_workflow(ctx: WorkflowStartContext) -> dict[str, Any]:
    workflow_id = ctx.workflow_id or ctx.thread_id
    state = ctx.model_dump()
    action = _normalize_workflow_action(str(state.pop("action", "continue")))
    state["workflow_id"] = workflow_id
    if action == "skip":
        return await _skip_current_step(state, workflow_id)
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


async def _get_checkpoint_state(workflow_id: str) -> dict[str, Any]:
    checkpoint_path = get_workflow_checkpoint_path()
    checkpoint_path.parent.mkdir(parents=True, exist_ok=True)
    async with AsyncSqliteSaver.from_conn_string(str(checkpoint_path)) as checkpointer:
        graph = build_workflow_graph(checkpointer=checkpointer)
        snapshot = await graph.aget_state(workflow_config(workflow_id))
    return dict(snapshot.values or {})


def build_workflow_status(state: Mapping[str, Any]) -> dict[str, Any]:
    """Return workflow progress metadata without embedding large artifact payloads."""
    workflow_id = str(state.get("workflow_id") or state.get("project_id") or "").strip()
    current_phase = str(state.get("current_phase") or "").strip()
    current_step = _active_step_from_state(state)
    error = state.get("error")
    awaiting_user_input = bool(state.get("awaiting_user_input"))
    status = _workflow_status(current_phase, error, awaiting_user_input)
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


def build_workflow_graph(
    *,
    checkpointer: BaseCheckpointSaver | None = None,
    node_overrides: Mapping[NodeName, WorkflowNode] | None = None,
):
    """Build the full workflow graph.

    The graph state intentionally excludes ModelConfig so API keys are not
    serialized into checkpoints.
    """
    overrides = dict(node_overrides or {})
    graph = StateGraph(AutoDevWorkflowState)
    graph.add_node("chat", overrides.get("chat", chat_node))
    graph.add_node("report", overrides.get("report", report_node))
    graph.add_node("prd", overrides.get("prd", prd_node))
    graph.add_node("prd_review", overrides.get("prd_review", prd_review_node))
    graph.add_node("development", overrides.get("development", development_node))
    graph.add_node("coding", overrides.get("coding", coding_node))
    graph.add_node("code_review", overrides.get("code_review", code_review_node))
    graph.add_node("summary", overrides.get("summary", summary_node))

    graph.add_edge(START, "chat")
    graph.add_conditional_edges(
        "chat",
        _route_after_chat,
        {
            "awaiting_user_input": END,
            "report": "report",
        },
    )
    graph.add_conditional_edges("report", _route_after_phase, {"stop": END, "continue": "prd"})
    graph.add_conditional_edges("prd", _route_after_phase, {"stop": END, "continue": "prd_review"})
    graph.add_conditional_edges(
        "prd_review",
        _route_after_prd_review,
        {
            "stop": END,
            "prd": "prd",
            "development": "development",
        },
    )
    graph.add_conditional_edges(
        "development",
        _route_after_phase,
        {"stop": END, "continue": "coding"},
    )
    graph.add_conditional_edges(
        "coding",
        _route_after_phase,
        {"stop": END, "continue": "code_review"},
    )
    graph.add_conditional_edges(
        "code_review",
        _route_after_code_review,
        {
            "stop": END,
            "coding": "coding",
            "summary": "summary",
        },
    )
    graph.add_edge("summary", END)
    return graph.compile(checkpointer=checkpointer)


async def chat_node(state: AutoDevWorkflowState) -> dict[str, Any]:
    async def run() -> dict[str, Any]:
        ctx = ChatContext(
            thread_id=_required(state, "thread_id"),
            user_message=_required(state, "user_message"),
            draft=state.get("draft", {}),
            messages=state.get("messages", []),
            materials=state.get("materials", []),
        )
        result = await generate_chat(ctx, ModelConfig.from_env())
        dumped = result.model_dump()
        patch = dumped.get("report_patch") or {}
        draft = _merge_report_patch(state.get("draft", {}), patch)
        project_name = _project_name(state, draft)
        awaiting_user_input = not bool(patch) and not _draft_ready_for_report(draft)
        return {
            "chat_result": dumped,
            "draft": draft,
            "project_name": project_name,
            "awaiting_user_input": awaiting_user_input,
            "current_phase": "awaiting_user_input" if awaiting_user_input else "chat_complete",
            "error": None,
            "events": _append_event(
                state,
                "chat: 需要用户补充需求信息" if awaiting_user_input else "chat: 需求澄清完成",
            ),
        }

    return await _with_node_errors(state, "chat", run)


async def report_node(state: AutoDevWorkflowState) -> dict[str, Any]:
    async def run() -> dict[str, Any]:
        ctx = ReportContext(
            thread_id=_required(state, "thread_id"),
            draft=state.get("draft", {}),
            messages=state.get("messages", []),
            materials=state.get("materials", []),
        )
        result = await generate_report(ctx, ModelConfig.from_env())
        dumped = result.model_dump()
        return {
            "feasibility_report": dumped,
            "project_name": _project_name(state, dumped),
            "current_phase": "report_complete",
            "error": None,
            "events": _append_event(state, "report: 可行性分析报告已生成"),
        }

    return await _with_node_errors(state, "report", run)


async def prd_node(state: AutoDevWorkflowState) -> dict[str, Any]:
    async def run() -> dict[str, Any]:
        cfg = ModelConfig.from_env()
        feasibility = dict(state.get("feasibility_report") or {})
        if _needs_revision(state.get("prd_review_result")):
            feasibility["prd_review_feedback"] = _review_feedback(state.get("prd_review_result", {}))
        ctx = PRDContext(
            project_id=_required(state, "project_id"),
            project_name=_project_name(state, state.get("feasibility_report", {})),
            feasibility=feasibility,
        )
        worker_state: PRDState = {
            "context": ctx,
            "config": cfg,
            "agent_reply": "",
            "deltas": [],
            "structured": {},
            "error": None,
        }
        result = _phase_result(
            await _prd_graph.ainvoke(worker_state),
            "prd_result",
            "prd_complete",
        )
        result["events"] = _append_event(state, "prd: 产品需求文档已生成")
        return result

    return await _with_node_errors(state, "prd", run)


async def prd_review_node(state: AutoDevWorkflowState) -> dict[str, Any]:
    async def run() -> dict[str, Any]:
        iteration = int(state.get("prd_review_iteration", 0)) + 1
        max_iterations = int(state.get("max_prd_review_iterations", DEFAULT_MAX_PRD_REVIEW_ITERATIONS))
        project_name = _project_name(state, state.get("prd_result", {}))
        ctx = PRDContext(
            project_id=_required(state, "project_id"),
            project_name=project_name,
            feasibility=state.get("feasibility_report"),
        )
        llm = create_llm(ModelConfig.from_env(), max_tokens=1600, json_mode=True)
        response = await retry_async(
            lambda: llm.ainvoke(
                [
                    SystemMessage(content=PRD_REVIEW_SYSTEM),
                    HumanMessage(
                        content=prd_review_user_prompt(
                            project_name,
                            json.dumps(state.get("feasibility_report", {}), ensure_ascii=False),
                            json.dumps(state.get("prd_result", {}), ensure_ascii=False),
                        )
                    ),
                ],
                config=build_trace_config(
                    "prd_review",
                    "prd_review",
                    ctx,
                    prompt_keys=["prd_review.system", "prd_review.user"],
                ),
            )
        )
        review = _parse_review_response(response.content, default_summary="PRD 评审完成")
        phase = _review_phase(
            review,
            iteration=iteration,
            max_iterations=max_iterations,
            passed_phase="prd_review_complete",
            revision_phase="prd_review_revision_required",
            blocked_phase="prd_review_blocked",
        )
        return {
            "prd_review_iteration": iteration,
            "max_prd_review_iterations": max_iterations,
            "prd_review_result": review,
            "awaiting_user_input": bool(review.get("requires_user_input")),
            "current_phase": phase,
            "error": None,
            "events": _append_event(
                state,
                f"prd_review: 第 {iteration} 轮需求评审{_review_event_suffix(review, phase)}",
            ),
        }

    return await _with_node_errors(state, "prd_review", run)


async def development_node(state: AutoDevWorkflowState) -> dict[str, Any]:
    async def run() -> dict[str, Any]:
        cfg = ModelConfig.from_env()
        ctx = DevelopmentContext(
            project_id=_required(state, "project_id"),
            project_name=_project_name(state, state.get("feasibility_report", {})),
            prd=state.get("prd_result"),
            feasibility=state.get("feasibility_report"),
        )
        worker_state: DevState = {
            "context": ctx,
            "config": cfg,
            "architect_reply": "",
            "deltas": [],
            "structured": {},
            "error": None,
        }
        result = _phase_result(
            await _development_graph.ainvoke(worker_state),
            "development_plan",
            "development_complete",
        )
        result["events"] = _append_event(state, "development: 研发计划已生成")
        return result

    return await _with_node_errors(state, "development", run)


async def coding_node(state: AutoDevWorkflowState) -> dict[str, Any]:
    async def run() -> dict[str, Any]:
        cfg = ModelConfig.from_env()
        task_breakdown = dict(state.get("development_plan") or {})
        task_breakdown["prd"] = state.get("prd_result") or {}
        task_breakdown["ui_requirements"] = (
            state.get("ui_requirements")
            or (state.get("draft") or {}).get("ui_requirements")
            or (state.get("prd_result") or {}).get("ui_requirements")
            or {}
        )
        if _needs_revision(state.get("code_review_result")):
            task_breakdown["code_review_feedback"] = _review_feedback(
                state.get("code_review_result", {})
            )
            task_breakdown["previous_coding_summary"] = str(
                (state.get("coding_result") or {}).get("summary", "")
            )[:1000]
        ctx = CodingContext(
            project_id=_required(state, "project_id"),
            project_name=_project_name(state, state.get("feasibility_report", {})),
            task_breakdown=task_breakdown,
        )
        worker_state: CodingState = {
            "context": ctx,
            "config": cfg,
            "coding_plan": [],
            "coding_reply": "",
            "deltas": [],
            "structured": {},
            "error": None,
        }
        worker_result = await _coding_graph.ainvoke(worker_state)
        result = _phase_result(
            worker_result,
            "coding_result",
            "coding_complete",
        )
        events = list(state.get("events") or [])
        for event in worker_result.get("deltas") or []:
            if isinstance(event, str) and event.strip():
                events.append(event.strip())
        events.append("coding: 代码生成阶段已完成")
        result["events"] = events
        return result

    return await _with_node_errors(state, "coding", run)


async def code_review_node(state: AutoDevWorkflowState) -> dict[str, Any]:
    async def run() -> dict[str, Any]:
        iteration = int(state.get("code_review_iteration", 0)) + 1
        max_iterations = int(
            state.get("max_code_review_iterations", DEFAULT_MAX_CODE_REVIEW_ITERATIONS)
        )
        project_name = _project_name(state, state.get("prd_result", {}))
        ctx = CodingContext(
            project_id=_required(state, "project_id"),
            project_name=project_name,
            task_breakdown=state.get("development_plan", {}),
        )
        llm = create_llm(ModelConfig.from_env(), max_tokens=1800, json_mode=True)
        response = await retry_async(
            lambda: llm.ainvoke(
                [
                    SystemMessage(content=CODE_REVIEW_SYSTEM),
                    HumanMessage(
                        content=code_review_user_prompt(
                            project_name,
                            json.dumps(state.get("prd_result", {}), ensure_ascii=False),
                            json.dumps(state.get("development_plan", {}), ensure_ascii=False),
                            json.dumps(state.get("coding_result", {}), ensure_ascii=False),
                        )
                    ),
                ],
                config=build_trace_config(
                    "code_review",
                    "code_review",
                    ctx,
                    prompt_keys=["code_review.system", "code_review.user"],
                ),
            )
        )
        review = _parse_review_response(response.content, default_summary="代码评审完成")
        phase = _review_phase(
            review,
            iteration=iteration,
            max_iterations=max_iterations,
            passed_phase="code_review_complete",
            revision_phase="code_review_revision_required",
            blocked_phase="code_review_blocked",
        )
        return {
            "code_review_iteration": iteration,
            "max_code_review_iterations": max_iterations,
            "code_review_result": review,
            "awaiting_user_input": bool(review.get("requires_user_input")),
            "current_phase": phase,
            "error": None,
            "events": _append_event(
                state,
                f"code_review: 第 {iteration} 轮代码评审{_review_event_suffix(review, phase)}",
            ),
        }

    return await _with_node_errors(state, "code_review", run)


async def summary_node(state: AutoDevWorkflowState) -> dict[str, Any]:
    code_review = state.get("code_review_result") or {}
    summary = {
        "status": "completed" if bool(code_review.get("approved")) else "incomplete",
        "project_id": state.get("project_id", ""),
        "project_name": state.get("project_name", ""),
        "prd_review_iterations": int(state.get("prd_review_iteration", 0)),
        "code_review_iterations": int(state.get("code_review_iteration", 0)),
        "final_phase": "workflow_complete",
        "prd_review_summary": (state.get("prd_review_result") or {}).get("summary", ""),
        "code_review_summary": code_review.get("summary", ""),
    }
    return {
        "workflow_summary": summary,
        "current_phase": "workflow_complete",
        "awaiting_user_input": False,
        "error": None,
        "events": _append_event(state, "summary: Workflow 完成总结已生成"),
    }


def _route_after_chat(state: AutoDevWorkflowState) -> str:
    if state.get("awaiting_user_input"):
        return "awaiting_user_input"
    return "report"


def _route_after_phase(state: AutoDevWorkflowState) -> str:
    if state.get("error"):
        return "stop"
    return "continue"


def _route_after_prd_review(state: AutoDevWorkflowState) -> str:
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


def _route_after_code_review(state: AutoDevWorkflowState) -> str:
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
    started_events = _append_event_once(state, _prepare_event(stage))
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


def _agent_title(stage: str) -> str:
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
    next_state["events"] = _append_event(next_state, f"{stage}: 已跳过")
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
    next_state["events"] = _append_event(next_state, f"{stage}: 重新执行")
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
    summary = f"{_agent_title(stage)} Agent 已由用户跳过。"
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
    prepared["events"] = _append_event_once(prepared, _prepare_event(stage))
    return prepared


def _prepare_event(stage: str) -> str:
    return f"{stage}: 准备执行{_agent_title(stage)} Agent"


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
        "events": _append_event(state, f"{stage}: 执行失败：{message}"),
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


def _phase_status(state: Mapping[str, Any], workflow_id: str, stage: str) -> dict[str, Any]:
    spec = WORKFLOW_ARTIFACTS[stage]
    current_step = _active_step_from_state(state)
    has_artifact = bool(state.get(spec["state_key"]))
    if _stage_is_stale_after_revision(state, stage, current_step):
        has_artifact = False
    status = "completed" if has_artifact else "pending"
    if current_step == stage and _workflow_status(
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
    if _needs_revision(state.get("prd_review_result")) and current_step == "prd":
        return stage_index > current_index
    if _needs_revision(state.get("code_review_result")) and current_step == "coding":
        return stage_index > current_index
    return False


def _phase_name(state: Mapping[str, Any], stage: str, fallback: str) -> str:
    if stage == "coding":
        return f"第 {_coding_round(state)} 轮代码开发"
    if stage == "code_review":
        return f"第 {_code_review_round(state)} 轮代码评审"
    return fallback


def _coding_round(state: Mapping[str, Any]) -> int:
    return max(1, int(state.get("code_review_iteration") or 0) + 1)


def _code_review_round(state: Mapping[str, Any]) -> int:
    completed_reviews = int(state.get("code_review_iteration") or 0)
    if _active_step_from_state(state) == "code_review" and not state.get("code_review_result"):
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


def _workflow_status(
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


def _active_step_from_state(state: Mapping[str, Any]) -> str:
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
        return _step_from_phase(current_phase)

    if current_phase == "prd_review_revision_required":
        return "prd"
    if current_phase == "code_review_revision_required":
        return "coding"
    phase_step = _step_from_phase(current_phase)
    if current_phase.endswith("_complete") and phase_step in WORKFLOW_ORDER:
        phase_index = WORKFLOW_ORDER.index(phase_step)
        for stage in WORKFLOW_ORDER[phase_index + 1 :]:
            spec = WORKFLOW_ARTIFACTS[stage]
            artifact = state.get(spec["state_key"])
            if not artifact:
                return stage
            if stage == "prd_review" and _needs_revision(artifact):
                return "prd"
            if stage == "code_review" and _needs_revision(artifact):
                return "coding"
        return "summary"

    for stage in WORKFLOW_ORDER:
        spec = WORKFLOW_ARTIFACTS[stage]
        artifact = state.get(spec["state_key"])
        if not artifact:
            return stage
        if stage == "prd_review" and _needs_revision(artifact):
            return "prd"
        if stage == "code_review" and _needs_revision(artifact):
            return "coding"
    return "summary"


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
    retry_state["events"] = _append_event(retry_state, f"{failed_stage}: 重新执行")
    return retry_state, previous_node


def _step_from_phase(current_phase: str) -> str:
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


def _needs_revision(review: dict[str, Any] | None) -> bool:
    return bool(review) and not bool((review or {}).get("approved"))


def _append_event(state: Mapping[str, Any], detail: str) -> list[str]:
    events = list(state.get("events") or [])
    events.append(detail)
    return events


def _append_event_once(state: Mapping[str, Any], detail: str) -> list[str]:
    events = list(state.get("events") or [])
    if not events or events[-1] != detail:
        events.append(detail)
    return events


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


def _project_name(state: AutoDevWorkflowState, candidate: dict[str, Any]) -> str:
    value = str(candidate.get("project_name") or state.get("project_name") or "").strip()
    return value or "AutoDev 项目"


def _required(state: AutoDevWorkflowState, field: str) -> str:
    value = str(state.get(field, "")).strip()
    if not value:
        raise ValueError(f"workflow state missing required field: {field}")
    return value

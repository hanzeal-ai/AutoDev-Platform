"""Unified AutoDev workflow graph with persistent checkpoint support."""

from __future__ import annotations

import os
from collections.abc import Awaitable, Callable, Mapping
from pathlib import Path
from typing import Any, Literal, TypedDict

from langgraph.checkpoint.base import BaseCheckpointSaver
from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver
from langgraph.graph import END, START, StateGraph

from .config import ModelConfig
from .graphs.chat import generate_chat
from .graphs.coding import CodingState, build_coding_graph
from .graphs.development import DevState, build_development_graph
from .graphs.prd import PRDState, build_prd_graph
from .graphs.report import generate_report
from .models import (
    ChatContext,
    CodingContext,
    DevelopmentContext,
    PRDContext,
    ReportContext,
    WorkflowStartContext,
)


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
    development_plan: dict[str, Any]
    coding_result: dict[str, Any]
    events: list[str]


WorkflowNode = Callable[[AutoDevWorkflowState], Awaitable[dict[str, Any]]]
NodeName = Literal["chat", "report", "prd", "development", "coding"]


_prd_graph = build_prd_graph()
_development_graph = build_development_graph()
_coding_graph = build_coding_graph()


def workflow_config(workflow_id: str) -> dict[str, Any]:
    """Return the LangGraph config that scopes checkpoints to one workflow."""
    return {"configurable": {"thread_id": workflow_id}}


def get_workflow_checkpoint_path() -> Path:
    configured = os.environ.get("AI_WORKFLOW_CHECKPOINT_PATH", "").strip()
    if configured:
        return Path(configured).expanduser()
    return Path(__file__).resolve().parents[1] / ".checkpoints" / "autodev_workflow.sqlite"


async def start_workflow(ctx: WorkflowStartContext) -> dict[str, Any]:
    workflow_id = ctx.workflow_id or ctx.thread_id
    state = ctx.model_dump()
    state["workflow_id"] = workflow_id
    return await _invoke_persistent_workflow(state, workflow_id)


async def resume_workflow(workflow_id: str) -> dict[str, Any]:
    return await _invoke_persistent_workflow(None, workflow_id)


async def get_workflow_status(workflow_id: str) -> dict[str, Any]:
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
    return dict(result or {})


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
    graph.add_node("development", overrides.get("development", development_node))
    graph.add_node("coding", overrides.get("coding", coding_node))

    graph.add_edge(START, "chat")
    graph.add_conditional_edges(
        "chat",
        _route_after_chat,
        {
            "awaiting_user_input": END,
            "report": "report",
        },
    )
    graph.add_edge("report", "prd")
    graph.add_conditional_edges("prd", _route_after_phase, {"stop": END, "continue": "development"})
    graph.add_conditional_edges(
        "development",
        _route_after_phase,
        {"stop": END, "continue": "coding"},
    )
    graph.add_edge("coding", END)
    return graph.compile(checkpointer=checkpointer)


async def chat_node(state: AutoDevWorkflowState) -> dict[str, Any]:
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
    return {
        "chat_result": dumped,
        "draft": draft,
        "project_name": project_name,
        "awaiting_user_input": not bool(patch),
        "current_phase": "awaiting_user_input" if not patch else "chat_complete",
        "error": None,
    }


async def report_node(state: AutoDevWorkflowState) -> dict[str, Any]:
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
    }


async def prd_node(state: AutoDevWorkflowState) -> dict[str, Any]:
    cfg = ModelConfig.from_env()
    ctx = PRDContext(
        project_id=_required(state, "project_id"),
        project_name=_project_name(state, state.get("feasibility_report", {})),
        feasibility=state.get("feasibility_report"),
    )
    worker_state: PRDState = {
        "context": ctx,
        "config": cfg,
        "agent_reply": "",
        "deltas": [],
        "structured": {},
        "error": None,
    }
    return _phase_result(
        await _prd_graph.ainvoke(worker_state),
        "prd_result",
        "prd_complete",
    )


async def development_node(state: AutoDevWorkflowState) -> dict[str, Any]:
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
    return _phase_result(
        await _development_graph.ainvoke(worker_state),
        "development_plan",
        "development_complete",
    )


async def coding_node(state: AutoDevWorkflowState) -> dict[str, Any]:
    cfg = ModelConfig.from_env()
    ctx = CodingContext(
        project_id=_required(state, "project_id"),
        project_name=_project_name(state, state.get("feasibility_report", {})),
        task_breakdown=state.get("development_plan", {}),
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
    return _phase_result(
        await _coding_graph.ainvoke(worker_state),
        "coding_result",
        "coding_complete",
    )


def _route_after_chat(state: AutoDevWorkflowState) -> str:
    if state.get("awaiting_user_input"):
        return "awaiting_user_input"
    return "report"


def _route_after_phase(state: AutoDevWorkflowState) -> str:
    if state.get("error"):
        return "stop"
    return "continue"


def _phase_result(worker_state: dict[str, Any], result_key: str, phase: str) -> dict[str, Any]:
    if worker_state.get("error"):
        return {"error": str(worker_state["error"]), "current_phase": f"{phase}_failed"}
    result = worker_state.get("result")
    if result is None:
        return {"error": f"{phase} completed without result", "current_phase": f"{phase}_failed"}
    if hasattr(result, "model_dump"):
        result = result.model_dump()
    return {result_key: result, "current_phase": phase, "error": None}


def _merge_report_patch(draft: dict[str, Any], patch: dict[str, Any]) -> dict[str, Any]:
    merged = dict(draft)
    for key, value in patch.items():
        if value not in ("", None, []):
            merged[key] = value
    return merged


def _project_name(state: AutoDevWorkflowState, candidate: dict[str, Any]) -> str:
    value = str(candidate.get("project_name") or state.get("project_name") or "").strip()
    return value or "AutoDev 项目"


def _required(state: AutoDevWorkflowState, field: str) -> str:
    value = str(state.get(field, "")).strip()
    if not value:
        raise ValueError(f"workflow state missing required field: {field}")
    return value

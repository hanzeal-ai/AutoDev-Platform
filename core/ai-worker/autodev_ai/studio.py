"""LangGraph Studio entrypoint.

These graphs are intentionally separate from the FastAPI worker in main.py.
They adapt Studio inputs into the existing worker contexts and reuse the same
generation code, while loading ModelConfig from .env internally.
"""

from __future__ import annotations

from typing import Any, TypedDict

from langgraph.graph import END, START, StateGraph

from .config import ModelConfig
from .graphs.chat import generate_chat
from .graphs.coding import CodingState, build_coding_graph
from .graphs.development import DevState, build_development_graph
from .graphs.prd import PRDState, build_prd_graph
from .graphs.report import generate_report
from .graphs.stage import StageState, build_stage_graph
from .models import (
    ChatContext,
    CodingContext,
    DevelopmentContext,
    PRDContext,
    ReportContext,
    StageContext,
)
from .workflow import build_workflow_graph


class StudioState(TypedDict, total=False):
    """Studio-facing state. Input shape: {"context": {...}}."""

    context: dict[str, Any]
    result: dict[str, Any]
    error: str | None


_stage_worker_graph = build_stage_graph()
_prd_worker_graph = build_prd_graph()
_development_worker_graph = build_development_graph()
_coding_worker_graph = build_coding_graph()


async def _chat_node(state: StudioState) -> dict[str, Any]:
    ctx = ChatContext(**state.get("context", {}))
    result = await generate_chat(ctx, ModelConfig.from_env())
    return {"result": result.model_dump(), "error": None}


async def _report_node(state: StudioState) -> dict[str, Any]:
    ctx = ReportContext(**state.get("context", {}))
    result = await generate_report(ctx, ModelConfig.from_env())
    return {"result": result.model_dump(), "error": None}


async def _stage_node(state: StudioState) -> dict[str, Any]:
    ctx = StageContext(**state.get("context", {}))
    worker_state: StageState = {
        "context": ctx,
        "config": ModelConfig.from_env(),
        "agent_reply": "",
        "deltas": [],
        "structured": {},
        "error": None,
    }
    return _dump_worker_result(await _stage_worker_graph.ainvoke(worker_state))


async def _prd_node(state: StudioState) -> dict[str, Any]:
    ctx = PRDContext(**state.get("context", {}))
    worker_state: PRDState = {
        "context": ctx,
        "config": ModelConfig.from_env(),
        "agent_reply": "",
        "deltas": [],
        "structured": {},
        "error": None,
    }
    return _dump_worker_result(await _prd_worker_graph.ainvoke(worker_state))


async def _development_node(state: StudioState) -> dict[str, Any]:
    ctx = DevelopmentContext(**state.get("context", {}))
    worker_state: DevState = {
        "context": ctx,
        "config": ModelConfig.from_env(),
        "architect_reply": "",
        "deltas": [],
        "structured": {},
        "error": None,
    }
    return _dump_worker_result(await _development_worker_graph.ainvoke(worker_state))


async def _coding_node(state: StudioState) -> dict[str, Any]:
    ctx = CodingContext(**state.get("context", {}))
    worker_state: CodingState = {
        "context": ctx,
        "config": ModelConfig.from_env(),
        "coding_plan": [],
        "coding_reply": "",
        "deltas": [],
        "structured": {},
        "error": None,
    }
    return _dump_worker_result(await _coding_worker_graph.ainvoke(worker_state))


def _dump_worker_result(state: dict[str, Any]) -> dict[str, Any]:
    if state.get("error"):
        return {"error": str(state["error"])}
    result = state.get("result")
    if result is None:
        return {"error": "Studio graph completed without a result"}
    if hasattr(result, "model_dump"):
        return {"result": result.model_dump(), "error": None}
    return {"result": result, "error": None}


def _single_node_graph(node_name: str, node) -> Any:
    graph = StateGraph(StudioState)
    graph.add_node(node_name, node)
    graph.add_edge(START, node_name)
    graph.add_edge(node_name, END)
    return graph.compile()


chat_graph = _single_node_graph("chat", _chat_node)
report_graph = _single_node_graph("report", _report_node)
stage_graph = _single_node_graph("stage", _stage_node)
prd_graph = _single_node_graph("prd", _prd_node)
development_graph = _single_node_graph("development", _development_node)
coding_graph = _single_node_graph("coding", _coding_node)
workflow_graph = build_workflow_graph()

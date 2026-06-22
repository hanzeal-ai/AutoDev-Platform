"""Unified AutoDev workflow graph assembly."""

from __future__ import annotations

from collections.abc import Mapping

from langgraph.checkpoint.base import BaseCheckpointSaver
from langgraph.graph import END, START, StateGraph

from ...workflow_runtime.types import AutoDevWorkflowState, NodeName, WorkflowNode
from .nodes import (
    chat_node,
    code_review_node,
    coding_node,
    development_node,
    prd_node,
    prd_review_node,
    report_node,
    summary_node,
)
from .routing import (
    route_after_chat,
    route_after_code_review,
    route_after_phase,
    route_after_prd_review,
)


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
        route_after_chat,
        {
            "awaiting_user_input": END,
            "report": "report",
        },
    )
    graph.add_conditional_edges("report", route_after_phase, {"stop": END, "continue": "prd"})
    graph.add_conditional_edges("prd", route_after_phase, {"stop": END, "continue": "prd_review"})
    graph.add_conditional_edges(
        "prd_review",
        route_after_prd_review,
        {
            "stop": END,
            "prd": "prd",
            "development": "development",
        },
    )
    graph.add_conditional_edges(
        "development",
        route_after_phase,
        {"stop": END, "continue": "coding"},
    )
    graph.add_conditional_edges(
        "coding",
        route_after_phase,
        {"stop": END, "continue": "code_review"},
    )
    graph.add_conditional_edges(
        "code_review",
        route_after_code_review,
        {
            "stop": END,
            "coding": "coding",
            "summary": "summary",
        },
    )
    graph.add_edge("summary", END)
    return graph.compile(checkpointer=checkpointer)

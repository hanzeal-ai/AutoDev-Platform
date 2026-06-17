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
    return build_workflow_status(await _get_checkpoint_state(workflow_id))


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
    current_step = _step_from_phase(current_phase)
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
    graph.add_edge("report", "prd")
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
    return _phase_result(
        await _prd_graph.ainvoke(worker_state),
        "prd_result",
        "prd_complete",
    )


async def prd_review_node(state: AutoDevWorkflowState) -> dict[str, Any]:
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
    }


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
    task_breakdown = dict(state.get("development_plan") or {})
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
    return _phase_result(
        await _coding_graph.ainvoke(worker_state),
        "coding_result",
        "coding_complete",
    )


async def code_review_node(state: AutoDevWorkflowState) -> dict[str, Any]:
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
    }


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


def _phase_status(state: Mapping[str, Any], workflow_id: str, stage: str) -> dict[str, Any]:
    spec = WORKFLOW_ARTIFACTS[stage]
    has_artifact = bool(state.get(spec["state_key"]))
    current_step = _step_from_phase(str(state.get("current_phase") or ""))
    status = "completed" if has_artifact else "pending"
    if current_step == stage and not has_artifact:
        status = "running"
    if current_step == stage and state.get("error"):
        status = "failed"
    artifact_id = f"{workflow_id}:{stage}" if workflow_id and has_artifact else None
    return {
        "status": status,
        "artifact_id": artifact_id,
        "name": spec["name"],
        "kind": spec["kind"],
    }


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


def _project_name(state: AutoDevWorkflowState, candidate: dict[str, Any]) -> str:
    value = str(candidate.get("project_name") or state.get("project_name") or "").strip()
    return value or "AutoDev 项目"


def _required(state: AutoDevWorkflowState, field: str) -> str:
    value = str(state.get(field, "")).strip()
    if not value:
        raise ValueError(f"workflow state missing required field: {field}")
    return value


def _string_list(raw, limit: int, max_len: int) -> list[str]:
    if not isinstance(raw, list):
        return []
    result: list[str] = []
    for item in raw[:limit]:
        value = str(item).strip()[:max_len]
        if value:
            result.append(value)
    return result


def _extract_json_fallback(raw: str) -> dict[str, Any] | None:
    import re

    raw = raw[:65536]
    match = re.search(r"```(?:json)?[ \t]*\n(.+?)\n[ \t]*```", raw, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(1))
        except json.JSONDecodeError:
            pass

    start = raw.find("{")
    if start < 0:
        return None
    depth = 0
    for idx, char in enumerate(raw[start:], start):
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(raw[start : idx + 1])
                except json.JSONDecodeError:
                    return None
    return None

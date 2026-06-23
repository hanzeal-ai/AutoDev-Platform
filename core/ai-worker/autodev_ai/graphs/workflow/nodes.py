"""Workflow graph node implementations."""

from __future__ import annotations

import json
from typing import Any

from langchain_core.messages import HumanMessage, SystemMessage

from ...config import ModelConfig
from ...llm import create_llm
from ...models import ChatContext, CodingContext, DevelopmentContext, PRDContext, ReportContext
from ...prompts import (
    CODE_REVIEW_SYSTEM,
    PRD_REVIEW_SYSTEM,
    code_review_user_prompt,
    prd_review_user_prompt,
)
from ...retry import retry_async
from ...tracing import build_trace_config
from ...workflow_runtime.events import append_event
from ...workflow_runtime.progress import needs_revision as _needs_revision
from ...workflow_runtime.schema import (
    DEFAULT_MAX_CODE_REVIEW_ITERATIONS,
    DEFAULT_MAX_PRD_REVIEW_ITERATIONS,
)
from ...workflow_runtime.types import AutoDevWorkflowState
from ..chat import generate_chat
from ..coding import CodingState, build_coding_graph
from ..development import DevState, build_development_graph
from ..prd import PRDState, build_prd_graph
from ..report import generate_report
from .helpers import (
    _draft_ready_for_report,
    _merge_report_patch,
    _parse_review_response,
    _phase_result,
    _project_name,
    _required,
    _review_event_suffix,
    _review_feedback,
    _review_phase,
    _with_node_errors,
)


_prd_graph = build_prd_graph()
_development_graph = build_development_graph()
_coding_graph = build_coding_graph()


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
            "events": append_event(
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
            "events": append_event(state, "report: 可行性分析报告已生成"),
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
        result["events"] = append_event(state, "prd: 产品需求文档已生成")
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
            "events": append_event(
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
        result["events"] = append_event(state, "development: 研发计划已生成")
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
            project_workspace=_coding_workspace(state),
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
            project_workspace=_coding_workspace(state),
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
            "events": append_event(
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
        "events": append_event(state, "summary: Workflow 完成总结已生成"),
    }


def _coding_workspace(state: AutoDevWorkflowState) -> str:
    workspace = str(state.get("project_workspace") or state.get("workspace_path") or "").strip()
    if workspace:
        return workspace
    return str(state.get("project_id") or "").strip()

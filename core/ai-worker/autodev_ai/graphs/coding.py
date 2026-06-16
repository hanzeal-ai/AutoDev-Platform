"""LangGraph coding generation workflow (development sub-step 2).

Graph topology:
    planner_node ──▶ coding_agent_node (streaming) ──▶ synthesizer_node ──▶ normalizer_node

Produces a structured CodingResult with implementation code files.
"""

from __future__ import annotations

import json
import logging
from typing import TypedDict

from langchain_core.messages import HumanMessage, SystemMessage
from langgraph.graph import StateGraph, START, END

from ..config import ModelConfig
from ..llm import create_llm
from ..retry import retry_async
from ..models import CodingContext, CodingResult, CodeFile
from ..prompts import (
    coding_planner_system_prompt,
    coding_planner_user_prompt,
    coding_agent_system_prompt,
    coding_agent_user_prompt,
    CODING_SYNTHESIZER_SYSTEM,
    coding_synthesizer_user_prompt,
)
from ..tracing import build_trace_config

logger = logging.getLogger(__name__)

MAX_CODE_FILES = 30

class CodingState(TypedDict, total=False):
    context: CodingContext
    config: ModelConfig
    coding_plan: list[dict]
    coding_reply: str
    deltas: list[str]
    structured: dict
    result: CodingResult
    error: str | None


async def planner_node(state: CodingState) -> dict:
    """Stage 1: planning — creates ordered coding tasks before implementation."""
    ctx = state["context"]
    cfg = state["config"]

    task_breakdown_text = json.dumps(ctx.task_breakdown, ensure_ascii=False)
    llm = create_llm(cfg, max_tokens=1800, json_mode=True)

    messages = [
        SystemMessage(content=coding_planner_system_prompt()),
        HumanMessage(content=coding_planner_user_prompt(ctx.project_name, task_breakdown_text)),
    ]

    response = await retry_async(
        lambda: llm.ainvoke(
            messages,
            config=build_trace_config(
                "coding_planner",
                "coding",
                ctx,
                prompt_keys=["coding.planner.system", "coding.planner.user"],
            ),
        )
    )
    raw_text = response.content

    try:
        raw = json.loads(raw_text)
    except json.JSONDecodeError:
        raw = _extract_json_fallback(raw_text) or {}

    return {"coding_plan": _normalize_coding_plan(raw)}


async def coding_agent_node(state: CodingState) -> dict:
    """Stage 2: streaming coding agent — produces implementation narrative."""
    ctx = state["context"]
    cfg = state["config"]

    llm = create_llm(cfg, max_tokens=4000, streaming=True)

    task_breakdown_text = json.dumps(ctx.task_breakdown, ensure_ascii=False)
    coding_plan_text = json.dumps(state.get("coding_plan", []), ensure_ascii=False)

    messages = [
        SystemMessage(content=coding_agent_system_prompt()),
        HumanMessage(content=coding_agent_user_prompt(
            ctx.project_name, task_breakdown_text, coding_plan_text,
        )),
    ]

    full_reply = ""
    deltas: list[str] = []

    async def _stream():
        nonlocal full_reply, deltas
        full_reply = ""
        deltas = []
        async for chunk in llm.astream(
            messages,
            config=build_trace_config(
                "coding_agent",
                "coding",
                ctx,
                prompt_keys=["coding.agent.system", "coding.agent.user"],
            ),
        ):
            delta = chunk.content
            if delta:
                full_reply += delta
                deltas.append(delta)

    await retry_async(_stream)

    if not full_reply.strip():
        return {"error": "编码 Agent 返回空内容", "coding_reply": "", "deltas": deltas}

    return {"coding_reply": full_reply, "deltas": deltas}


async def synthesizer_node(state: CodingState) -> dict:
    """Stage 3: synthesizer — converts coding narrative to structured JSON."""
    ctx = state["context"]
    cfg = state["config"]
    coding_reply = state.get("coding_reply", "")

    if not coding_reply:
        return {"error": "无编码 Agent 回复，跳过结构化"}

    task_breakdown_text = json.dumps(ctx.task_breakdown, ensure_ascii=False)

    llm = create_llm(cfg, max_tokens=4000, json_mode=True)

    messages = [
        SystemMessage(content=CODING_SYNTHESIZER_SYSTEM),
        HumanMessage(content=coding_synthesizer_user_prompt(
            ctx.project_name, task_breakdown_text, coding_reply,
        )),
    ]

    response = await retry_async(
        lambda: llm.ainvoke(
            messages,
            config=build_trace_config(
                "coding_synthesizer",
                "coding",
                ctx,
                prompt_keys=["coding.synthesizer.system", "coding.synthesizer.user"],
            ),
        )
    )
    raw_text = response.content

    try:
        structured = json.loads(raw_text)
    except json.JSONDecodeError:
        structured = _extract_json_fallback(raw_text)
        if structured is None:
            return {"error": f"无法解析代码 JSON: {raw_text[:200]}"}

    return {"structured": structured}


async def normalizer_node(state: CodingState) -> dict:
    """Stage 4: normalize and validate the coding result."""
    raw = state.get("structured", {})

    if not raw:
        return {"error": "无代码结构化数据可规范化"}

    code_files = []
    for cf in raw.get("code_files", [])[:MAX_CODE_FILES]:
        if not isinstance(cf, dict):
            continue
        fpath = cf.get("path", "").strip()
        if not fpath:
            continue
        code_files.append(CodeFile(
            path=fpath[:512],
            content=cf.get("content", "")[:65536],
            language=cf.get("language", "")[:32],
            module_id=cf.get("module_id", "")[:64],
            purpose=cf.get("purpose", "")[:256],
        ))

    result = CodingResult(
        summary=raw.get("summary", "")[:4096],
        code_files=code_files,
    )

    return {"result": result}


def build_coding_graph() -> StateGraph:
    graph = StateGraph(CodingState)
    graph.add_node("planner", planner_node)
    graph.add_node("coding_agent", coding_agent_node)
    graph.add_node("synthesizer", synthesizer_node)
    graph.add_node("normalizer", normalizer_node)

    graph.add_edge(START, "planner")
    graph.add_edge("planner", "coding_agent")
    graph.add_edge("coding_agent", "synthesizer")
    graph.add_edge("synthesizer", "normalizer")
    graph.add_edge("normalizer", END)

    return graph.compile()


def _normalize_coding_plan(raw: dict) -> list[dict]:
    tasks = raw.get("tasks") if isinstance(raw, dict) else None
    if not isinstance(tasks, list):
        return [_fallback_coding_task()]

    normalized: list[dict] = []
    seen_ids: set[str] = set()
    for index, task in enumerate(tasks[:20], 1):
        if not isinstance(task, dict):
            continue
        task_id = str(task.get("id", "")).strip()[:64] or f"task-{index}"
        title = str(task.get("title", "")).strip()[:256]
        if not title or task_id in seen_ids:
            continue
        seen_ids.add(task_id)
        normalized.append({
            "id": task_id,
            "title": title,
            "module_id": str(task.get("module_id", "")).strip()[:64],
            "depends_on": _string_list(task.get("depends_on"), 12, 64),
            "target_files": _string_list(task.get("target_files"), 20, 512),
            "acceptance_checks": _string_list(task.get("acceptance_checks"), 8, 256),
            "implementation_notes": str(task.get("implementation_notes", "")).strip()[:512],
        })

    return normalized or [_fallback_coding_task()]


def _fallback_coding_task() -> dict:
    return {
        "id": "implementation",
        "title": "按任务拆分方案生成核心实现",
        "module_id": "",
        "depends_on": [],
        "target_files": [],
        "acceptance_checks": ["生成的文件路径、模块关系和接口契约保持一致"],
        "implementation_notes": "LLM 未返回有效计划，回退到单步实现。",
    }


def _string_list(raw, limit: int, max_len: int) -> list[str]:
    if not isinstance(raw, list):
        return []
    result: list[str] = []
    for item in raw:
        if not isinstance(item, str):
            continue
        value = item.strip()[:max_len]
        if value and value not in result:
            result.append(value)
        if len(result) >= limit:
            break
    return result


def _extract_json_fallback(raw: str) -> dict | None:
    import re
    raw = raw[:65536]
    m = re.search(r"```(?:json)?[ \t]*\n(.+?)\n[ \t]*```", raw, re.DOTALL)
    if m:
        try:
            return json.loads(m.group(1))
        except json.JSONDecodeError:
            pass
    start = raw.find("{")
    if start < 0:
        return None
    depth = 0
    for i in range(start, len(raw)):
        if raw[i] == "{":
            depth += 1
        elif raw[i] == "}":
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(raw[start : i + 1])
                except json.JSONDecodeError:
                    return None
    return None

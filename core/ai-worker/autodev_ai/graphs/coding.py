"""LangGraph coding generation workflow (development sub-step 2).

Graph topology:
    coding_agent_node (streaming) ──▶ synthesizer_node ──▶ normalizer_node

Produces a structured CodingResult with implementation code files.
"""

from __future__ import annotations

import json
import logging
from typing import TypedDict

from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, SystemMessage
from langgraph.graph import StateGraph, START, END

from ..config import ModelConfig
from ..retry import retry_async
from ..models import CodingContext, CodingResult, CodeFile
from ..prompts import (
    coding_agent_system_prompt,
    coding_agent_user_prompt,
    CODING_SYNTHESIZER_SYSTEM,
    coding_synthesizer_user_prompt,
)

logger = logging.getLogger(__name__)

MAX_CODE_FILES = 30

class CodingState(TypedDict, total=False):
    context: CodingContext
    config: ModelConfig
    coding_reply: str
    deltas: list[str]
    structured: dict
    result: CodingResult
    error: str | None


async def coding_agent_node(state: CodingState) -> dict:
    """Stage 1: streaming coding agent — produces implementation narrative."""
    ctx = state["context"]
    cfg = state["config"]

    llm = ChatOpenAI(
        model=cfg.model,
        api_key=cfg.api_key,
        base_url=cfg.base_url,
        temperature=0.2,
        max_tokens=4000,
        streaming=True,
    )

    task_breakdown_text = json.dumps(ctx.task_breakdown, ensure_ascii=False)

    messages = [
        SystemMessage(content=coding_agent_system_prompt()),
        HumanMessage(content=coding_agent_user_prompt(
            ctx.project_name, task_breakdown_text,
        )),
    ]

    full_reply = ""
    deltas: list[str] = []

    async def _stream():
        nonlocal full_reply, deltas
        full_reply = ""
        deltas = []
        async for chunk in llm.astream(messages):
            delta = chunk.content
            if delta:
                full_reply += delta
                deltas.append(delta)

    await retry_async(_stream)

    if not full_reply.strip():
        return {"error": "编码 Agent 返回空内容", "coding_reply": "", "deltas": deltas}

    return {"coding_reply": full_reply, "deltas": deltas}


async def synthesizer_node(state: CodingState) -> dict:
    """Stage 2: synthesizer — converts coding narrative to structured JSON."""
    ctx = state["context"]
    cfg = state["config"]
    coding_reply = state.get("coding_reply", "")

    if not coding_reply:
        return {"error": "无编码 Agent 回复，跳过结构化"}

    task_breakdown_text = json.dumps(ctx.task_breakdown, ensure_ascii=False)

    llm = ChatOpenAI(
        model=cfg.model,
        api_key=cfg.api_key,
        base_url=cfg.base_url,
        temperature=0.2,
        max_tokens=4000,
        model_kwargs={"response_format": {"type": "json_object"}},
    )

    messages = [
        SystemMessage(content=CODING_SYNTHESIZER_SYSTEM),
        HumanMessage(content=coding_synthesizer_user_prompt(
            ctx.project_name, task_breakdown_text, coding_reply,
        )),
    ]

    response = await retry_async(lambda: llm.ainvoke(messages))
    raw_text = response.content

    try:
        structured = json.loads(raw_text)
    except json.JSONDecodeError:
        structured = _extract_json_fallback(raw_text)
        if structured is None:
            return {"error": f"无法解析代码 JSON: {raw_text[:200]}"}

    return {"structured": structured}


async def normalizer_node(state: CodingState) -> dict:
    """Stage 3: normalize and validate the coding result."""
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
    graph.add_node("coding_agent", coding_agent_node)
    graph.add_node("synthesizer", synthesizer_node)
    graph.add_node("normalizer", normalizer_node)

    graph.add_edge(START, "coding_agent")
    graph.add_edge("coding_agent", "synthesizer")
    graph.add_edge("synthesizer", "normalizer")
    graph.add_edge("normalizer", END)

    return graph.compile()


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

"""LangGraph stage generation workflow.

Graph topology:
    agent_node (streaming) ──▶ synthesizer_node ──▶ normalizer_node

Replaces the hand-written two-stage chain in Rust ai_stage/mod.rs.
"""

from __future__ import annotations

import json
import logging
from typing import TypedDict

from langchain_openai import ChatOpenAI
from langchain_core.messages import HumanMessage, SystemMessage
from langgraph.graph import StateGraph, START, END

from ..config import ModelConfig
from ..models import StageContext, StageResult, StepProgress, WorkUnit
from ..prompts import (
    agent_system_prompt,
    agent_user_prompt,
    stage_label,
    SYNTHESIZER_SYSTEM,
    synthesizer_user_prompt,
)

logger = logging.getLogger(__name__)

MAX_INPUT_CONTEXTS = 8
MAX_RISK_ITEMS = 6
MAX_EVENT_FLOW = 6
MAX_SECONDARY_ACTIONS = 4
MAX_WORK_UNITS = 6

VALID_STATUSES = {
    "queued", "running", "completed", "awaiting_confirmation", "blocked", "failed",
}


# ---------- Graph state ----------

class StageState(TypedDict, total=False):
    context: StageContext
    config: ModelConfig
    agent_reply: str
    deltas: list[str]          # accumulated streaming deltas
    structured: dict           # raw JSON from synthesizer
    result: StageResult        # normalized final result
    error: str | None


# ---------- Nodes ----------

async def agent_node(state: StageState) -> dict:
    """Stage 1: streaming agent — produces narrative reply visible to user."""
    ctx = state["context"]
    cfg = state["config"]

    feasibility_text = json.dumps(ctx.feasibility or {}, ensure_ascii=False)

    llm = ChatOpenAI(
        model=cfg.model,
        api_key=cfg.api_key,
        base_url=cfg.base_url,
        temperature=0.2,
        max_tokens=1800,
        streaming=True,
    )

    messages = [
        SystemMessage(content=agent_system_prompt(ctx.stage)),
        HumanMessage(content=agent_user_prompt(
            ctx.project_name, ctx.stage, ctx.objective, feasibility_text,
        )),
    ]

    full_reply = ""
    deltas: list[str] = []

    async for chunk in llm.astream(messages):
        delta = chunk.content
        if delta:
            full_reply += delta
            deltas.append(delta)

    if not full_reply.strip():
        return {"error": "Agent 返回空内容", "agent_reply": "", "deltas": deltas}

    return {"agent_reply": full_reply, "deltas": deltas}


async def synthesizer_node(state: StageState) -> dict:
    """Stage 2: synthesizer — converts agent narrative to structured JSON."""
    ctx = state["context"]
    cfg = state["config"]
    agent_reply = state.get("agent_reply", "")

    if not agent_reply:
        return {"error": "无 Agent 回复，跳过结构化"}

    feasibility_text = json.dumps(ctx.feasibility or {}, ensure_ascii=False)
    defaults_json = json.dumps({
        "objective": ctx.objective,
        "input_contexts": ctx.input_contexts,
        "step_progress": ctx.step_progress,
        "risk_items": ctx.risk_items,
        "event_flow": ctx.event_flow,
        "primary_action": ctx.primary_action,
        "secondary_actions": ctx.secondary_actions,
        "work_units": ctx.work_units,
    }, ensure_ascii=False)

    llm = ChatOpenAI(
        model=cfg.model,
        api_key=cfg.api_key,
        base_url=cfg.base_url,
        temperature=0.2,
        max_tokens=1200,
        model_kwargs={"response_format": {"type": "json_object"}},
    )

    messages = [
        SystemMessage(content=SYNTHESIZER_SYSTEM),
        HumanMessage(content=synthesizer_user_prompt(
            ctx.project_name, ctx.stage, defaults_json, feasibility_text, agent_reply,
        )),
    ]

    response = await llm.ainvoke(messages)
    raw_text = response.content

    try:
        structured = json.loads(raw_text)
    except json.JSONDecodeError:
        # Fallback: try to extract JSON from code fence or braces
        structured = _extract_json_fallback(raw_text)
        if structured is None:
            return {"error": f"无法解析结构化 JSON: {raw_text[:200]}"}

    return {"structured": structured}


async def normalizer_node(state: StageState) -> dict:
    """Stage 3: normalize and cap the structured output."""
    ctx = state["context"]
    cfg = state["config"]
    raw = state.get("structured", {})

    if not raw:
        return {"error": "无结构化数据可规范化"}

    label = stage_label(ctx.stage)

    # Normalize input_contexts with model tag
    input_contexts = _capped_strings(raw.get("input_contexts", []), MAX_INPUT_CONTEXTS)
    input_contexts.insert(0, f"真实 AI：{cfg.model} / {label}")

    # Normalize step_progress
    steps = []
    for s in raw.get("step_progress", [])[:20]:
        title = s.get("title", "").strip() if isinstance(s, dict) else ""
        status = s.get("status", "queued") if isinstance(s, dict) else "queued"
        if title and status in VALID_STATUSES:
            steps.append(StepProgress(title=title, status=status))

    # Normalize work_units
    units = []
    for u in raw.get("work_units", [])[:MAX_WORK_UNITS]:
        if not isinstance(u, dict):
            continue
        uid = u.get("id", "").strip()
        utitle = u.get("title", "").strip()
        if not uid or not utitle:
            continue
        status = u.get("status", "queued")
        if status not in VALID_STATUSES:
            status = "queued"
        units.append(WorkUnit(
            id=uid,
            title=utitle,
            agent_role=u.get("agent_role", ""),
            status=status,
            progress=max(0.0, min(1.0, float(u.get("progress", 0)))),
            depends_on=u.get("depends_on", []),
            current_output=u.get("current_output"),
            next_step=u.get("next_step", ""),
        ))

    result = StageResult(
        objective=raw.get("objective", ctx.objective) or ctx.objective,
        input_contexts=input_contexts,
        step_progress=steps,
        risk_items=_capped_strings(raw.get("risk_items", []), MAX_RISK_ITEMS),
        event_flow=_capped_strings(raw.get("event_flow", []), MAX_EVENT_FLOW),
        primary_action=raw.get("primary_action", ""),
        secondary_actions=_capped_strings(
            raw.get("secondary_actions", []), MAX_SECONDARY_ACTIONS
        ),
        work_units=units,
    )

    return {"result": result}


# ---------- Build graph ----------

def build_stage_graph() -> StateGraph:
    """Construct the LangGraph workflow for stage generation."""
    graph = StateGraph(StageState)
    graph.add_node("agent", agent_node)
    graph.add_node("synthesizer", synthesizer_node)
    graph.add_node("normalizer", normalizer_node)

    graph.add_edge(START, "agent")
    graph.add_edge("agent", "synthesizer")
    graph.add_edge("synthesizer", "normalizer")
    graph.add_edge("normalizer", END)

    return graph.compile()


# ---------- Helpers ----------

def _capped_strings(items: list, limit: int) -> list[str]:
    result = []
    if not isinstance(items, list):
        return result
    for item in items[:limit]:
        text = str(item).strip()
        if text:
            result.append(text)
    return result


def _extract_json_fallback(raw: str) -> dict | None:
    """Try to extract JSON from code fence or balanced braces."""
    import re
    # Code fence
    m = re.search(r"```(?:json)?\s*\n?(.*?)\n?```", raw, re.DOTALL)
    if m:
        try:
            return json.loads(m.group(1))
        except json.JSONDecodeError:
            pass
    # Balanced braces
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

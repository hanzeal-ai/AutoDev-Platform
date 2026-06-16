"""LangGraph PRD generation workflow.

Graph topology:
    agent_node (streaming) ──▶ synthesizer_node ──▶ normalizer_node

Produces a structured PRDResult with scope items, acceptance criteria, milestones.
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
from ..models import (
    PRDContext,
    PRDResult,
    ScopeItem,
    AcceptanceCriterion,
    Milestone,
)
from ..prompts import (
    prd_agent_system_prompt,
    prd_agent_user_prompt,
    PRD_SYNTHESIZER_SYSTEM,
    prd_synthesizer_user_prompt,
)
from ..tracing import build_trace_config

logger = logging.getLogger(__name__)


VALID_PRIORITIES = {"P0", "P1", "P2"}
VALID_CATEGORIES = {"frontend", "backend", "infra", "cross-cutting"}
VALID_CRITICALITIES = {"must", "should", "nice-to-have"}


# ---------- Graph state ----------

class PRDState(TypedDict, total=False):
    context: PRDContext
    config: ModelConfig
    agent_reply: str
    deltas: list[str]
    structured: dict
    result: PRDResult
    error: str | None


# ---------- Nodes ----------

async def agent_node(state: PRDState) -> dict:
    """Stage 1: streaming PRD agent — produces narrative PRD."""
    ctx = state["context"]
    cfg = state["config"]

    llm = create_llm(cfg, max_tokens=2400, streaming=True)

    feasibility_text = json.dumps(ctx.feasibility or {}, ensure_ascii=False)

    messages = [
        SystemMessage(content=prd_agent_system_prompt()),
        HumanMessage(content=prd_agent_user_prompt(ctx.project_name, feasibility_text)),
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
                "prd_agent",
                "prd",
                ctx,
                prompt_keys=["prd.agent.system", "prd.agent.user"],
            ),
        ):
            delta = chunk.content
            if delta:
                full_reply += delta
                deltas.append(delta)

    await retry_async(_stream)

    if not full_reply.strip():
        return {"error": "PRD Agent 返回空内容", "agent_reply": "", "deltas": deltas}

    return {"agent_reply": full_reply, "deltas": deltas}


async def synthesizer_node(state: PRDState) -> dict:
    """Stage 2: synthesizer — converts PRD narrative to structured JSON."""
    ctx = state["context"]
    cfg = state["config"]
    agent_reply = state.get("agent_reply", "")

    if not agent_reply:
        return {"error": "无 PRD Agent 回复，跳过结构化"}

    feasibility_text = json.dumps(ctx.feasibility or {}, ensure_ascii=False)

    llm = create_llm(cfg, max_tokens=2000, json_mode=True)

    messages = [
        SystemMessage(content=PRD_SYNTHESIZER_SYSTEM),
        HumanMessage(content=prd_synthesizer_user_prompt(
            ctx.project_name, feasibility_text, agent_reply,
        )),
    ]

    response = await retry_async(
        lambda: llm.ainvoke(
            messages,
            config=build_trace_config(
                "prd_synthesizer",
                "prd",
                ctx,
                prompt_keys=["prd.synthesizer.system", "prd.synthesizer.user"],
            ),
        )
    )
    raw_text = response.content

    try:
        structured = json.loads(raw_text)
    except json.JSONDecodeError:
        structured = _extract_json_fallback(raw_text)
        if structured is None:
            return {"error": f"无法解析 PRD JSON: {raw_text[:200]}"}

    return {"structured": structured}


async def normalizer_node(state: PRDState) -> dict:
    """Stage 3: normalize and validate the PRD structured output."""
    ctx = state["context"]
    raw = state.get("structured", {})

    if not raw:
        return {"error": "无 PRD 结构化数据可规范化"}

    # Normalize scope_items
    scope_items = []
    for item in raw.get("scope_items", [])[:20]:
        if not isinstance(item, dict):
            continue
        sid = item.get("id", "").strip()
        name = item.get("name", "").strip()
        if not sid or not name:
            continue
        priority = item.get("priority", "P1").upper()
        if priority not in VALID_PRIORITIES:
            priority = "P1"
        category = item.get("category", "frontend").lower()
        if category not in VALID_CATEGORIES:
            category = "frontend"
        scope_items.append(ScopeItem(
            id=sid,
            name=name,
            description=item.get("description", "")[:2048],
            priority=priority,
            category=category,
        ))

    # Normalize acceptance_criteria
    criteria = []
    scope_ids = {s.id for s in scope_items}
    for ac in raw.get("acceptance_criteria", [])[:30]:
        if not isinstance(ac, dict):
            continue
        aid = ac.get("id", "").strip()
        statement = ac.get("statement", "").strip()
        if not aid or not statement:
            continue
        criticality = ac.get("criticality", "must").lower()
        if criticality not in VALID_CRITICALITIES:
            criticality = "must"
        scope_item_id = ac.get("scope_item_id", "")
        criteria.append(AcceptanceCriterion(
            id=aid,
            scope_item_id=scope_item_id,
            statement=statement[:2048],
            criticality=criticality,
        ))

    # Normalize milestones
    milestones = []
    for ms in raw.get("milestones", [])[:10]:
        if not isinstance(ms, dict):
            continue
        mid = ms.get("id", "").strip()
        title = ms.get("title", "").strip()
        if not mid or not title:
            continue
        ms_scope_ids = [s for s in ms.get("scope_item_ids", []) if isinstance(s, str)]
        milestones.append(Milestone(
            id=mid,
            title=title,
            scope_item_ids=ms_scope_ids[:20],
            target_description=ms.get("target_description", "")[:1024],
        ))

    goals = _capped_strings(raw.get("goals", []), 8)
    non_goals = _capped_strings(raw.get("non_goals", []), 6)
    constraints = _capped_strings(raw.get("technical_constraints", []), 10)

    result = PRDResult(
        project_name=raw.get("project_name", ctx.project_name) or ctx.project_name,
        summary=raw.get("summary", "")[:2048],
        goals=goals,
        non_goals=non_goals,
        scope_items=scope_items,
        technical_constraints=constraints,
        acceptance_criteria=criteria,
        milestones=milestones,
    )

    return {"result": result}


# ---------- Build graph ----------

def build_prd_graph() -> StateGraph:
    graph = StateGraph(PRDState)
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

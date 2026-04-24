"""LangGraph development plan generation workflow.

Graph topology:
    architect_node (streaming) ──▶ synthesizer_node ──▶ normalizer_node

Produces a structured DevelopmentPlan with tech stack, modules, API contracts, scaffold files.
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
from ..models import (
    DevelopmentContext,
    DevelopmentPlan,
    TechStack,
    ModuleSpec,
    APIContract,
    ScaffoldFile,
)
from ..prompts import (
    dev_architect_system_prompt,
    dev_architect_user_prompt,
    DEV_SYNTHESIZER_SYSTEM,
    dev_synthesizer_user_prompt,
)

logger = logging.getLogger(__name__)

VALID_HTTP_METHODS = {"GET", "POST", "PUT", "DELETE", "PATCH"}
MAX_MODULES = 15
MAX_API_CONTRACTS = 20
MAX_SCAFFOLD_FILES = 30


# ---------- Graph state ----------

class DevState(TypedDict, total=False):
    context: DevelopmentContext
    config: ModelConfig
    architect_reply: str
    deltas: list[str]
    structured: dict
    result: DevelopmentPlan
    error: str | None


# ---------- Nodes ----------

async def architect_node(state: DevState) -> dict:
    """Stage 1: streaming architect agent — produces architecture narrative."""
    ctx = state["context"]
    cfg = state["config"]

    llm = ChatOpenAI(
        model=cfg.model,
        api_key=cfg.api_key,
        base_url=cfg.base_url,
        temperature=0.2,
        max_tokens=2800,
        streaming=True,
    )

    prd_text = json.dumps(ctx.prd or {}, ensure_ascii=False)
    feasibility_text = json.dumps(ctx.feasibility or {}, ensure_ascii=False)

    messages = [
        SystemMessage(content=dev_architect_system_prompt()),
        HumanMessage(content=dev_architect_user_prompt(
            ctx.project_name, prd_text, feasibility_text,
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
        return {"error": "架构 Agent 返回空内容", "architect_reply": "", "deltas": deltas}

    return {"architect_reply": full_reply, "deltas": deltas}


async def synthesizer_node(state: DevState) -> dict:
    """Stage 2: synthesizer — converts architecture narrative to structured JSON."""
    ctx = state["context"]
    cfg = state["config"]
    architect_reply = state.get("architect_reply", "")

    if not architect_reply:
        return {"error": "无架构 Agent 回复，跳过结构化"}

    prd_text = json.dumps(ctx.prd or {}, ensure_ascii=False)

    llm = ChatOpenAI(
        model=cfg.model,
        api_key=cfg.api_key,
        base_url=cfg.base_url,
        temperature=0.2,
        max_tokens=3000,
        model_kwargs={"response_format": {"type": "json_object"}},
    )

    messages = [
        SystemMessage(content=DEV_SYNTHESIZER_SYSTEM),
        HumanMessage(content=dev_synthesizer_user_prompt(
            ctx.project_name, prd_text, architect_reply,
        )),
    ]

    response = await retry_async(lambda: llm.ainvoke(messages))
    raw_text = response.content

    try:
        structured = json.loads(raw_text)
    except json.JSONDecodeError:
        structured = _extract_json_fallback(raw_text)
        if structured is None:
            return {"error": f"无法解析研发方案 JSON: {raw_text[:200]}"}

    return {"structured": structured}


async def normalizer_node(state: DevState) -> dict:
    """Stage 3: normalize and validate the development plan."""
    raw = state.get("structured", {})

    if not raw:
        return {"error": "无研发方案结构化数据可规范化"}

    # Normalize tech_stack
    raw_ts = raw.get("tech_stack", {})
    if not isinstance(raw_ts, dict):
        raw_ts = {}
    tech_stack = TechStack(
        language=raw_ts.get("language", "")[:64],
        framework=raw_ts.get("framework", "")[:128],
        build_tool=raw_ts.get("build_tool", "")[:64],
        package_manager=raw_ts.get("package_manager", "")[:64],
        runtime=raw_ts.get("runtime", "")[:64],
        additional=_capped_strings(raw_ts.get("additional", []), 10),
    )

    # Normalize modules
    modules = []
    for m in raw.get("modules", [])[:MAX_MODULES]:
        if not isinstance(m, dict):
            continue
        mid = m.get("id", "").strip()
        name = m.get("name", "").strip()
        if not mid or not name:
            continue
        modules.append(ModuleSpec(
            id=mid,
            name=name,
            responsibility=m.get("responsibility", "")[:1024],
            depends_on=[d for d in m.get("depends_on", []) if isinstance(d, str)][:10],
            files=[f for f in m.get("files", []) if isinstance(f, str)][:20],
        ))

    # Normalize api_contracts
    api_contracts = []
    for api in raw.get("api_contracts", [])[:MAX_API_CONTRACTS]:
        if not isinstance(api, dict):
            continue
        aid = api.get("id", "").strip()
        path = api.get("path", "").strip()
        if not aid or not path:
            continue
        method = api.get("method", "GET").upper()
        if method not in VALID_HTTP_METHODS:
            method = "GET"
        api_contracts.append(APIContract(
            id=aid,
            method=method,
            path=path[:512],
            description=api.get("description", "")[:1024],
            request_schema=api.get("request_schema", "")[:4096],
            response_schema=api.get("response_schema", "")[:4096],
            scope_item_id=api.get("scope_item_id", "")[:64],
        ))

    # Normalize scaffold_files
    scaffold_files = []
    for sf in raw.get("scaffold_files", [])[:MAX_SCAFFOLD_FILES]:
        if not isinstance(sf, dict):
            continue
        fpath = sf.get("path", "").strip()
        if not fpath:
            continue
        scaffold_files.append(ScaffoldFile(
            path=fpath[:512],
            content=sf.get("content", "")[:32768],
            language=sf.get("language", "")[:32],
            purpose=sf.get("purpose", "")[:256],
        ))

    result = DevelopmentPlan(
        architecture_summary=raw.get("architecture_summary", "")[:4096],
        tech_stack=tech_stack,
        modules=modules,
        api_contracts=api_contracts,
        scaffold_files=scaffold_files,
    )

    return {"result": result}


# ---------- Build graph ----------

def build_development_graph() -> StateGraph:
    graph = StateGraph(DevState)
    graph.add_node("architect", architect_node)
    graph.add_node("synthesizer", synthesizer_node)
    graph.add_node("normalizer", normalizer_node)

    graph.add_edge(START, "architect")
    graph.add_edge("architect", "synthesizer")
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

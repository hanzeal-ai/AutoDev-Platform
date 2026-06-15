"""FastAPI application — HTTP interface for Rust daemon to call."""

from __future__ import annotations

import asyncio
import logging
import time as _time
import traceback

from fastapi import FastAPI, HTTPException
from sse_starlette.sse import EventSourceResponse

from .config import ModelConfig, get_worker_port
from .graphs.chat import generate_chat, generate_chat_stream
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
    StreamDelta,
    WorkflowResumeContext,
    WorkflowStartContext,
)
from .workflow import get_workflow_status, resume_workflow, start_workflow

# ── Logging setup ──────────────────────────────────────────────────────────────
# Explicitly set converter = time.localtime on the Formatter base class so that
# every handler (including ones Uvicorn installs) uses local time, not UTC.
# force=True removes any handlers that Uvicorn may have attached to the root
# logger before this module was imported, then installs a fresh StreamHandler
# with our format (which includes %z so the timezone offset is always visible).
logging.Formatter.converter = _time.localtime
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(name)s %(levelname)s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S %z",
    force=True,
)
logger = logging.getLogger("autodev_ai")

app = FastAPI(title="AutoDev AI Worker", version="0.1.0")

# Pre-compile the stage graph once at startup
_stage_graph = build_stage_graph()
_prd_graph = build_prd_graph()
_dev_graph = build_development_graph()
_coding_graph = build_coding_graph()


async def _sse_stream_graph(graph, initial_state: dict, agent_node: str, error_label: str):
    """Shared SSE streaming logic for all LangGraph graphs."""
    last_deltas_len = 0
    final_result = None

    async for event in graph.astream(initial_state, stream_mode="updates"):
        for node_name, update in event.items():
            if node_name == agent_node:
                new_deltas = update.get("deltas", [])
                for delta in new_deltas[last_deltas_len:]:
                    yield {
                        "event": "message",
                        "data": StreamDelta(kind="delta", content=delta).model_dump_json(),
                    }
                last_deltas_len = len(new_deltas)

            if update.get("error"):
                yield {
                    "event": "message",
                    "data": StreamDelta(kind="error", content=update["error"]).model_dump_json(),
                }
                return

            result = update.get("result")
            if result:
                final_result = result

    if final_result:
        yield {
            "event": "message",
            "data": StreamDelta(
                kind="result", structured=final_result.model_dump()
            ).model_dump_json(),
        }
    else:
        yield {
            "event": "message",
            "data": StreamDelta(
                kind="error", content=f"{error_label} 图执行完成但无最终结果"
            ).model_dump_json(),
        }


@app.get("/health")
async def health():
    try:
        cfg = ModelConfig.from_env()
        return {"status": "ok", "model": cfg.model, "base_url": cfg.base_url}
    except RuntimeError:
        return {"status": "degraded", "error": "AI 配置加载失败"}


@app.post("/generate/stage")
async def generate_stage(ctx: StageContext):
    """Run stage AI generation with SSE streaming.

    Returns an SSE stream with events:
      - kind=delta  : each streaming chunk from the agent node
      - kind=result : final structured StageResult JSON
      - kind=error  : error message
    """
    try:
        cfg = ModelConfig.from_env()
    except RuntimeError:
        raise HTTPException(status_code=503, detail="AI 服务不可用")

    async def event_generator():
        try:
            initial_state: StageState = {
                "context": ctx,
                "config": cfg,
                "agent_reply": "",
                "deltas": [],
                "structured": {},
                "error": None,
            }
            async for evt in _sse_stream_graph(_stage_graph, initial_state, "agent", ""):
                yield evt
        except Exception:
            logger.error("Stage generation failed: %s", traceback.format_exc())
            yield {
                "event": "message",
                "data": StreamDelta(kind="error", content="AI 生成失败，请重试").model_dump_json(),
            }

    return EventSourceResponse(event_generator())


@app.post("/generate/report")
async def generate_feasibility_report(ctx: ReportContext):
    """Generate a feasibility report (non-streaming)."""
    try:
        cfg = ModelConfig.from_env()
    except RuntimeError:
        raise HTTPException(status_code=503, detail="AI 服务不可用")

    try:
        report = await generate_report(ctx, cfg)
        return report.model_dump()
    except Exception as exc:
        logger.error("Report generation failed: %s", traceback.format_exc())
        raise HTTPException(status_code=500, detail="报告生成失败，请重试")


@app.post("/generate/chat")
async def generate_chat_clarification(ctx: ChatContext):
    """Run a single chat clarification turn (non-streaming).

    Returns JSON with assistant_reply and report_patch.
    """
    try:
        cfg = ModelConfig.from_env()
    except RuntimeError:
        raise HTTPException(status_code=503, detail="AI 服务不可用")

    try:
        result = await generate_chat(ctx, cfg)
        return result.model_dump()
    except Exception as exc:
        logger.error("Chat clarification failed: %s", traceback.format_exc())
        raise HTTPException(status_code=500, detail="对话生成失败，请重试")


@app.post("/generate/chat/stream")
async def generate_chat_stream_endpoint(ctx: ChatContext):
    """Run a chat clarification turn with SSE streaming.

    Returns an SSE stream with events:
      - kind=delta  : each streaming text chunk of the assistant reply
      - kind=result : final structured {assistant_reply, report_patch} JSON
      - kind=error  : error message
    """
    try:
        cfg = ModelConfig.from_env()
    except RuntimeError:
        raise HTTPException(status_code=503, detail="AI 服务不可用")

    async def event_generator():
        try:
            # Timeout slightly longer than the Rust-side SO_RCVTIMEO (120 s) so
            # the client sees a clean error event rather than a socket timeout.
            async with asyncio.timeout(130):
                async for evt in generate_chat_stream(ctx, cfg):
                    yield evt
        except TimeoutError:
            logger.error("Chat stream timed out after 130 s (thread_id=%s)", ctx.thread_id)
            yield {
                "event": "message",
                "data": StreamDelta(kind="error", content="对话生成超时，请重试").model_dump_json(),
            }
        except Exception:
            logger.error("Chat stream failed: %s", traceback.format_exc())
            yield {
                "event": "message",
                "data": StreamDelta(kind="error", content="对话生成失败，请重试").model_dump_json(),
            }

    return EventSourceResponse(event_generator())


@app.post("/generate/prd")
async def generate_prd(ctx: PRDContext):
    """Run PRD AI generation with SSE streaming.

    Returns an SSE stream with events:
      - kind=delta  : each streaming chunk from the agent node
      - kind=result : final structured PRDResult JSON
      - kind=error  : error message
    """
    try:
        cfg = ModelConfig.from_env()
    except RuntimeError:
        raise HTTPException(status_code=503, detail="AI 服务不可用")

    async def event_generator():
        try:
            initial_state: PRDState = {
                "context": ctx,
                "config": cfg,
                "agent_reply": "",
                "deltas": [],
                "structured": {},
                "error": None,
            }
            async for evt in _sse_stream_graph(_prd_graph, initial_state, "agent", "PRD"):
                yield evt
        except Exception:
            logger.error("PRD generation failed: %s", traceback.format_exc())
            yield {
                "event": "message",
                "data": StreamDelta(kind="error", content="PRD 生成失败，请重试").model_dump_json(),
            }

    return EventSourceResponse(event_generator())


@app.post("/generate/development")
async def generate_development(ctx: DevelopmentContext):
    """Run development plan AI generation with SSE streaming.

    Returns an SSE stream with events:
      - kind=delta  : each streaming chunk from the architect node
      - kind=result : final structured DevelopmentPlan JSON
      - kind=error  : error message
    """
    try:
        cfg = ModelConfig.from_env()
    except RuntimeError:
        raise HTTPException(status_code=503, detail="AI 服务不可用")

    async def event_generator():
        try:
            initial_state: DevState = {
                "context": ctx,
                "config": cfg,
                "architect_reply": "",
                "deltas": [],
                "structured": {},
                "error": None,
            }
            async for evt in _sse_stream_graph(_dev_graph, initial_state, "architect", "研发方案"):
                yield evt
        except Exception:
            logger.error("Development generation failed: %s", traceback.format_exc())
            yield {
                "event": "message",
                "data": StreamDelta(
                    kind="error", content="研发方案生成失败，请重试"
                ).model_dump_json(),
            }

    return EventSourceResponse(event_generator())


@app.post("/generate/development/coding")
async def generate_development_coding(ctx: CodingContext):
    """Run development coding AI generation with SSE streaming."""
    try:
        cfg = ModelConfig.from_env()
    except RuntimeError:
        raise HTTPException(status_code=503, detail="AI 服务不可用")

    async def event_generator():
        try:
            initial_state: CodingState = {
                "context": ctx,
                "config": cfg,
                "coding_plan": [],
                "coding_reply": "",
                "deltas": [],
                "structured": {},
                "error": None,
            }
            async for evt in _sse_stream_graph(
                _coding_graph, initial_state, "coding_agent", "代码生成"
            ):
                yield evt
        except Exception:
            logger.error("Coding generation failed: %s", traceback.format_exc())
            yield {
                "event": "message",
                "data": StreamDelta(kind="error", content="代码生成失败，请重试").model_dump_json(),
            }

    return EventSourceResponse(event_generator())


@app.post("/workflow/start")
async def workflow_start(ctx: WorkflowStartContext):
    """Start the unified checkpointed workflow."""
    try:
        return await start_workflow(ctx)
    except RuntimeError:
        raise HTTPException(status_code=503, detail="AI 服务不可用")
    except Exception:
        logger.error("Workflow start failed: %s", traceback.format_exc())
        raise HTTPException(status_code=500, detail="Workflow 执行失败，请重试")


@app.post("/workflow/resume")
async def workflow_resume(ctx: WorkflowResumeContext):
    """Resume a workflow from its latest SQLite checkpoint."""
    try:
        return await resume_workflow(ctx.workflow_id)
    except RuntimeError:
        raise HTTPException(status_code=503, detail="AI 服务不可用")
    except Exception:
        logger.error("Workflow resume failed: %s", traceback.format_exc())
        raise HTTPException(status_code=500, detail="Workflow 恢复失败，请重试")


@app.post("/workflow/status")
async def workflow_status(ctx: WorkflowResumeContext):
    """Return the latest checkpointed workflow state without advancing it."""
    try:
        return await get_workflow_status(ctx.workflow_id)
    except Exception:
        logger.error("Workflow status failed: %s", traceback.format_exc())
        raise HTTPException(status_code=500, detail="Workflow 状态读取失败，请重试")

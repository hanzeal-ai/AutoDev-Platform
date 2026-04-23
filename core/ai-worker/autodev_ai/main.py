"""FastAPI application — HTTP interface for Rust daemon to call."""

from __future__ import annotations

import json
import logging
import traceback

from fastapi import FastAPI, HTTPException
from sse_starlette.sse import EventSourceResponse

from .config import ModelConfig, get_worker_port
from .models import StageContext, ReportContext, StreamDelta
from .graphs.stage import build_stage_graph, StageState
from .graphs.report import generate_report

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")
logger = logging.getLogger("autodev_ai")

app = FastAPI(title="AutoDev AI Worker", version="0.1.0")

# Pre-compile the stage graph once at startup
_stage_graph = build_stage_graph()


@app.get("/health")
async def health():
    try:
        ModelConfig.from_env()
        return {"status": "ok"}
    except RuntimeError as e:
        return {"status": "degraded", "error": str(e)}


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
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

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

            # Stream through the graph
            last_deltas_len = 0
            final_result = None

            async for event in _stage_graph.astream(
                initial_state,
                stream_mode="updates",
            ):
                # event is {node_name: state_update}
                for node_name, update in event.items():
                    # Stream agent deltas incrementally
                    if node_name == "agent":
                        new_deltas = update.get("deltas", [])
                        for delta in new_deltas[last_deltas_len:]:
                            yield {
                                "event": "message",
                                "data": StreamDelta(
                                    kind="delta", content=delta
                                ).model_dump_json(),
                            }
                        last_deltas_len = len(new_deltas)

                        if update.get("error"):
                            yield {
                                "event": "message",
                                "data": StreamDelta(
                                    kind="error", content=update["error"]
                                ).model_dump_json(),
                            }
                            return

                    elif node_name == "synthesizer":
                        if update.get("error"):
                            yield {
                                "event": "message",
                                "data": StreamDelta(
                                    kind="error", content=update["error"]
                                ).model_dump_json(),
                            }
                            return

                    elif node_name == "normalizer":
                        if update.get("error"):
                            yield {
                                "event": "message",
                                "data": StreamDelta(
                                    kind="error", content=update["error"]
                                ).model_dump_json(),
                            }
                            return
                        result = update.get("result")
                        if result:
                            final_result = result

            if final_result:
                yield {
                    "event": "message",
                    "data": StreamDelta(
                        kind="result",
                        structured=final_result.model_dump(),
                    ).model_dump_json(),
                }
            else:
                yield {
                    "event": "message",
                    "data": StreamDelta(
                        kind="error", content="图执行完成但无最终结果"
                    ).model_dump_json(),
                }

        except Exception as exc:
            logger.error("Stage generation failed: %s", traceback.format_exc())
            yield {
                "event": "message",
                "data": StreamDelta(
                    kind="error", content=str(exc)
                ).model_dump_json(),
            }

    return EventSourceResponse(event_generator())


@app.post("/generate/report")
async def generate_feasibility_report(ctx: ReportContext):
    """Generate a feasibility report (non-streaming)."""
    try:
        cfg = ModelConfig.from_env()
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

    try:
        report = await generate_report(ctx, cfg)
        return report.model_dump()
    except Exception as exc:
        logger.error("Report generation failed: %s", traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(exc))

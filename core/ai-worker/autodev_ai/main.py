"""FastAPI application — HTTP interface for Rust daemon to call."""

from __future__ import annotations

import logging
import time as _time
import traceback

from fastapi import FastAPI, HTTPException

from .config import ModelConfig, get_worker_port
from .models import (
    WorkflowArtifactContext,
    WorkflowResumeContext,
    WorkflowStartContext,
)
from .workflow import get_workflow_artifact, get_workflow_status, resume_workflow, start_workflow

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


@app.get("/health")
async def health():
    try:
        cfg = ModelConfig.from_env()
        return {"status": "ok", "model": cfg.model, "base_url": cfg.base_url}
    except RuntimeError:
        return {"status": "degraded", "error": "AI 配置加载失败"}


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


@app.post("/workflow/artifact")
async def workflow_artifact(ctx: WorkflowArtifactContext):
    """Return one workflow artifact from the latest checkpoint."""
    try:
        artifact = await get_workflow_artifact(ctx.workflow_id, ctx.artifact_id)
    except Exception:
        logger.error("Workflow artifact failed: %s", traceback.format_exc())
        raise HTTPException(status_code=500, detail="Workflow 产物读取失败，请重试")
    if artifact is None:
        raise HTTPException(status_code=404, detail="Workflow 产物不存在")
    return artifact

"""Workflow runtime service and state projection helpers."""

from __future__ import annotations

from typing import Any

from .projection import (
    build_workflow_artifact,
    build_workflow_events,
    build_workflow_status,
)
from .types import AutoDevWorkflowState, NodeName, WorkflowNode

_SERVICE_EXPORTS = {
    "get_workflow_artifact",
    "get_workflow_checkpoint_path",
    "get_workflow_events",
    "get_workflow_status",
    "resume_workflow",
    "start_workflow",
    "stream_workflow",
    "workflow_config",
}

__all__ = [
    "AutoDevWorkflowState",
    "NodeName",
    "WorkflowNode",
    "build_workflow_artifact",
    "build_workflow_events",
    "build_workflow_status",
    "get_workflow_artifact",
    "get_workflow_checkpoint_path",
    "get_workflow_events",
    "get_workflow_status",
    "resume_workflow",
    "start_workflow",
    "stream_workflow",
    "workflow_config",
]


def __getattr__(name: str) -> Any:
    if name in _SERVICE_EXPORTS:
        from . import service

        return getattr(service, name)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")

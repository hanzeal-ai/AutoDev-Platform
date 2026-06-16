"""LangSmith tracing helpers with conservative metadata redaction."""

from __future__ import annotations

import os
from collections.abc import Mapping
from typing import Any

from .prompt_registry import prompt_versions


def configure_langsmith_tracing() -> None:
    """Apply safe LangSmith defaults after .env has been loaded.

    LangSmith tracing can capture model prompts and outputs. This worker defaults
    to hiding both so project-specific secrets, user text, material contents, and
    generated code are not sent unless the operator explicitly opts in.
    """
    tracing_enabled = os.environ.get("LANGSMITH_TRACING", "").lower() in {"1", "true", "yes"}
    if not tracing_enabled:
        return

    os.environ.setdefault("LANGSMITH_PROJECT", "autodev")
    os.environ.setdefault("LANGSMITH_HIDE_INPUTS", "true")
    os.environ.setdefault("LANGSMITH_HIDE_OUTPUTS", "true")
    os.environ.setdefault("LANGCHAIN_HIDE_INPUTS", os.environ["LANGSMITH_HIDE_INPUTS"])
    os.environ.setdefault("LANGCHAIN_HIDE_OUTPUTS", os.environ["LANGSMITH_HIDE_OUTPUTS"])


def build_trace_config(
    run_name: str,
    stage: str,
    context: Any | None = None,
    prompt_keys: list[str] | tuple[str, ...] | str | None = None,
) -> dict[str, Any]:
    """Build RunnableConfig-compatible trace data without raw request content."""
    metadata = summarize_context(stage, context)
    keys = _normalize_prompt_keys(prompt_keys)
    if keys:
        metadata["prompt_keys"] = keys
        metadata["prompt_versions"] = prompt_versions(keys)
    return {
        "run_name": run_name,
        "tags": ["ai-worker", stage],
        "metadata": metadata,
    }


def summarize_context(stage: str, context: Any | None) -> dict[str, Any]:
    """Summarize a request context without prompt, material, or code contents."""
    metadata: dict[str, Any] = {
        "trace_schema_version": 1,
        "stage": _safe_string(stage, 64),
    }
    if context is None:
        return metadata

    for field in ("project_id", "thread_id"):
        value = getattr(context, field, None)
        if isinstance(value, str) and value:
            metadata[field] = _safe_string(value, 128)

    messages = getattr(context, "messages", None)
    if isinstance(messages, list):
        metadata["message_count"] = len(messages)

    materials = getattr(context, "materials", None)
    if isinstance(materials, list):
        metadata["material_count"] = len(materials)

    draft = getattr(context, "draft", None)
    if isinstance(draft, Mapping):
        metadata["draft_field_count"] = len(draft)

    task_breakdown = getattr(context, "task_breakdown", None)
    if isinstance(task_breakdown, Mapping):
        metadata["task_breakdown_keys"] = sorted(
            str(key)[:64] for key in task_breakdown.keys()
        )[:20]
        files = task_breakdown.get("scaffold_files")
        if isinstance(files, list):
            metadata["scaffold_file_count"] = len(files)
        modules = task_breakdown.get("modules")
        if isinstance(modules, list):
            metadata["module_count"] = len(modules)

    return metadata


def _safe_string(value: str, max_len: int) -> str:
    return value.strip()[:max_len]


def _normalize_prompt_keys(prompt_keys: list[str] | tuple[str, ...] | str | None) -> list[str]:
    if prompt_keys is None:
        return []
    if isinstance(prompt_keys, str):
        raw_keys = [prompt_keys]
    else:
        raw_keys = list(prompt_keys)
    keys: list[str] = []
    seen: set[str] = set()
    for key in raw_keys:
        if not isinstance(key, str):
            continue
        normalized = key.strip()
        if normalized and normalized not in seen:
            seen.add(normalized)
            keys.append(normalized)
    return keys

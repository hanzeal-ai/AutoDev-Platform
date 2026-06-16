"""Versioned prompt registry.

The registry tracks prompt identity and version without sending prompt bodies to
trace metadata. Prompt functions can keep their existing string-returning API
while consumers can still inspect which prompt version was used.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class PromptSpec:
    key: str
    version: str
    stage: str
    role: str
    content: str
    description: str = ""


_PROMPTS: dict[str, PromptSpec] = {}
_LOADING_PROMPTS = False


def register_prompt(spec: PromptSpec) -> PromptSpec:
    if not spec.key.strip():
        raise ValueError("prompt key must not be empty")
    if not spec.version.strip():
        raise ValueError(f"prompt {spec.key} version must not be empty")
    if not spec.content.strip():
        raise ValueError(f"prompt {spec.key} content must not be empty")
    _PROMPTS[spec.key] = spec
    return spec


def get_prompt(key: str) -> PromptSpec:
    _ensure_prompts_registered()
    try:
        return _PROMPTS[key]
    except KeyError as exc:
        raise KeyError(f"unknown prompt key: {key}") from exc


def get_prompt_content(key: str) -> str:
    return get_prompt(key).content


def list_prompts() -> list[PromptSpec]:
    _ensure_prompts_registered()
    return [spec for _, spec in sorted(_PROMPTS.items())]


def prompt_metadata(key: str) -> dict[str, Any]:
    spec = get_prompt(key)
    return {
        "prompt_key": spec.key,
        "prompt_version": spec.version,
        "prompt_stage": spec.stage,
        "prompt_role": spec.role,
    }


def prompt_versions(keys: list[str]) -> dict[str, str]:
    return {key: get_prompt(key).version for key in keys}


def _ensure_prompts_registered() -> None:
    global _LOADING_PROMPTS
    if _PROMPTS or _LOADING_PROMPTS:
        return
    _LOADING_PROMPTS = True
    try:
        from . import prompts  # noqa: F401
    finally:
        _LOADING_PROMPTS = False

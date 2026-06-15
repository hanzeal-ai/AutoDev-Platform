"""LLM construction helpers for AI worker graph nodes."""

from __future__ import annotations

from langchain_openai import ChatOpenAI

from .config import ModelConfig


def create_llm(
    cfg: ModelConfig,
    *,
    max_tokens: int,
    temperature: float = 0.2,
    streaming: bool = False,
    json_mode: bool = False,
) -> ChatOpenAI:
    """Create a configured chat model while keeping node-specific knobs explicit."""
    kwargs = {
        "model": cfg.model,
        "api_key": cfg.api_key,
        "base_url": cfg.base_url,
        "temperature": temperature,
        "max_tokens": max_tokens,
    }
    if streaming:
        kwargs["streaming"] = True
    if json_mode:
        kwargs["model_kwargs"] = {"response_format": {"type": "json_object"}}
    return ChatOpenAI(**kwargs)

"""Tests for LangSmith tracing configuration and metadata redaction."""

from autodev_ai.models import ChatContext, ChatMessage, CodingContext
from autodev_ai.tracing import (
    build_trace_config,
    configure_langsmith_tracing,
    summarize_context,
)


def test_configure_langsmith_defaults_hide_inputs_and_outputs(monkeypatch):
    monkeypatch.setenv("LANGSMITH_TRACING", "true")
    monkeypatch.delenv("LANGSMITH_HIDE_INPUTS", raising=False)
    monkeypatch.delenv("LANGSMITH_HIDE_OUTPUTS", raising=False)
    monkeypatch.delenv("LANGSMITH_PROJECT", raising=False)

    configure_langsmith_tracing()

    import os

    assert os.environ["LANGSMITH_HIDE_INPUTS"] == "true"
    assert os.environ["LANGSMITH_HIDE_OUTPUTS"] == "true"
    assert os.environ["LANGCHAIN_HIDE_INPUTS"] == "true"
    assert os.environ["LANGCHAIN_HIDE_OUTPUTS"] == "true"
    assert os.environ["LANGSMITH_PROJECT"] == "autodev"


def test_summarize_context_excludes_chat_content():
    ctx = ChatContext(
        thread_id="thread-1",
        user_message="用户的商业机密需求",
        messages=[ChatMessage(role="user", content="历史敏感内容")],
        materials=[],
    )

    metadata = summarize_context("chat", ctx)

    dumped = repr(metadata)
    assert "thread-1" in dumped
    assert "用户的商业机密需求" not in dumped
    assert "历史敏感内容" not in dumped
    assert metadata["message_count"] == 1


def test_build_trace_config_uses_safe_tags_and_metadata():
    ctx = CodingContext(
        project_id="proj-1",
        project_name="Sensitive Project",
        task_breakdown={
            "scaffold_files": [
                {"path": "secret.py", "content": "API_KEY = 'do-not-record'"},
            ]
        },
    )

    config = build_trace_config("coding_agent", "coding", ctx)

    dumped = repr(config)
    assert "coding_agent" in dumped
    assert "ai-worker" in dumped
    assert "proj-1" in dumped
    assert "Sensitive Project" not in dumped
    assert "do-not-record" not in dumped


def test_build_trace_config_records_prompt_versions_without_content():
    ctx = ChatContext(thread_id="thread-1", user_message="secret prompt input")

    config = build_trace_config("chat_clarification", "chat", ctx, prompt_keys=["chat.system"])

    metadata = config["metadata"]
    dumped = repr(metadata)
    assert metadata["prompt_keys"] == ["chat.system"]
    assert metadata["prompt_versions"]["chat.system"]
    assert "assistant_reply" not in dumped
    assert "secret prompt input" not in dumped

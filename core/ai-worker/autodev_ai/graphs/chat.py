"""Chat clarification — single-step LLM call returning assistant_reply + report_patch.

Replaces Rust store/reports/chat/mod.rs direct DeepSeek call.
Also provides a streaming variant for SSE delivery.
"""

from __future__ import annotations

import json
import logging
from typing import AsyncIterator

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_openai import ChatOpenAI

from ..config import ModelConfig
from ..models import ChatContext, ClarificationResult, StreamDelta
from ..prompts import CHAT_SYSTEM, chat_user_prompt

logger = logging.getLogger(__name__)

PLACEHOLDER_NAMES = {"待定义", "新项目", "项目", ""}
REPORT_PATCH_FIELDS = {
    "project_name",
    "problem_definition",
    "target_users",
    "core_capabilities",
    "risks_and_constraints",
    "initial_delivery_plan",
    "feasibility_conclusion",
}


async def generate_chat(ctx: ChatContext, cfg: ModelConfig) -> ClarificationResult:
    """Run a single clarification turn and return assistant_reply + report_patch."""

    draft_json = json.dumps(ctx.draft, ensure_ascii=False)

    message_lines = "- 无历史消息"
    if ctx.messages:
        lines = []
        for i, msg in enumerate(ctx.messages[:8], 1):
            content = msg.content[:220]
            lines.append(f"- {i}. [{msg.role}] {content}")
        message_lines = "\n".join(lines)

    material_lines = "- 无材料"
    if ctx.materials:
        lines = []
        for i, mat in enumerate(ctx.materials[:6], 1):
            lines.append(f"- {i}. {mat.name} | {mat.type_hint} | {mat.size_hint} | {mat.status}")
        material_lines = "\n".join(lines)

    llm = ChatOpenAI(
        model=cfg.model,
        api_key=cfg.api_key,
        base_url=cfg.base_url,
        temperature=0.2,
        max_tokens=520,
        model_kwargs={"response_format": {"type": "json_object"}},
    )

    messages = [
        SystemMessage(content=CHAT_SYSTEM),
        HumanMessage(
            content=chat_user_prompt(
                draft_json,
                message_lines,
                material_lines,
                ctx.user_message,
            )
        ),
    ]

    response = await llm.ainvoke(messages)

    try:
        raw = json.loads(response.content)
    except json.JSONDecodeError:
        logger.warning("Chat JSON parse failed, returning generic reply")
        return ClarificationResult(
            assistant_reply="抱歉，AI 解析失败，请重新描述您的需求。",
            report_patch={},
        )

    return _normalize(raw)


def _normalize(raw: dict) -> ClarificationResult:
    assistant_reply = str(raw.get("assistant_reply", "")).strip()
    if not assistant_reply:
        assistant_reply = "抱歉，AI 未能生成有效回复，请重新描述您的需求。"

    patch = _normalize_report_patch(raw.get("report_patch"))

    return ClarificationResult(assistant_reply=assistant_reply, report_patch=patch)


def _normalize_report_patch(raw_patch) -> dict:
    if not isinstance(raw_patch, dict):
        return {}

    patch: dict = {}

    for field in ("problem_definition", "target_users", "feasibility_conclusion"):
        val = raw_patch.get(field)
        if isinstance(val, str) and val.strip():
            patch[field] = val.strip()

    # project_name: reject placeholders
    pn = raw_patch.get("project_name")
    if isinstance(pn, str) and pn.strip() and pn.strip() not in PLACEHOLDER_NAMES:
        patch["project_name"] = pn.strip()

    for field in ("core_capabilities", "risks_and_constraints", "initial_delivery_plan"):
        val = raw_patch.get(field)
        items: list[str] = []
        if isinstance(val, list):
            items = [str(s).strip() for s in val if str(s).strip()]
        elif isinstance(val, str) and val.strip():
            items = [val.strip()]
        if items:
            # deduplicate, cap at 6
            seen: set[str] = set()
            unique: list[str] = []
            for item in items:
                if item not in seen:
                    seen.add(item)
                    unique.append(item)
            patch[field] = unique[:6]

    return patch


async def generate_chat_stream(
    ctx: ChatContext,
    cfg: ModelConfig,
) -> AsyncIterator[dict]:
    """Streaming variant of generate_chat. Yields SSE-ready dicts.

    The LLM outputs JSON: {"assistant_reply": "...", "report_patch": {...}}.
    We incrementally parse the stream to extract only the assistant_reply
    value as deltas, so the user sees clean text — not raw JSON.
    """
    draft_json = json.dumps(ctx.draft, ensure_ascii=False)

    message_lines = "- 无历史消息"
    if ctx.messages:
        lines = []
        for i, msg in enumerate(ctx.messages[:8], 1):
            content = msg.content[:220]
            lines.append(f"- {i}. [{msg.role}] {content}")
        message_lines = "\n".join(lines)

    material_lines = "- 无材料"
    if ctx.materials:
        lines = []
        for i, mat in enumerate(ctx.materials[:6], 1):
            lines.append(f"- {i}. {mat.name} | {mat.type_hint} | {mat.size_hint} | {mat.status}")
        material_lines = "\n".join(lines)

    llm = ChatOpenAI(
        model=cfg.model,
        api_key=cfg.api_key,
        base_url=cfg.base_url,
        temperature=0.2,
        max_tokens=520,
        streaming=True,
        model_kwargs={"response_format": {"type": "json_object"}},
    )

    messages = [
        SystemMessage(content=CHAT_SYSTEM),
        HumanMessage(
            content=chat_user_prompt(
                draft_json,
                message_lines,
                material_lines,
                ctx.user_message,
            )
        ),
    ]

    full_reply = ""
    extractor = _AssistantReplyExtractor()
    try:
        async for chunk in llm.astream(messages):
            delta = chunk.content
            if delta:
                full_reply += delta
                # Extract only assistant_reply content from the JSON stream
                text_delta = extractor.feed(delta)
                if text_delta:
                    yield {
                        "event": "message",
                        "data": StreamDelta(kind="delta", content=text_delta).model_dump_json(),
                    }
    except Exception:
        logger.exception(
            "Chat stream LLM call failed (thread_id=%s, message_preview=%.80s)",
            getattr(ctx, "thread_id", "unknown"),
            ctx.user_message if hasattr(ctx, "user_message") else "",
        )
        yield {
            "event": "message",
            "data": StreamDelta(kind="error", content="AI 生成失败，请重试").model_dump_json(),
        }
        return

    # Parse the full accumulated JSON response
    try:
        raw = json.loads(full_reply)
    except json.JSONDecodeError:
        logger.warning("Chat stream JSON parse failed, raw: %s", full_reply[:200])
        raw = {"assistant_reply": full_reply, "report_patch": {}}

    result = _normalize(raw)
    yield {
        "event": "message",
        "data": StreamDelta(
            kind="result",
            structured=result.model_dump(),
        ).model_dump_json(),
    }


class _AssistantReplyExtractor:
    """Incrementally extracts the assistant_reply string value from a
    streaming JSON output like: {"assistant_reply": "...", "report_patch": {...}}

    State machine:
      BEFORE  → scanning for "assistant_reply" key + colon + opening quote
      INSIDE  → forwarding string content, handling JSON escapes
      AFTER   → done, swallow everything else (report_patch etc.)
    """

    _BEFORE = 0
    _INSIDE = 1
    _AFTER = 2

    def __init__(self) -> None:
        self._state = self._BEFORE
        self._buf = ""  # accumulator for BEFORE-phase pattern matching
        self._escape = False  # previous char was backslash
        self._unicode_digits = ""

    def feed(self, chunk: str) -> str:
        """Feed a raw JSON chunk and return the extracted reply text (may be empty)."""
        if self._state == self._AFTER:
            return ""

        if self._state == self._BEFORE:
            return self._feed_before(chunk)

        # _INSIDE
        return self._feed_inside(chunk)

    def _feed_before(self, chunk: str) -> str:
        """Scan for the opening quote of the assistant_reply value."""
        self._buf += chunk

        # Look for: "assistant_reply" followed by optional whitespace, colon,
        # optional whitespace, then opening double-quote
        marker = '"assistant_reply"'
        idx = self._buf.find(marker)
        if idx == -1:
            # Keep only the tail that might still contain a partial match
            keep = len(marker) + 10
            if len(self._buf) > keep:
                self._buf = self._buf[-keep:]
            return ""

        # Found the key — now find : then opening "
        after_key = self._buf[idx + len(marker) :]
        colon_idx = after_key.find(":")
        if colon_idx == -1:
            return ""  # colon not yet arrived

        after_colon = after_key[colon_idx + 1 :].lstrip()
        if not after_colon:
            return ""  # opening quote not yet arrived

        if after_colon[0] != '"':
            # Unexpected token — skip
            self._state = self._AFTER
            return ""

        # Everything after the opening quote is reply content
        self._state = self._INSIDE
        remainder = after_colon[1:]
        return self._feed_inside(remainder)

    def _feed_inside(self, chunk: str) -> str:
        """Extract string content, respecting JSON escape sequences."""
        out: list[str] = []
        for ch in chunk:
            if self._unicode_digits:
                if ch.lower() in "0123456789abcdef":
                    self._unicode_digits += ch
                    if len(self._unicode_digits) == 4:
                        try:
                            out.append(chr(int(self._unicode_digits, 16)))
                        except ValueError:
                            out.append("\\u")
                            out.append(self._unicode_digits)
                        self._unicode_digits = ""
                    continue

                out.append("\\u")
                out.append(self._unicode_digits)
                self._unicode_digits = ""

            if self._escape:
                self._escape = False
                # Standard JSON escape mappings
                if ch == '"':
                    out.append('"')
                elif ch == "\\":
                    out.append("\\")
                elif ch == "n":
                    out.append("\n")
                elif ch == "r":
                    out.append("\r")
                elif ch == "t":
                    out.append("\t")
                elif ch == "/":
                    out.append("/")
                elif ch == "u":
                    self._unicode_digits = ""
                else:
                    out.append("\\")
                    out.append(ch)
                continue

            if ch == "\\":
                self._escape = True
                continue

            if ch == '"':
                # Closing quote — we're done with assistant_reply
                self._state = self._AFTER
                break

            out.append(ch)

        return "".join(out)

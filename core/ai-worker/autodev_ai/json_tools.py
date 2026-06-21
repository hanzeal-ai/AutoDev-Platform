from __future__ import annotations

import json
import re
from typing import Any


def extract_json_fallback(raw: str) -> dict[str, Any] | None:
    """Extract a JSON object from fenced text or the first balanced object."""
    raw = raw[:65536]
    match = re.search(r"```(?:json)?[ \t]*\n(.+?)\n[ \t]*```", raw, re.DOTALL)
    if match:
        try:
            return json.loads(match.group(1))
        except json.JSONDecodeError:
            pass

    start = raw.find("{")
    if start < 0:
        return None
    depth = 0
    for idx, char in enumerate(raw[start:], start):
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                try:
                    return json.loads(raw[start : idx + 1])
                except json.JSONDecodeError:
                    return None
    return None

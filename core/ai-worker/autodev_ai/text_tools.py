from __future__ import annotations

from typing import Any


def string_list(raw: Any, limit: int, max_len: int) -> list[str]:
    if not isinstance(raw, list):
        return []
    result: list[str] = []
    for item in raw:
        value = str(item).strip()[:max_len]
        if value:
            result.append(value)
        if len(result) >= limit:
            break
    return result


def deduped_string_list(raw: Any, limit: int, max_len: int) -> list[str]:
    if not isinstance(raw, list):
        return []
    result: list[str] = []
    for item in raw:
        if not isinstance(item, str):
            continue
        value = item.strip()[:max_len]
        if value and value not in result:
            result.append(value)
        if len(result) >= limit:
            break
    return result

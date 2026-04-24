import json
from autodev_ai.graphs.stage import _capped_strings, _extract_json_fallback


class TestCappedStrings:
    def test_caps_at_limit(self):
        items = ["a", "b", "c", "d", "e"]
        result = _capped_strings(items, 3)
        assert result == ["a", "b", "c"]

    def test_strips_empty(self):
        items = ["a", "", "  ", "b"]
        result = _capped_strings(items, 10)
        assert result == ["a", "b"]

    def test_handles_non_list(self):
        result = _capped_strings("not a list", 5)
        assert result == []


class TestExtractJsonFallback:
    def test_extracts_from_code_fence(self):
        raw = '```json\n{"key": "value"}\n```'
        result = _extract_json_fallback(raw)
        assert result == {"key": "value"}

    def test_extracts_from_braces(self):
        raw = 'Some text {"key": "value"} more text'
        result = _extract_json_fallback(raw)
        assert result == {"key": "value"}

    def test_returns_none_for_no_json(self):
        result = _extract_json_fallback("no json here")
        assert result is None

    def test_returns_none_for_invalid_json(self):
        result = _extract_json_fallback("{invalid json}")
        assert result is None

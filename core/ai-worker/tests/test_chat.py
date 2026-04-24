"""Tests for chat clarification normalization logic."""

from autodev_ai.graphs.chat import _normalize, _normalize_report_patch


class TestNormalize:
    def test_valid_response(self):
        raw = {
            "assistant_reply": "这是一个可行的方案。",
            "report_patch": {"project_name": "MyProject"},
        }
        result = _normalize(raw)
        assert result.assistant_reply == "这是一个可行的方案。"
        assert result.report_patch == {"project_name": "MyProject"}

    def test_empty_reply_returns_fallback(self):
        raw = {"assistant_reply": "", "report_patch": {}}
        result = _normalize(raw)
        assert "未能生成" in result.assistant_reply

    def test_missing_reply_returns_fallback(self):
        result = _normalize({})
        assert "未能生成" in result.assistant_reply

    def test_missing_report_patch(self):
        raw = {"assistant_reply": "hello"}
        result = _normalize(raw)
        assert result.report_patch == {}


class TestNormalizeReportPatch:
    def test_rejects_placeholder_project_name(self):
        patch = _normalize_report_patch({"project_name": "待定义"})
        assert "project_name" not in patch

    def test_accepts_valid_project_name(self):
        patch = _normalize_report_patch({"project_name": "AI平台"})
        assert patch["project_name"] == "AI平台"

    def test_text_fields_trimmed(self):
        patch = _normalize_report_patch({"problem_definition": "  解决问题  "})
        assert patch["problem_definition"] == "解决问题"

    def test_list_field_from_array(self):
        patch = _normalize_report_patch({"core_capabilities": ["A", "", "A", "B"]})
        assert patch["core_capabilities"] == ["A", "B"]

    def test_list_field_from_string(self):
        patch = _normalize_report_patch({"initial_delivery_plan": "第一步"})
        assert patch["initial_delivery_plan"] == ["第一步"]

    def test_list_field_capped_at_6(self):
        items = [f"item{i}" for i in range(10)]
        patch = _normalize_report_patch({"risks_and_constraints": items})
        assert len(patch["risks_and_constraints"]) == 6

    def test_empty_values_excluded(self):
        patch = _normalize_report_patch({
            "problem_definition": "  ",
            "core_capabilities": [],
        })
        assert patch == {}

    def test_non_dict_returns_empty(self):
        assert _normalize_report_patch("not a dict") == {}
        assert _normalize_report_patch(None) == {}

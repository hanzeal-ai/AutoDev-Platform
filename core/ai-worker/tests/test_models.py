import pytest
from autodev_ai.models import (
    StageContext, ReportContext, StageResult, FeasibilityReport, StreamDelta,
    ChatContext, ClarificationResult,
)


class TestStageContext:
    def test_valid_stage_context(self):
        ctx = StageContext(project_id="abc-123", project_name="Test", stage="prd")
        assert ctx.project_id == "abc-123"
        assert ctx.stage == "prd"

    def test_invalid_stage_raises(self):
        with pytest.raises(ValueError):
            StageContext(project_id="abc", project_name="Test", stage="invalid")

    def test_empty_project_id_raises(self):
        with pytest.raises(ValueError):
            StageContext(project_id="", project_name="Test", stage="prd")

    def test_empty_project_name_raises(self):
        with pytest.raises(ValueError):
            StageContext(project_id="abc", project_name="  ", stage="prd")

    def test_all_valid_stages(self):
        for stage in ["feasibility", "prd", "ui", "development", "testing", "release", "maintenance"]:
            ctx = StageContext(project_id="abc", project_name="Test", stage=stage)
            assert ctx.stage == stage

    def test_defaults(self):
        ctx = StageContext(project_id="abc", project_name="Test", stage="prd")
        assert ctx.objective == ""
        assert ctx.input_contexts == []
        assert ctx.feasibility is None


class TestReportContext:
    def test_valid_report_context(self):
        ctx = ReportContext(thread_id="abc-123")
        assert ctx.thread_id == "abc-123"

    def test_invalid_thread_id_raises(self):
        with pytest.raises(ValueError):
            ReportContext(thread_id="")


class TestStageResult:
    def test_minimal_result(self):
        result = StageResult(objective="test")
        assert result.objective == "test"
        assert result.work_units == []


class TestStreamDelta:
    def test_delta_kind(self):
        d = StreamDelta(kind="delta", content="hello")
        assert d.kind == "delta"
        assert d.content == "hello"
        assert d.structured is None

    def test_result_kind_with_structured(self):
        d = StreamDelta(kind="result", structured={"key": "val"})
        assert d.structured == {"key": "val"}


class TestChatContext:
    def test_valid_chat_context(self):
        ctx = ChatContext(thread_id="abc-123", user_message="hello")
        assert ctx.thread_id == "abc-123"
        assert ctx.user_message == "hello"

    def test_empty_thread_id_raises(self):
        with pytest.raises(ValueError):
            ChatContext(thread_id="", user_message="hello")

    def test_empty_user_message_raises(self):
        with pytest.raises(ValueError):
            ChatContext(thread_id="abc", user_message="  ")

    def test_defaults(self):
        ctx = ChatContext(thread_id="abc", user_message="hi")
        assert ctx.draft == {}
        assert ctx.messages == []
        assert ctx.materials == []


class TestClarificationResult:
    def test_basic(self):
        r = ClarificationResult(assistant_reply="OK", report_patch={"project_name": "X"})
        assert r.assistant_reply == "OK"
        assert r.report_patch == {"project_name": "X"}

    def test_defaults(self):
        r = ClarificationResult(assistant_reply="hi")
        assert r.report_patch == {}

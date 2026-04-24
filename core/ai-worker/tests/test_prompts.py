from autodev_ai.prompts import (
    stage_label, agent_system_prompt, agent_user_prompt,
    REPORT_SYSTEM, CHAT_SYSTEM, chat_user_prompt,
)


class TestStageLabel:
    def test_known_labels(self):
        assert stage_label("feasibility") == "可行性"
        assert stage_label("prd") == "PRD"
        assert stage_label("development") == "研发"

    def test_unknown_label(self):
        assert stage_label("unknown") == "阶段"


class TestAgentPrompts:
    def test_system_prompt_contains_stage(self):
        prompt = agent_system_prompt("prd")
        assert "PRD" in prompt
        assert "Agent" in prompt

    def test_user_prompt_contains_project_info(self):
        prompt = agent_user_prompt("MyProject", "prd", "冻结PRD", "{}")
        assert "MyProject" in prompt
        assert "prd" in prompt


class TestReportPrompt:
    def test_report_system_is_not_empty(self):
        assert len(REPORT_SYSTEM) > 50
        assert "JSON" in REPORT_SYSTEM


class TestChatPrompts:
    def test_chat_system_prompt_contains_key_phrases(self):
        assert len(CHAT_SYSTEM) > 50
        assert "JSON" in CHAT_SYSTEM
        assert "assistant_reply" in CHAT_SYSTEM
        assert "report_patch" in CHAT_SYSTEM

    def test_chat_user_prompt_includes_context(self):
        prompt = chat_user_prompt("{}", "- msg1", "- mat1", "用户输入")
        assert "用户输入" in prompt
        assert "msg1" in prompt
        assert "mat1" in prompt

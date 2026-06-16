from autodev_ai.prompts import (
    stage_label, agent_system_prompt, agent_user_prompt,
    REPORT_SYSTEM, CHAT_SYSTEM, chat_user_prompt,
    coding_planner_system_prompt,
    coding_planner_user_prompt,
)
from autodev_ai.prompt_registry import get_prompt, list_prompts, prompt_metadata


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
        assert "需求是否合理" in CHAT_SYSTEM
        assert "是否缺少关键信息" in CHAT_SYSTEM

    def test_chat_user_prompt_includes_context(self):
        prompt = chat_user_prompt("{}", "- msg1", "- mat1", "用户输入")
        assert "用户输入" in prompt
        assert "msg1" in prompt
        assert "mat1" in prompt


class TestCodingPrompts:
    def test_coding_planner_prompts_define_planning_contract(self):
        system_prompt = coding_planner_system_prompt()
        user_prompt = coding_planner_user_prompt("项目", "{}")

        assert "planning" in system_prompt.lower()
        assert "tasks" in system_prompt
        assert "acceptance_checks" in system_prompt
        assert "项目" in user_prompt


class TestPromptRegistry:
    def test_registry_exposes_versioned_prompts(self):
        prompts = list_prompts()
        keys = {prompt.key for prompt in prompts}

        assert "chat.system" in keys
        assert "coding.planner.system" in keys
        assert all(prompt.version for prompt in prompts)
        assert len(keys) == len(prompts)

    def test_registry_content_matches_existing_prompt_exports(self):
        assert get_prompt("chat.system").content == CHAT_SYSTEM
        assert get_prompt("report.system").content == REPORT_SYSTEM

    def test_prompt_metadata_excludes_prompt_content(self):
        metadata = prompt_metadata("chat.system")

        assert metadata["prompt_key"] == "chat.system"
        assert metadata["prompt_version"]
        assert "content" not in metadata
        assert CHAT_SYSTEM not in repr(metadata)

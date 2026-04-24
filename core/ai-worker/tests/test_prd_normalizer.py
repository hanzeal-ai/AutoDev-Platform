"""Tests for PRD graph normalizer_node — validation, capping, and normalization logic."""

import asyncio

import pytest

from autodev_ai.graphs.prd import normalizer_node
from autodev_ai.models import PRDContext, PRDResult, ScopeItem, AcceptanceCriterion, Milestone


def _make_state(structured: dict) -> dict:
    ctx = PRDContext(project_id="test-proj-001", project_name="测试项目")
    return {"context": ctx, "structured": structured}


def _run(state: dict) -> dict:
    return asyncio.run(normalizer_node(state))


class TestScopeItemNormalization:
    def test_valid_scope_item(self):
        state = _make_state({
            "scope_items": [{"id": "s1", "name": "用户认证", "priority": "P0", "category": "backend"}],
        })
        result: PRDResult = _run(state)["result"]
        assert len(result.scope_items) == 1
        assert result.scope_items[0].priority == "P0"
        assert result.scope_items[0].category == "backend"

    def test_invalid_priority_defaults_to_p1(self):
        state = _make_state({
            "scope_items": [{"id": "s1", "name": "功能A", "priority": "INVALID", "category": "frontend"}],
        })
        result: PRDResult = _run(state)["result"]
        assert result.scope_items[0].priority == "P1"

    def test_invalid_category_defaults_to_frontend(self):
        state = _make_state({
            "scope_items": [{"id": "s1", "name": "功能B", "priority": "P0", "category": "unknown"}],
        })
        result: PRDResult = _run(state)["result"]
        assert result.scope_items[0].category == "frontend"

    def test_capped_at_20(self):
        items = [{"id": f"s{i}", "name": f"功能{i}", "priority": "P1", "category": "backend"} for i in range(25)]
        state = _make_state({"scope_items": items})
        result: PRDResult = _run(state)["result"]
        assert len(result.scope_items) == 20

    def test_skips_non_dict_items(self):
        state = _make_state({"scope_items": ["not-a-dict", {"id": "s1", "name": "有效"}]})
        result: PRDResult = _run(state)["result"]
        assert len(result.scope_items) == 1

    def test_skips_missing_id_or_name(self):
        state = _make_state({"scope_items": [{"id": "", "name": "无ID"}, {"id": "s1", "name": ""}]})
        result: PRDResult = _run(state)["result"]
        assert len(result.scope_items) == 0

    def test_description_truncated_at_2048(self):
        state = _make_state({
            "scope_items": [{"id": "s1", "name": "长描述", "description": "x" * 3000}],
        })
        result: PRDResult = _run(state)["result"]
        assert len(result.scope_items[0].description) == 2048


class TestCriteriaNormalization:
    def test_valid_criterion(self):
        state = _make_state({
            "scope_items": [{"id": "s1", "name": "功能"}],
            "acceptance_criteria": [{"id": "ac1", "scope_item_id": "s1", "statement": "能登录", "criticality": "must"}],
        })
        result: PRDResult = _run(state)["result"]
        assert len(result.acceptance_criteria) == 1
        assert result.acceptance_criteria[0].criticality == "must"

    def test_invalid_criticality_defaults_to_must(self):
        state = _make_state({
            "acceptance_criteria": [{"id": "ac1", "statement": "条件", "criticality": "INVALID"}],
        })
        result: PRDResult = _run(state)["result"]
        assert result.acceptance_criteria[0].criticality == "must"

    def test_statement_truncated_at_2048(self):
        state = _make_state({
            "acceptance_criteria": [{"id": "ac1", "statement": "s" * 3000}],
        })
        result: PRDResult = _run(state)["result"]
        assert len(result.acceptance_criteria[0].statement) == 2048

    def test_capped_at_30(self):
        items = [{"id": f"ac{i}", "statement": f"条件{i}"} for i in range(35)]
        state = _make_state({"acceptance_criteria": items})
        result: PRDResult = _run(state)["result"]
        assert len(result.acceptance_criteria) == 30


class TestMilestoneNormalization:
    def test_valid_milestone(self):
        state = _make_state({
            "milestones": [{"id": "m1", "title": "阶段一", "target_description": "完成核心功能"}],
        })
        result: PRDResult = _run(state)["result"]
        assert len(result.milestones) == 1
        assert result.milestones[0].title == "阶段一"

    def test_scope_item_ids_capped_at_20(self):
        ids = [f"s{i}" for i in range(25)]
        state = _make_state({
            "milestones": [{"id": "m1", "title": "里程碑", "scope_item_ids": ids}],
        })
        result: PRDResult = _run(state)["result"]
        assert len(result.milestones[0].scope_item_ids) == 20

    def test_capped_at_10(self):
        items = [{"id": f"m{i}", "title": f"里程碑{i}"} for i in range(15)]
        state = _make_state({"milestones": items})
        result: PRDResult = _run(state)["result"]
        assert len(result.milestones) == 10


class TestGoalsAndConstraints:
    def test_goals_capped_at_8(self):
        state = _make_state({"goals": [f"目标{i}" for i in range(12)]})
        result: PRDResult = _run(state)["result"]
        assert len(result.goals) == 8

    def test_non_goals_capped_at_6(self):
        state = _make_state({"non_goals": [f"非目标{i}" for i in range(10)]})
        result: PRDResult = _run(state)["result"]
        assert len(result.non_goals) == 6

    def test_constraints_capped_at_10(self):
        state = _make_state({"technical_constraints": [f"约束{i}" for i in range(15)]})
        result: PRDResult = _run(state)["result"]
        assert len(result.technical_constraints) == 10


class TestPRDNormalizerIntegration:
    def test_full_normalizer_flow(self):
        state = _make_state({
            "project_name": "集成测试",
            "summary": "测试摘要",
            "goals": ["目标1", "目标2"],
            "non_goals": ["非目标1"],
            "scope_items": [
                {"id": "s1", "name": "登录", "priority": "P0", "category": "frontend", "description": "用户登录功能"},
                {"id": "s2", "name": "注册", "priority": "P1", "category": "backend", "description": "用户注册"},
            ],
            "technical_constraints": ["macOS 12+", "SQLite"],
            "acceptance_criteria": [
                {"id": "ac1", "scope_item_id": "s1", "statement": "能输入密码登录", "criticality": "must"},
                {"id": "ac2", "scope_item_id": "s2", "statement": "邮箱验证", "criticality": "should"},
            ],
            "milestones": [
                {"id": "m1", "title": "MVP", "scope_item_ids": ["s1"], "target_description": "基础登录可用"},
            ],
        })
        result: PRDResult = _run(state)["result"]

        assert result.project_name == "集成测试"
        assert result.summary == "测试摘要"
        assert len(result.goals) == 2
        assert len(result.non_goals) == 1
        assert len(result.scope_items) == 2
        assert len(result.technical_constraints) == 2
        assert len(result.acceptance_criteria) == 2
        assert len(result.milestones) == 1

    def test_empty_structured_returns_error(self):
        state = _make_state({})
        state["structured"] = {}
        result = _run(state)
        assert "error" in result

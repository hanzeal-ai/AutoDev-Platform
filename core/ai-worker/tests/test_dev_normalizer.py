"""Tests for Development graph normalizer_node — validation, capping, and normalization logic."""

import asyncio

import pytest

from autodev_ai.graphs.development import normalizer_node
from autodev_ai.models import DevelopmentContext, DevelopmentPlan, TechStack, ModuleSpec, APIContract, ScaffoldFile


def _make_state(structured: dict) -> dict:
    return {"structured": structured}


def _run(state: dict) -> dict:
    return asyncio.run(normalizer_node(state))


class TestTechStackNormalization:
    def test_valid_tech_stack(self):
        state = _make_state({
            "tech_stack": {"language": "Rust", "framework": "Actix-web", "build_tool": "cargo",
                           "package_manager": "cargo", "runtime": "native"},
        })
        result: DevelopmentPlan = _run(state)["result"]
        assert result.tech_stack.language == "Rust"
        assert result.tech_stack.framework == "Actix-web"

    def test_additional_capped_at_10(self):
        state = _make_state({
            "tech_stack": {"language": "Go", "additional": [f"dep{i}" for i in range(15)]},
        })
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.tech_stack.additional) == 10

    def test_non_dict_tech_stack_defaults(self):
        state = _make_state({"tech_stack": "not-a-dict"})
        result: DevelopmentPlan = _run(state)["result"]
        assert result.tech_stack.language == ""

    def test_language_truncated_at_64(self):
        state = _make_state({"tech_stack": {"language": "x" * 100}})
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.tech_stack.language) == 64


class TestModuleNormalization:
    def test_valid_module(self):
        state = _make_state({
            "modules": [{"id": "m1", "name": "auth", "responsibility": "用户认证"}],
        })
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.modules) == 1
        assert result.modules[0].name == "auth"

    def test_capped_at_15(self):
        items = [{"id": f"m{i}", "name": f"模块{i}"} for i in range(20)]
        state = _make_state({"modules": items})
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.modules) == 15

    def test_depends_on_capped_at_10(self):
        deps = [f"dep{i}" for i in range(15)]
        state = _make_state({
            "modules": [{"id": "m1", "name": "核心", "depends_on": deps}],
        })
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.modules[0].depends_on) == 10

    def test_files_capped_at_20(self):
        files = [f"src/file{i}.rs" for i in range(25)]
        state = _make_state({
            "modules": [{"id": "m1", "name": "核心", "files": files}],
        })
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.modules[0].files) == 20

    def test_skips_missing_id_or_name(self):
        state = _make_state({"modules": [{"id": "", "name": "无ID"}, {"id": "m1", "name": ""}]})
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.modules) == 0

    def test_responsibility_truncated_at_1024(self):
        state = _make_state({
            "modules": [{"id": "m1", "name": "模块", "responsibility": "r" * 2000}],
        })
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.modules[0].responsibility) == 1024


class TestAPIContractNormalization:
    def test_valid_api(self):
        state = _make_state({
            "api_contracts": [{"id": "a1", "method": "POST", "path": "/api/users", "description": "创建用户"}],
        })
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.api_contracts) == 1
        assert result.api_contracts[0].method == "POST"

    def test_invalid_method_defaults_to_get(self):
        state = _make_state({
            "api_contracts": [{"id": "a1", "method": "INVALID", "path": "/api/test"}],
        })
        result: DevelopmentPlan = _run(state)["result"]
        assert result.api_contracts[0].method == "GET"

    def test_capped_at_20(self):
        items = [{"id": f"a{i}", "method": "GET", "path": f"/api/r{i}"} for i in range(25)]
        state = _make_state({"api_contracts": items})
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.api_contracts) == 20

    def test_path_truncated_at_512(self):
        state = _make_state({
            "api_contracts": [{"id": "a1", "path": "/" + "x" * 600}],
        })
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.api_contracts[0].path) == 512

    def test_schema_truncated_at_4096(self):
        state = _make_state({
            "api_contracts": [{"id": "a1", "path": "/test", "request_schema": "s" * 5000, "response_schema": "r" * 5000}],
        })
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.api_contracts[0].request_schema) == 4096
        assert len(result.api_contracts[0].response_schema) == 4096

    def test_skips_missing_id_or_path(self):
        state = _make_state({
            "api_contracts": [{"id": "", "path": "/test"}, {"id": "a1", "path": ""}],
        })
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.api_contracts) == 0


class TestScaffoldFileNormalization:
    def test_valid_scaffold(self):
        state = _make_state({
            "scaffold_files": [{"path": "src/main.rs", "content": "fn main() {}", "language": "rust", "purpose": "入口"}],
        })
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.scaffold_files) == 1
        assert result.scaffold_files[0].language == "rust"

    def test_capped_at_30(self):
        items = [{"path": f"src/file{i}.rs", "content": "code"} for i in range(35)]
        state = _make_state({"scaffold_files": items})
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.scaffold_files) == 30

    def test_content_truncated_at_32768(self):
        state = _make_state({
            "scaffold_files": [{"path": "big.rs", "content": "c" * 40000}],
        })
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.scaffold_files[0].content) == 32768

    def test_skips_empty_path(self):
        state = _make_state({"scaffold_files": [{"path": "", "content": "code"}]})
        result: DevelopmentPlan = _run(state)["result"]
        assert len(result.scaffold_files) == 0


class TestDevNormalizerIntegration:
    def test_full_normalizer_flow(self):
        state = _make_state({
            "architecture_summary": "微服务架构",
            "tech_stack": {"language": "Rust", "framework": "Actix-web", "build_tool": "cargo",
                           "package_manager": "cargo", "runtime": "native", "additional": ["SQLite"]},
            "modules": [
                {"id": "m1", "name": "auth", "responsibility": "认证授权", "depends_on": [], "files": ["src/auth.rs"]},
                {"id": "m2", "name": "api", "responsibility": "接口层", "depends_on": ["m1"], "files": ["src/api.rs"]},
            ],
            "api_contracts": [
                {"id": "a1", "method": "POST", "path": "/api/login", "description": "登录"},
            ],
            "scaffold_files": [
                {"path": "src/main.rs", "content": "fn main() {}", "language": "rust", "purpose": "入口"},
            ],
        })
        result: DevelopmentPlan = _run(state)["result"]

        assert result.architecture_summary == "微服务架构"
        assert result.tech_stack.language == "Rust"
        assert len(result.modules) == 2
        assert len(result.api_contracts) == 1
        assert len(result.scaffold_files) == 1

    def test_empty_structured_returns_error(self):
        state = _make_state({})
        state["structured"] = {}
        result = _run(state)
        assert "error" in result

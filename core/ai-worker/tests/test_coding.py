"""Tests for coding graph planning helpers."""

import pytest

from autodev_ai.config import ModelConfig
from autodev_ai.graphs import coding as coding_module
from autodev_ai.graphs.coding import (
    _normalize_coding_plan,
    document_provider_node,
    normalizer_node,
)
from autodev_ai.graphs import coding_providers
from autodev_ai.graphs.coding_providers import OPENSPEC_FLOW_STEPS, OpenSpecSkillProvider
from autodev_ai.models import CodingContext


def test_normalize_coding_plan_keeps_ordered_safe_tasks():
    raw = {
        "tasks": [
            {
                "id": "setup",
                "title": "搭建入口",
                "module_id": "core",
                "depends_on": [],
                "target_files": ["app/main.py", 42],
                "acceptance_checks": ["可以启动"],
                "implementation_notes": "先实现 FastAPI 入口",
            },
            {"id": "", "title": ""},
        ]
    }

    tasks = _normalize_coding_plan(raw)

    assert tasks == [
        {
            "id": "setup",
            "title": "搭建入口",
            "module_id": "core",
            "depends_on": [],
            "target_files": ["app/main.py"],
            "acceptance_checks": ["可以启动"],
            "implementation_notes": "先实现 FastAPI 入口",
        }
    ]


def test_normalize_coding_plan_falls_back_for_invalid_response():
    tasks = _normalize_coding_plan({"tasks": "invalid"})

    assert tasks == [
        {
            "id": "implementation",
            "title": "按任务拆分方案生成核心实现",
            "module_id": "",
            "depends_on": [],
            "target_files": [],
            "acceptance_checks": ["生成的文件路径、模块关系和接口契约保持一致"],
            "implementation_notes": "LLM 未返回有效计划，回退到单步实现。",
        }
    ]


def test_openspec_flow_steps_are_centrally_defined():
    assert OPENSPEC_FLOW_STEPS["propose"] == "正在使用 OpenSpec 模式生成提案"
    assert OPENSPEC_FLOW_STEPS["docs"] == "正在使用 OpenSpec 模式生成文档"
    assert OPENSPEC_FLOW_STEPS["apply"] == "正在使用 OpenSpec 模式执行实现"


def test_openspec_project_root_defaults_to_generated_project_workspace(tmp_path, monkeypatch):
    monkeypatch.setenv("AUTODEV_GENERATED_PROJECTS_ROOT", str(tmp_path / "generated"))
    monkeypatch.delenv("AUTODEV_PROJECT_ROOT", raising=False)
    ctx = CodingContext(
        project_id="project-1",
        project_name="Demo",
        task_breakdown={},
    )

    root = coding_providers._resolve_project_root(ctx=ctx)

    assert root == (tmp_path / "generated" / "project-1").resolve()
    assert root != coding_providers._platform_repo_root()


def test_openspec_project_root_rejects_autodev_platform_repo():
    ctx = CodingContext(
        project_id="project-1",
        project_name="Demo",
        task_breakdown={},
        project_workspace=str(coding_providers._platform_repo_root() / "tmp-generated-project"),
    )

    with pytest.raises(RuntimeError, match="不能位于 AutoDev 平台仓库内"):
        coding_providers._resolve_project_root(ctx=ctx)


@pytest.mark.anyio
async def test_document_provider_node_uses_injected_provider():
    class FakeProvider:
        async def run(self, *, ctx, cfg, tasks, event_sink=None):
            return {
                "coding_reply": "已按 OpenSpec apply 完成实现",
                "deltas": ["openspec:task-1:archived"],
                "openspec_tasks": [
                    {
                        "task_id": "task-1",
                        "title": "账号登录",
                        "change_id": "add-login",
                        "proposal_md": "# Proposal",
                        "design_md": "# Design",
                        "tasks_md": "# Tasks",
                        "review_iterations": 1,
                        "review_result": {"approved": True},
                        "archive_note": "已归档",
                        "archived": True,
                    }
                ],
            }

    result = await document_provider_node(
        {
            "context": CodingContext(
                project_id="project-1",
                project_name="Demo",
                task_breakdown={"prd": {"summary": "PRD"}},
            ),
            "config": ModelConfig(api_key="test", base_url="http://example.test", model="test"),
            "coding_plan": [{"id": "task-1", "title": "账号登录"}],
        },
        provider=FakeProvider(),
    )

    assert result["coding_reply"] == "已按 OpenSpec apply 完成实现"
    assert result["deltas"] == ["openspec:task-1:archived"]
    assert result["openspec_tasks"][0]["proposal_md"] == "# Proposal"


@pytest.mark.anyio
async def test_coding_graph_awaits_injected_document_provider(monkeypatch):
    async def fake_planner_node(state):
        return {"coding_plan": [{"id": "task-1", "title": "账号登录"}]}

    async def fake_synthesizer_node(state):
        return {
            "structured": {
                "summary": "完成",
                "code_files": [],
            }
        }

    class FakeProvider:
        async def run(self, *, ctx, cfg, tasks, event_sink=None):
            if event_sink is not None:
                event_sink("coding: 正在使用 OpenSpec 模式执行实现：账号登录")
            return {
                "coding_reply": "已完成账号登录实现",
                "deltas": ["coding: 正在使用 OpenSpec 模式执行实现：账号登录"],
                "openspec_tasks": [],
            }

    monkeypatch.setattr(coding_module, "planner_node", fake_planner_node)
    monkeypatch.setattr(coding_module, "synthesizer_node", fake_synthesizer_node)

    graph = coding_module.build_coding_graph(provider=FakeProvider())
    result = await graph.ainvoke(
        {
            "context": CodingContext(
                project_id="project-1",
                project_name="Demo",
                task_breakdown={"prd": {"summary": "PRD"}},
            ),
            "config": ModelConfig(api_key="test", base_url="http://example.test", model="test"),
            "deltas": [],
            "structured": {},
            "error": None,
        }
    )

    assert result["result"].summary == "完成"
    assert result["coding_reply"] == "已完成账号登录实现"
    assert result["deltas"] == ["coding: 正在使用 OpenSpec 模式执行实现：账号登录"]

    custom_events = []
    async for mode, chunk in graph.astream(
        {
            "context": CodingContext(
                project_id="project-1",
                project_name="Demo",
                task_breakdown={"prd": {"summary": "PRD"}},
            ),
            "config": ModelConfig(api_key="test", base_url="http://example.test", model="test"),
            "deltas": [],
            "structured": {},
            "error": None,
        },
        stream_mode=["custom", "updates"],
    ):
        if mode == "custom":
            custom_events.append(chunk)

    assert custom_events == [
        {
            "type": "workflow_log",
            "stage": "coding",
            "detail": "coding: 正在使用 OpenSpec 模式执行实现：账号登录",
        }
    ]


@pytest.mark.anyio
async def test_normalizer_preserves_openspec_task_artifacts():
    result = await normalizer_node(
        {
            "structured": {
                "summary": "完成",
                "code_files": [
                    {
                        "path": "app/main.py",
                        "content": "print('ok')",
                        "language": "python",
                        "module_id": "app",
                        "purpose": "入口",
                    }
                ],
            },
            "openspec_tasks": [
                {
                    "task_id": "task-1",
                    "title": "账号登录",
                    "change_id": "add-login",
                    "proposal_md": "# Proposal",
                    "design_md": "# Design",
                    "tasks_md": "# Tasks",
                    "review_iterations": 2,
                    "review_result": {"approved": True},
                    "archive_note": "已归档",
                    "archived": True,
                }
            ],
        }
    )

    coding_result = result["result"]
    assert coding_result.openspec_tasks[0]["change_id"] == "add-login"
    assert coding_result.openspec_tasks[0]["archived"] is True


@pytest.mark.anyio
async def test_openspec_provider_persists_and_archives_docs(tmp_path, monkeypatch):
    skill_root = tmp_path / ".codex" / "skills"
    for name in ("openspec-propose", "openspec-apply-change", "openspec-archive-change"):
        path = skill_root / name
        path.mkdir(parents=True)
        (path / "SKILL.md").write_text(f"# {name}", encoding="utf-8")

    async def fake_json_llm(*args, run_name, **kwargs):
        if run_name in {"openspec_propose", "openspec_revise"}:
            return {
                "change_id": "Add Login",
                "proposal_md": "# Proposal",
                "design_md": "# Design",
                "tasks_md": "# Tasks",
            }
        return {"approved": True, "summary": "ok"}

    async def fake_text_llm(*args, run_name, **kwargs):
        return "archive ok" if run_name == "openspec_archive" else "implemented files"

    monkeypatch.setattr(coding_providers, "_json_llm", fake_json_llm)
    monkeypatch.setattr(coding_providers, "_text_llm", fake_text_llm)

    provider = OpenSpecSkillProvider(skill_root=skill_root, project_root=tmp_path)
    result = await provider.run(
        ctx=CodingContext(
            project_id="project-1",
            project_name="Demo",
            task_breakdown={"prd": {"summary": "PRD"}},
        ),
        cfg=ModelConfig(api_key="test", base_url="http://example.test", model="test"),
        tasks=[{"id": "task-1", "title": "账号登录"}],
    )

    archive_dir = tmp_path / "openspec" / "changes" / "archive"
    archived = next(archive_dir.glob("*-add-login"))
    assert (archived / "proposal.md").read_text(encoding="utf-8") == "# Proposal"
    assert (archived / "design.md").read_text(encoding="utf-8") == "# Design"
    assert (archived / "tasks.md").read_text(encoding="utf-8") == "# Tasks"
    assert (archived / "archive_note.md").read_text(encoding="utf-8") == "archive ok"
    assert not (tmp_path / "openspec" / "changes" / "add-login").exists()
    assert result["openspec_tasks"][0]["archive_dir"] == str(archived)
    assert result["deltas"][0] == "coding: 正在初始化 OpenSpec 环境"
    assert "coding: 正在使用 OpenSpec 模式生成提案：账号登录" in result["deltas"]
    assert "coding: 正在使用 OpenSpec 模式生成文档：账号登录" in result["deltas"]
    assert "coding: 正在使用 OpenSpec 模式执行实现：账号登录" in result["deltas"]
    assert all("# Proposal" not in event for event in result["deltas"])

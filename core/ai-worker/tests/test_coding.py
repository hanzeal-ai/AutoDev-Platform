"""Tests for coding graph planning helpers."""

from autodev_ai.graphs.coding import _normalize_coding_plan


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

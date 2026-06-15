"""Tests for the standalone LangGraph Studio entrypoint."""

import importlib
import json
from pathlib import Path


def test_studio_module_exposes_compiled_graphs():
    studio = importlib.import_module("autodev_ai.studio")

    for name in (
        "chat_graph",
        "report_graph",
        "stage_graph",
        "prd_graph",
        "development_graph",
        "coding_graph",
        "workflow_graph",
    ):
        graph = getattr(studio, name)
        assert hasattr(graph, "ainvoke")


def test_langgraph_json_points_to_studio_entrypoint():
    repo_root = Path(__file__).resolve().parents[3]
    config = json.loads((repo_root / "langgraph.json").read_text())

    assert config["dependencies"] == ["./core/ai-worker"]
    assert config["env"] == ".env"
    assert config["graphs"]["chat"] == "autodev_ai.studio:chat_graph"
    assert config["graphs"]["coding"] == "autodev_ai.studio:coding_graph"
    assert config["graphs"]["workflow"] == "autodev_ai.studio:workflow_graph"

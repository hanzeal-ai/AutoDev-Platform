"""Tests for the unified AutoDev workflow graph."""

import pytest

from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver

from autodev_ai.workflow import (
    build_workflow_graph,
    get_workflow_checkpoint_path,
    workflow_config,
)


@pytest.mark.anyio
async def test_workflow_graph_runs_full_sequence_with_fake_nodes():
    async def chat(state):
        return {
            "events": state.get("events", []) + ["chat"],
            "chat_result": {"assistant_reply": "ok", "report_patch": {"project_name": "Demo"}},
            "draft": {"project_name": "Demo"},
            "awaiting_user_input": False,
            "current_phase": "chat_complete",
        }

    async def step(name, result_key, phase, state):
        return {
            "events": state.get("events", []) + [name],
            result_key: {"ok": name},
            "current_phase": phase,
        }

    def make_step(name, result_key, phase):
        async def node(state):
            return await step(name, result_key, phase, state)

        return node

    graph = build_workflow_graph(
        node_overrides={
            "chat": chat,
            "report": make_step("report", "feasibility_report", "report_complete"),
            "prd": make_step("prd", "prd_result", "prd_complete"),
            "development": make_step("development", "development_plan", "development_complete"),
            "coding": make_step("coding", "coding_result", "coding_complete"),
        }
    )

    result = await graph.ainvoke({"workflow_id": "wf-1", "thread_id": "thread-1"})

    assert result["events"] == ["chat", "report", "prd", "development", "coding"]
    assert result["current_phase"] == "coding_complete"
    assert result["coding_result"] == {"ok": "coding"}


@pytest.mark.anyio
async def test_workflow_graph_stops_when_chat_needs_user_input():
    async def chat(state):
        return {
            "events": ["chat"],
            "chat_result": {"assistant_reply": "请补充目标用户", "report_patch": {}},
            "awaiting_user_input": True,
            "current_phase": "awaiting_user_input",
        }

    async def should_not_run(state):
        raise AssertionError("downstream node should not run")

    graph = build_workflow_graph(
        node_overrides={
            "chat": chat,
            "report": should_not_run,
            "prd": should_not_run,
            "development": should_not_run,
            "coding": should_not_run,
        }
    )

    result = await graph.ainvoke({"workflow_id": "wf-2", "thread_id": "thread-2"})

    assert result["events"] == ["chat"]
    assert result["awaiting_user_input"] is True
    assert result["current_phase"] == "awaiting_user_input"


@pytest.mark.anyio
async def test_workflow_graph_stops_after_phase_error():
    async def chat(state):
        return {
            "chat_result": {"assistant_reply": "ok", "report_patch": {"project_name": "Demo"}},
            "draft": {"project_name": "Demo"},
            "awaiting_user_input": False,
            "current_phase": "chat_complete",
        }

    async def report(state):
        return {"feasibility_report": {"project_name": "Demo"}, "current_phase": "report_complete"}

    async def prd(state):
        return {"error": "prd failed", "current_phase": "prd_failed"}

    async def should_not_run(state):
        raise AssertionError("downstream node should not run after error")

    graph = build_workflow_graph(
        node_overrides={
            "chat": chat,
            "report": report,
            "prd": prd,
            "development": should_not_run,
            "coding": should_not_run,
        }
    )

    result = await graph.ainvoke({"workflow_id": "wf-error", "thread_id": "thread-error"})

    assert result["error"] == "prd failed"
    assert result["current_phase"] == "prd_failed"


@pytest.mark.anyio
async def test_sqlite_checkpoint_resume_retries_only_failed_coding_node(tmp_path):
    counters = {"chat": 0, "report": 0, "prd": 0, "development": 0, "coding": 0}

    async def chat(state):
        counters["chat"] += 1
        return {
            "chat_result": {"assistant_reply": "ok", "report_patch": {"project_name": "Demo"}},
            "draft": {"project_name": "Demo"},
            "awaiting_user_input": False,
            "current_phase": "chat_complete",
        }

    async def report(state):
        counters["report"] += 1
        return {"feasibility_report": {"project_name": "Demo"}, "current_phase": "report_complete"}

    async def prd(state):
        counters["prd"] += 1
        return {"prd_result": {"summary": "prd"}, "current_phase": "prd_complete"}

    async def development(state):
        counters["development"] += 1
        return {"development_plan": {"modules": []}, "current_phase": "development_complete"}

    async def failing_coding(state):
        counters["coding"] += 1
        raise RuntimeError("coding interrupted")

    db_path = tmp_path / "workflow.sqlite"
    config = workflow_config("wf-resume")

    async with AsyncSqliteSaver.from_conn_string(str(db_path)) as checkpointer:
        graph = build_workflow_graph(
            checkpointer=checkpointer,
            node_overrides={
                "chat": chat,
                "report": report,
                "prd": prd,
                "development": development,
                "coding": failing_coding,
            },
        )
        with pytest.raises(RuntimeError, match="coding interrupted"):
            await graph.ainvoke({"workflow_id": "wf-resume", "thread_id": "thread"}, config=config)

    assert counters == {"chat": 1, "report": 1, "prd": 1, "development": 1, "coding": 1}

    async def successful_coding(state):
        counters["coding"] += 1
        return {"coding_result": {"summary": "done"}, "current_phase": "coding_complete"}

    async with AsyncSqliteSaver.from_conn_string(str(db_path)) as checkpointer:
        graph = build_workflow_graph(
            checkpointer=checkpointer,
            node_overrides={
                "chat": chat,
                "report": report,
                "prd": prd,
                "development": development,
                "coding": successful_coding,
            },
        )
        result = await graph.ainvoke(None, config=config)

    assert result["coding_result"] == {"summary": "done"}
    assert counters == {"chat": 1, "report": 1, "prd": 1, "development": 1, "coding": 2}


def test_default_checkpoint_path_lives_under_ai_worker(monkeypatch):
    monkeypatch.delenv("AI_WORKFLOW_CHECKPOINT_PATH", raising=False)

    path = get_workflow_checkpoint_path()

    assert path.name == "autodev_workflow.sqlite"
    assert path.parent.name == ".checkpoints"

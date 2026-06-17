"""Tests for the unified AutoDev workflow graph."""

import pytest

from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver

from autodev_ai.workflow import (
    build_workflow_graph,
    build_workflow_status,
    build_workflow_artifact,
    get_workflow_checkpoint_path,
    _phase_result,
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

    def make_review_step(name, result_key, phase):
        async def node(state):
            return {
                "events": state.get("events", []) + [name],
                result_key: {"approved": True, "summary": f"{name} passed", "issues": []},
                "current_phase": phase,
            }

        return node

    graph = build_workflow_graph(
        node_overrides={
            "chat": chat,
            "report": make_step("report", "feasibility_report", "report_complete"),
            "prd": make_step("prd", "prd_result", "prd_complete"),
            "prd_review": make_review_step(
                "prd_review",
                "prd_review_result",
                "prd_review_complete",
            ),
            "development": make_step("development", "development_plan", "development_complete"),
            "coding": make_step("coding", "coding_result", "coding_complete"),
            "code_review": make_review_step(
                "code_review",
                "code_review_result",
                "code_review_complete",
            ),
            "summary": make_step("summary", "workflow_summary", "workflow_complete"),
        }
    )

    result = await graph.ainvoke({"workflow_id": "wf-1", "thread_id": "thread-1"})

    assert result["events"] == [
        "chat",
        "report",
        "prd",
        "prd_review",
        "development",
        "coding",
        "code_review",
        "summary",
    ]
    assert result["current_phase"] == "workflow_complete"
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
            "prd_review": should_not_run,
            "development": should_not_run,
            "coding": should_not_run,
            "code_review": should_not_run,
            "summary": should_not_run,
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
            "prd_review": should_not_run,
            "development": should_not_run,
            "coding": should_not_run,
            "code_review": should_not_run,
            "summary": should_not_run,
        }
    )

    result = await graph.ainvoke({"workflow_id": "wf-error", "thread_id": "thread-error"})

    assert result["error"] == "prd failed"
    assert result["current_phase"] == "prd_failed"


@pytest.mark.anyio
async def test_workflow_graph_loops_prd_until_review_passes():
    counters = {"prd": 0, "prd_review": 0}

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
        counters["prd"] += 1
        return {
            "prd_result": {"summary": f"prd-{counters['prd']}"},
            "current_phase": "prd_complete",
        }

    async def prd_review(state):
        counters["prd_review"] += 1
        approved = counters["prd_review"] == 2
        return {
            "prd_review_iteration": counters["prd_review"],
            "prd_review_result": {
                "approved": approved,
                "requires_user_input": False,
                "summary": "ok" if approved else "needs repair",
                "issues": [],
                "required_changes": [] if approved else ["补充验收标准"],
            },
            "current_phase": "prd_review_complete" if approved else "prd_review_revision_required",
        }

    async def development(state):
        return {"development_plan": {"modules": []}, "current_phase": "development_complete"}

    async def coding(state):
        return {"coding_result": {"summary": "done"}, "current_phase": "coding_complete"}

    async def code_review(state):
        return {
            "code_review_iteration": 1,
            "code_review_result": {"approved": True, "summary": "pass", "issues": []},
            "current_phase": "code_review_complete",
        }

    async def summary(state):
        return {"workflow_summary": {"status": "completed"}, "current_phase": "workflow_complete"}

    graph = build_workflow_graph(
        node_overrides={
            "chat": chat,
            "report": report,
            "prd": prd,
            "prd_review": prd_review,
            "development": development,
            "coding": coding,
            "code_review": code_review,
            "summary": summary,
        }
    )

    result = await graph.ainvoke({"workflow_id": "wf-prd-loop", "thread_id": "thread"})

    assert counters == {"prd": 2, "prd_review": 2}
    assert result["prd_result"] == {"summary": "prd-2"}
    assert result["current_phase"] == "workflow_complete"


@pytest.mark.anyio
async def test_workflow_graph_loops_coding_until_review_passes():
    counters = {"coding": 0, "code_review": 0}

    async def step(result_key, phase, value=None):
        async def node(state):
            return {result_key: value or {}, "current_phase": phase}

        return node

    async def chat(state):
        return {
            "chat_result": {"assistant_reply": "ok", "report_patch": {"project_name": "Demo"}},
            "draft": {"project_name": "Demo"},
            "awaiting_user_input": False,
            "current_phase": "chat_complete",
        }

    async def coding(state):
        counters["coding"] += 1
        return {
            "coding_result": {"summary": f"coding-{counters['coding']}"},
            "current_phase": "coding_complete",
        }

    async def code_review(state):
        counters["code_review"] += 1
        approved = counters["code_review"] == 3
        return {
            "code_review_iteration": counters["code_review"],
            "code_review_result": {
                "approved": approved,
                "summary": "pass" if approved else "fix required",
                "issues": [],
                "required_changes": [] if approved else ["修复未覆盖的验收标准"],
            },
            "current_phase": (
                "code_review_complete" if approved else "code_review_revision_required"
            ),
        }

    async def summary(state):
        return {"workflow_summary": {"status": "completed"}, "current_phase": "workflow_complete"}

    graph = build_workflow_graph(
        node_overrides={
            "chat": chat,
            "report": await step(
                "feasibility_report",
                "report_complete",
                {"project_name": "Demo"},
            ),
            "prd": await step("prd_result", "prd_complete", {"summary": "prd"}),
            "prd_review": await step(
                "prd_review_result",
                "prd_review_complete",
                {"approved": True},
            ),
            "development": await step(
                "development_plan",
                "development_complete",
                {"modules": []},
            ),
            "coding": coding,
            "code_review": code_review,
            "summary": summary,
        }
    )

    result = await graph.ainvoke({"workflow_id": "wf-code-loop", "thread_id": "thread"})

    assert counters == {"coding": 3, "code_review": 3}
    assert result["coding_result"] == {"summary": "coding-3"}
    assert result["current_phase"] == "workflow_complete"


@pytest.mark.anyio
async def test_workflow_graph_blocks_after_code_review_limit():
    async def chat(state):
        return {
            "chat_result": {"assistant_reply": "ok", "report_patch": {"project_name": "Demo"}},
            "draft": {"project_name": "Demo"},
            "awaiting_user_input": False,
            "current_phase": "chat_complete",
        }

    async def passthrough(result_key, phase, value):
        async def node(state):
            return {result_key: value, "current_phase": phase}

        return node

    async def code_review(state):
        iteration = state.get("code_review_iteration", 0) + 1
        return {
            "code_review_iteration": iteration,
            "code_review_result": {
                "approved": False,
                "summary": "still broken",
                "issues": [],
                "required_changes": ["继续修复"],
            },
            "current_phase": (
                "code_review_blocked"
                if iteration >= state.get("max_code_review_iterations", 3)
                else "code_review_revision_required"
            ),
        }

    async def should_not_run(state):
        raise AssertionError("summary should not run when review is blocked")

    graph = build_workflow_graph(
        node_overrides={
            "chat": chat,
            "report": await passthrough(
                "feasibility_report",
                "report_complete",
                {"project_name": "Demo"},
            ),
            "prd": await passthrough("prd_result", "prd_complete", {"summary": "prd"}),
            "prd_review": await passthrough(
                "prd_review_result",
                "prd_review_complete",
                {"approved": True},
            ),
            "development": await passthrough(
                "development_plan",
                "development_complete",
                {"modules": []},
            ),
            "coding": await passthrough("coding_result", "coding_complete", {"summary": "done"}),
            "code_review": code_review,
            "summary": should_not_run,
        }
    )

    result = await graph.ainvoke({
        "workflow_id": "wf-code-blocked",
        "thread_id": "thread",
        "max_code_review_iterations": 2,
    })

    assert result["code_review_iteration"] == 2
    assert result["current_phase"] == "code_review_blocked"


@pytest.mark.anyio
async def test_sqlite_checkpoint_resume_retries_only_failed_coding_node(tmp_path):
    counters = {
        "chat": 0,
        "report": 0,
        "prd": 0,
        "prd_review": 0,
        "development": 0,
        "coding": 0,
        "code_review": 0,
        "summary": 0,
    }

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

    async def prd_review(state):
        counters["prd_review"] += 1
        return {
            "prd_review_result": {"approved": True, "summary": "pass", "issues": []},
            "prd_review_iteration": 1,
            "current_phase": "prd_review_complete",
        }

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
                "prd_review": prd_review,
                "development": development,
                "coding": failing_coding,
            },
        )
        with pytest.raises(RuntimeError, match="coding interrupted"):
            await graph.ainvoke({"workflow_id": "wf-resume", "thread_id": "thread"}, config=config)

    assert counters == {
        "chat": 1,
        "report": 1,
        "prd": 1,
        "prd_review": 1,
        "development": 1,
        "coding": 1,
        "code_review": 0,
        "summary": 0,
    }

    async def successful_coding(state):
        counters["coding"] += 1
        return {"coding_result": {"summary": "done"}, "current_phase": "coding_complete"}

    async def code_review(state):
        counters["code_review"] += 1
        return {
            "code_review_result": {"approved": True, "summary": "pass", "issues": []},
            "code_review_iteration": 1,
            "current_phase": "code_review_complete",
        }

    async def summary(state):
        counters["summary"] += 1
        return {"workflow_summary": {"status": "completed"}, "current_phase": "workflow_complete"}

    async with AsyncSqliteSaver.from_conn_string(str(db_path)) as checkpointer:
        graph = build_workflow_graph(
            checkpointer=checkpointer,
            node_overrides={
                "chat": chat,
                "report": report,
                "prd": prd,
                "prd_review": prd_review,
                "development": development,
                "coding": successful_coding,
                "code_review": code_review,
                "summary": summary,
            },
        )
        result = await graph.ainvoke(None, config=config)

    assert result["coding_result"] == {"summary": "done"}
    assert result["current_phase"] == "workflow_complete"
    assert counters == {
        "chat": 1,
        "report": 1,
        "prd": 1,
        "prd_review": 1,
        "development": 1,
        "coding": 2,
        "code_review": 1,
        "summary": 1,
    }


def test_default_checkpoint_path_lives_under_ai_worker(monkeypatch):
    monkeypatch.delenv("AI_WORKFLOW_CHECKPOINT_PATH", raising=False)

    path = get_workflow_checkpoint_path()

    assert path.name == "autodev_workflow.sqlite"
    assert path.parent.name == ".checkpoints"


def test_workflow_status_exposes_phase_state_and_artifact_ids_without_payloads():
    state = {
        "workflow_id": "wf-1",
        "thread_id": "thread-1",
        "project_id": "project-1",
        "project_name": "Demo",
        "current_phase": "development_complete",
        "awaiting_user_input": False,
        "feasibility_report": {"summary": "可行"},
        "prd_result": {"summary": "PRD"},
        "development_plan": {"summary": "研发计划"},
    }

    status = build_workflow_status(state)

    assert status["workflow_id"] == "wf-1"
    assert status["project_id"] == "project-1"
    assert status["current_phase"] == "development_complete"
    assert status["current_step"] == "development"
    assert status["status"] == "running"
    assert status["phases"]["report"]["status"] == "completed"
    assert status["phases"]["report"]["artifact_id"] == "wf-1:report"
    assert status["phases"]["prd"]["artifact_id"] == "wf-1:prd"
    assert status["phases"]["development"]["artifact_id"] == "wf-1:development"
    assert status["phases"]["coding"]["status"] == "pending"
    assert "feasibility_report" not in status
    assert "development_plan" not in status


def test_workflow_artifact_returns_payload_by_id():
    state = {
        "workflow_id": "wf-1",
        "project_id": "project-1",
        "feasibility_report": {"summary": "可行"},
    }

    artifact = build_workflow_artifact(state, "wf-1:report")

    assert artifact == {
        "artifact_id": "wf-1:report",
        "workflow_id": "wf-1",
        "project_id": "project-1",
        "stage": "report",
        "name": "可行性分析报告",
        "kind": "workflow-report",
        "content_type": "application/json",
        "content": {"summary": "可行"},
    }


def test_workflow_artifact_rejects_unknown_or_unavailable_artifact():
    state = {
        "workflow_id": "wf-1",
        "project_id": "project-1",
        "feasibility_report": {"summary": "可行"},
    }

    assert build_workflow_artifact(state, "wf-1:missing") is None
    assert build_workflow_artifact(state, "wf-2:report") is None


def test_phase_result_raises_on_worker_error_for_checkpoint_resume():
    with pytest.raises(RuntimeError, match="coding interrupted"):
        _phase_result(
            {"error": "coding interrupted"},
            "coding_result",
            "coding_complete",
        )

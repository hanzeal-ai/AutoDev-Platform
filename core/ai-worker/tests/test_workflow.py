"""Tests for the unified AutoDev workflow graph."""

import pytest

from langgraph.checkpoint.sqlite.aio import AsyncSqliteSaver

from autodev_ai.workflow import (
    build_workflow_graph,
    build_workflow_status,
    build_workflow_events,
    build_workflow_artifact,
    chat_node,
    report_node,
    prd_node,
    development_node,
    coding_node,
    prd_review_node,
    code_review_node,
    get_workflow_checkpoint_path,
    resume_workflow,
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
async def test_workflow_graph_stops_after_report_error():
    async def chat(state):
        return {
            "chat_result": {"assistant_reply": "ok", "report_patch": {"project_name": "Demo"}},
            "draft": {"project_name": "Demo"},
            "awaiting_user_input": False,
            "current_phase": "chat_complete",
        }

    async def report(state):
        return {"error": "report failed", "current_phase": "report_failed"}

    async def should_not_run(state):
        raise AssertionError("prd should not run after report error")

    graph = build_workflow_graph(
        node_overrides={
            "chat": chat,
            "report": report,
            "prd": should_not_run,
            "prd_review": should_not_run,
            "development": should_not_run,
            "coding": should_not_run,
            "code_review": should_not_run,
            "summary": should_not_run,
        }
    )

    result = await graph.ainvoke({"workflow_id": "wf-report-error", "thread_id": "thread"})

    assert result["error"] == "report failed"
    assert result["current_phase"] == "report_failed"


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
    assert status["current_step"] == "coding"
    assert status["status"] == "running"
    assert status["phases"]["report"]["status"] == "completed"
    assert status["phases"]["report"]["artifact_id"] == "wf-1:report"
    assert status["phases"]["prd"]["artifact_id"] == "wf-1:prd"
    assert status["phases"]["development"]["artifact_id"] == "wf-1:development"
    assert status["phases"]["coding"]["status"] == "running"
    assert "feasibility_report" not in status
    assert "development_plan" not in status


def test_workflow_events_exposes_node_progress_and_raw_logs_without_artifact_payloads():
    state = {
        "workflow_id": "wf-1",
        "thread_id": "thread-1",
        "project_id": "project-1",
        "project_name": "Demo",
        "current_phase": "coding_complete",
        "events": ["report: 可行性分析报告已生成", "tool:file_search"],
        "feasibility_report": {"summary": "可行"},
        "prd_result": {"summary": "PRD"},
        "development_plan": {"summary": "研发计划"},
        "coding_result": {"summary": "代码完成"},
    }

    payload = build_workflow_events(state)

    assert payload["workflow_id"] == "wf-1"
    assert payload["current_step"] == "code_review"
    assert payload["status"] == "running"
    events = payload["events"]
    assert [event["stage"] for event in events[:8]] == [
        "chat",
        "report",
        "prd",
        "prd_review",
        "development",
        "coding",
        "code_review",
        "summary",
    ]
    assert events[1]["status"] == "completed"
    assert events[1]["artifact_id"] == "wf-1:report"
    assert events[5]["status"] == "completed"
    assert events[5]["artifact_id"] == "wf-1:coding"
    assert events[6]["status"] == "running"
    assert events[-2]["type"] == "log"
    assert events[-2]["stage"] == "report"
    assert events[-2]["detail"] == "report: 可行性分析报告已生成"
    assert events[-1]["stage"] == "code_review"
    assert "feasibility_report" not in payload
    assert "coding_result" not in payload


def test_workflow_status_advances_active_step_after_completed_checkpoint():
    status = build_workflow_status(
        {
            "workflow_id": "wf-active",
            "current_phase": "chat_complete",
            "awaiting_user_input": False,
            "chat_result": {"assistant_reply": "ok"},
        }
    )

    assert status["current_step"] == "report"
    assert status["phases"]["chat"]["status"] == "completed"
    assert status["phases"]["report"]["status"] == "running"


def test_workflow_status_grays_downstream_after_code_review_revision():
    status = build_workflow_status(
        {
            "workflow_id": "wf-review",
            "project_id": "project-review",
            "current_phase": "code_review_revision_required",
            "development_plan": {"summary": "研发计划"},
            "coding_result": {"summary": "第一轮代码"},
            "code_review_iteration": 1,
            "code_review_result": {
                "approved": False,
                "summary": "账号登录模块缺失",
                "issues": [{"description": "未实现登录 API"}],
            },
        }
    )

    assert status["current_step"] == "coding"
    assert status["phases"]["coding"]["status"] == "running"
    assert status["phases"]["coding"]["artifact_id"] == "wf-review:coding"
    assert status["phases"]["coding"]["name"] == "第 2 轮代码开发"
    assert status["phases"]["code_review"]["status"] == "pending"
    assert status["phases"]["code_review"]["artifact_id"] is None
    assert status["phases"]["code_review"]["name"] == "第 1 轮代码评审"
    assert status["phases"]["summary"]["status"] == "pending"
    assert status["phases"]["summary"]["artifact_id"] is None


def test_workflow_events_include_blocked_review_reason():
    payload = build_workflow_events(
        {
            "workflow_id": "wf-blocked",
            "current_phase": "code_review_blocked",
            "coding_result": {"summary": "代码完成"},
            "code_review_iteration": 4,
            "code_review_result": {
                "approved": False,
                "summary": "账号模块仍未完成",
                "required_changes": ["补齐登录 API", "补齐会话持久化"],
                "issues": [{"description": "缺少权限校验"}],
            },
        }
    )

    event = next(item for item in payload["events"] if item["stage"] == "code_review" and item["type"] == "phase")
    assert event["status"] == "blocked"
    assert event["title"] == "第 4 轮代码评审"
    assert "已达到最大代码评审次数" in event["detail"]
    assert "代码审核不通过" in event["detail"]
    assert "账号模块仍未完成" in event["detail"]
    assert "补齐登录 API" in event["detail"]


@pytest.mark.anyio
async def test_report_node_converts_llm_error_to_failed_state(monkeypatch):
    async def fake_generate_report(ctx, cfg):
        raise RuntimeError("insufficient balance")

    monkeypatch.setattr("autodev_ai.workflow.generate_report", fake_generate_report)

    result = await report_node(
        {
            "thread_id": "thread-1",
            "draft": {"project_name": "Demo"},
            "messages": [],
            "materials": [],
            "events": ["chat: 需求澄清完成"],
        }
    )

    assert result["current_phase"] == "report_failed"
    assert result["error"] == "模型服务余额不足，请检查 API Key 对应账户余额或更换可用 Key。"
    assert result["events"][-1] == (
        "report: 执行失败：模型服务余额不足，请检查 API Key 对应账户余额或更换可用 Key。"
    )


@pytest.mark.anyio
async def test_report_node_normalizes_insufficient_balance_error(monkeypatch):
    raw_error = (
        "Error code: 402 - {'error': {'message': 'Insufficient Balance', "
        "'type': 'unknown_error', 'param': None, 'code': 'invalid_request_error'}}"
    )

    async def fake_generate_report(ctx, cfg):
        raise RuntimeError(raw_error)

    monkeypatch.setattr("autodev_ai.workflow.generate_report", fake_generate_report)

    result = await report_node(
        {
            "thread_id": "thread-1",
            "draft": {"project_name": "Demo"},
            "messages": [],
            "materials": [],
            "events": [],
        }
    )

    assert result["current_phase"] == "report_failed"
    assert result["error"] == "模型服务余额不足，请检查 API Key 对应账户余额或更换可用 Key。"
    assert result["events"][-1] == (
        "report: 执行失败：模型服务余额不足，请检查 API Key 对应账户余额或更换可用 Key。"
    )


@pytest.mark.anyio
async def test_coding_node_merges_openspec_step_events(monkeypatch):
    class FakeCodingGraph:
        async def ainvoke(self, worker_state):
            return {
                "result": {"summary": "ok", "code_files": []},
                "deltas": [
                    "coding: 正在使用 OpenSpec 模式生成提案：账号登录",
                    "coding: 正在使用 OpenSpec 模式生成文档：账号登录",
                    "coding: 正在使用 OpenSpec 模式执行实现：账号登录",
                ],
                "error": None,
            }

    monkeypatch.setattr("autodev_ai.workflow._coding_graph", FakeCodingGraph())
    monkeypatch.setenv("DEEPSEEK_API_KEY", "test")

    result = await coding_node(
        {
            "project_id": "project-1",
            "project_name": "Demo",
            "feasibility_report": {"project_name": "Demo"},
            "prd_result": {"summary": "PRD"},
            "development_plan": {"summary": "Plan"},
            "events": ["development: 研发计划已生成"],
        }
    )

    assert result["current_phase"] == "coding_complete"
    assert result["events"][-4:] == [
        "coding: 正在使用 OpenSpec 模式生成提案：账号登录",
        "coding: 正在使用 OpenSpec 模式生成文档：账号登录",
        "coding: 正在使用 OpenSpec 模式执行实现：账号登录",
        "coding: 代码生成阶段已完成",
    ]


@pytest.mark.anyio
@pytest.mark.parametrize(
    ("node_name", "node", "graph_attr", "expected_phase"),
    [
        ("prd", prd_node, "_prd_graph", "prd_failed"),
        ("development", development_node, "_development_graph", "development_failed"),
        ("coding", coding_node, "_coding_graph", "coding_failed"),
    ],
)
async def test_subgraph_nodes_convert_worker_errors_to_failed_state(
    monkeypatch,
    node_name,
    node,
    graph_attr,
    expected_phase,
):
    class FailingGraph:
        async def ainvoke(self, worker_state):
            raise RuntimeError(f"{node_name} interrupted")

    monkeypatch.setattr(f"autodev_ai.workflow.{graph_attr}", FailingGraph())

    result = await node(
        {
            "project_id": "project-1",
            "project_name": "Demo",
            "feasibility_report": {"project_name": "Demo"},
            "prd_result": {"summary": "PRD"},
            "development_plan": {"summary": "Plan"},
            "events": [],
        }
    )

    assert result["current_phase"] == expected_phase
    assert result["error"] == f"{node_name} interrupted"
    assert result["events"][-1] == f"{node_name}: 执行失败：{node_name} interrupted"


@pytest.mark.anyio
@pytest.mark.parametrize(
    ("node_name", "node", "expected_phase"),
    [
        ("prd_review", prd_review_node, "prd_review_failed"),
        ("code_review", code_review_node, "code_review_failed"),
    ],
)
async def test_review_nodes_convert_llm_errors_to_failed_state(
    monkeypatch,
    node_name,
    node,
    expected_phase,
):
    class FailingLLM:
        async def ainvoke(self, messages, config=None):
            raise RuntimeError(f"{node_name} unavailable")

    monkeypatch.setattr("autodev_ai.workflow.create_llm", lambda *args, **kwargs: FailingLLM())

    result = await node(
        {
            "project_id": "project-1",
            "project_name": "Demo",
            "feasibility_report": {"project_name": "Demo"},
            "prd_result": {"summary": "PRD"},
            "development_plan": {"summary": "Plan"},
            "coding_result": {"summary": "Code"},
            "events": [],
        }
    )

    assert result["current_phase"] == expected_phase
    assert result["error"] == f"{node_name} unavailable"
    assert result["events"][-1] == f"{node_name}: 执行失败：{node_name} unavailable"


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


@pytest.mark.anyio
async def test_chat_node_continues_when_existing_draft_is_complete_and_patch_is_empty(monkeypatch):
    class FakeChatResult:
        def model_dump(self):
            return {
                "assistant_reply": "现有信息已足够，可以继续生成可行性报告。",
                "report_patch": {},
            }

    async def fake_generate_chat(ctx, cfg):
        return FakeChatResult()

    monkeypatch.setattr("autodev_ai.workflow.generate_chat", fake_generate_chat)
    state = {
        "thread_id": "thread-1",
        "user_message": "小红书自动热点推文系统",
        "draft": {
            "project_name": "小红书自动热点推文系统",
            "problem_definition": "自动发现热点并生成推文",
            "target_users": "运营人员",
            "core_capabilities": ["热点抓取", "内容生成"],
            "risks_and_constraints": ["平台风控"],
            "initial_delivery_plan": "先做 MVP",
        },
        "messages": [],
        "materials": [],
    }

    result = await chat_node(state)

    assert result["awaiting_user_input"] is False
    assert result["current_phase"] == "chat_complete"
    assert result["events"] == [
        "chat: 准备执行需求澄清 Agent",
        "chat: 需求澄清完成",
    ]


@pytest.mark.anyio
async def test_resume_restarts_awaiting_chat_when_existing_draft_is_complete(monkeypatch):
    captured = {}
    state = {
        "workflow_id": "wf-ready",
        "thread_id": "thread-1",
        "current_phase": "awaiting_user_input",
        "awaiting_user_input": True,
        "draft": {
            "project_name": "Demo",
            "problem_definition": "Build a tool",
            "target_users": "Operators",
            "core_capabilities": ["Generate"],
        },
        "chat_result": {"assistant_reply": "信息足够", "report_patch": {}},
    }

    async def fake_get_checkpoint_state(workflow_id):
        return dict(state)

    async def fake_resume_persistent_workflow_after_node(next_state, workflow_id, node):
        captured["state"] = next_state
        captured["workflow_id"] = workflow_id
        captured["node"] = node
        return {"workflow_id": workflow_id, "status": "running"}

    monkeypatch.setattr("autodev_ai.workflow._get_checkpoint_state", fake_get_checkpoint_state)
    monkeypatch.setattr(
        "autodev_ai.workflow._resume_persistent_workflow_after_node",
        fake_resume_persistent_workflow_after_node,
    )

    result = await resume_workflow("wf-ready")

    assert result == {"workflow_id": "wf-ready", "status": "running"}
    assert captured["workflow_id"] == "wf-ready"
    assert captured["node"] == "chat"
    assert captured["state"]["awaiting_user_input"] is False
    assert captured["state"]["current_phase"] == "chat_complete"


@pytest.mark.anyio
async def test_resume_continues_after_completed_checkpoint(monkeypatch):
    captured = {}
    state = {
        "workflow_id": "wf-chat-complete",
        "thread_id": "thread-1",
        "current_phase": "chat_complete",
        "awaiting_user_input": False,
        "chat_result": {"assistant_reply": "信息足够", "report_patch": {}},
        "draft": {"project_name": "Demo"},
    }

    async def fake_get_checkpoint_state(workflow_id):
        return dict(state)

    async def fake_resume_persistent_workflow_after_node(next_state, workflow_id, node):
        captured["state"] = next_state
        captured["workflow_id"] = workflow_id
        captured["node"] = node
        return {"workflow_id": workflow_id, "status": "running"}

    monkeypatch.setattr("autodev_ai.workflow._get_checkpoint_state", fake_get_checkpoint_state)
    monkeypatch.setattr(
        "autodev_ai.workflow._resume_persistent_workflow_after_node",
        fake_resume_persistent_workflow_after_node,
    )

    result = await resume_workflow("wf-chat-complete")

    assert result == {"workflow_id": "wf-chat-complete", "status": "running"}
    assert captured["workflow_id"] == "wf-chat-complete"
    assert captured["node"] == "chat"
    assert captured["state"]["current_phase"] == "chat_complete"


@pytest.mark.anyio
async def test_resume_retries_failed_report_from_previous_checkpoint(monkeypatch):
    captured = {}
    state = {
        "workflow_id": "wf-report-failed",
        "thread_id": "thread-1",
        "current_phase": "report_failed",
        "awaiting_user_input": False,
        "error": "模型服务余额不足",
        "chat_result": {"assistant_reply": "信息足够", "report_patch": {}},
        "draft": {"project_name": "Demo"},
        "events": ["report: 执行失败：模型服务余额不足"],
    }

    async def fake_get_checkpoint_state(workflow_id):
        return dict(state)

    async def fake_resume_persistent_workflow_after_node(next_state, workflow_id, node):
        captured["state"] = next_state
        captured["workflow_id"] = workflow_id
        captured["node"] = node
        return {"workflow_id": workflow_id, "status": "running"}

    monkeypatch.setattr("autodev_ai.workflow._get_checkpoint_state", fake_get_checkpoint_state)
    monkeypatch.setattr(
        "autodev_ai.workflow._resume_persistent_workflow_after_node",
        fake_resume_persistent_workflow_after_node,
    )

    result = await resume_workflow("wf-report-failed")

    assert result == {"workflow_id": "wf-report-failed", "status": "running"}
    assert captured["workflow_id"] == "wf-report-failed"
    assert captured["node"] == "chat"
    assert captured["state"]["current_phase"] == "chat_complete"
    assert captured["state"]["error"] is None
    assert captured["state"]["events"][-1] == "report: 重新执行"


@pytest.mark.anyio
@pytest.mark.parametrize(
    ("failed_phase", "resume_node", "resume_phase", "retry_event"),
    [
        ("prd_failed", "report", "report_complete", "prd: 重新执行"),
        ("prd_review_failed", "prd", "prd_complete", "prd_review: 重新执行"),
        ("development_failed", "prd_review", "prd_review_complete", "development: 重新执行"),
        ("coding_failed", "development", "development_complete", "coding: 重新执行"),
        ("code_review_failed", "coding", "coding_complete", "code_review: 重新执行"),
        ("summary_failed", "code_review", "code_review_complete", "summary: 重新执行"),
    ],
)
async def test_resume_retries_failed_downstream_node(
    monkeypatch,
    failed_phase,
    resume_node,
    resume_phase,
    retry_event,
):
    captured = {}
    state = {
        "workflow_id": "wf-node-failed",
        "thread_id": "thread-1",
        "current_phase": failed_phase,
        "awaiting_user_input": False,
        "error": "temporary failure",
        "events": [f"{failed_phase}: 执行失败：temporary failure"],
    }

    async def fake_get_checkpoint_state(workflow_id):
        return dict(state)

    async def fake_resume_persistent_workflow_after_node(next_state, workflow_id, node):
        captured["state"] = next_state
        captured["workflow_id"] = workflow_id
        captured["node"] = node
        return {"workflow_id": workflow_id, "status": "running"}

    monkeypatch.setattr("autodev_ai.workflow._get_checkpoint_state", fake_get_checkpoint_state)
    monkeypatch.setattr(
        "autodev_ai.workflow._resume_persistent_workflow_after_node",
        fake_resume_persistent_workflow_after_node,
    )

    result = await resume_workflow("wf-node-failed")

    assert result == {"workflow_id": "wf-node-failed", "status": "running"}
    assert captured["node"] == resume_node
    assert captured["state"]["current_phase"] == resume_phase
    assert captured["state"]["error"] is None
    assert captured["state"]["events"][-1] == retry_event


@pytest.mark.anyio
async def test_resume_skips_current_node_and_continues(monkeypatch):
    captured = {}
    state = {
        "workflow_id": "wf-skip",
        "thread_id": "thread-1",
        "current_phase": "report_complete",
        "awaiting_user_input": False,
        "feasibility_report": {"summary": "可行"},
        "events": ["report: 可行性分析报告已生成"],
    }

    async def fake_get_checkpoint_state(workflow_id):
        return dict(state)

    async def fake_resume_persistent_workflow_after_node(next_state, workflow_id, node):
        captured["state"] = next_state
        captured["workflow_id"] = workflow_id
        captured["node"] = node
        return {"workflow_id": workflow_id, "status": "running"}

    monkeypatch.setattr("autodev_ai.workflow._get_checkpoint_state", fake_get_checkpoint_state)
    monkeypatch.setattr(
        "autodev_ai.workflow._resume_persistent_workflow_after_node",
        fake_resume_persistent_workflow_after_node,
    )

    result = await resume_workflow("wf-skip", action="skip")

    assert result == {"workflow_id": "wf-skip", "status": "running"}
    assert captured["node"] == "prd"
    assert captured["state"]["current_phase"] == "prd_complete"
    assert captured["state"]["prd_result"]["skipped"] is True
    assert captured["state"]["events"][-1] == "prd: 已跳过"


@pytest.mark.anyio
async def test_resume_reruns_current_node_from_previous_checkpoint(monkeypatch):
    captured = {}
    state = {
        "workflow_id": "wf-rerun",
        "thread_id": "thread-1",
        "current_phase": "coding_complete",
        "awaiting_user_input": False,
        "coding_result": {"summary": "代码已生成"},
        "events": ["coding: 代码生成阶段已完成"],
    }

    async def fake_get_checkpoint_state(workflow_id):
        return dict(state)

    async def fake_resume_persistent_workflow_after_node(next_state, workflow_id, node):
        captured["state"] = next_state
        captured["workflow_id"] = workflow_id
        captured["node"] = node
        return {"workflow_id": workflow_id, "status": "running"}

    monkeypatch.setattr("autodev_ai.workflow._get_checkpoint_state", fake_get_checkpoint_state)
    monkeypatch.setattr(
        "autodev_ai.workflow._resume_persistent_workflow_after_node",
        fake_resume_persistent_workflow_after_node,
    )

    result = await resume_workflow("wf-rerun", action="rerun")

    assert result == {"workflow_id": "wf-rerun", "status": "running"}
    assert captured["node"] == "coding"
    assert captured["state"]["current_phase"] == "coding_complete"
    assert "code_review_result" not in captured["state"]
    assert captured["state"]["events"][-1] == "code_review: 重新执行"


@pytest.mark.anyio
async def test_resume_retries_blocked_review_node(monkeypatch):
    captured = {}
    state = {
        "workflow_id": "wf-blocked",
        "thread_id": "thread-1",
        "current_phase": "code_review_blocked",
        "awaiting_user_input": False,
        "code_review_result": {"approved": False},
        "events": ["code_review: 第 3 轮代码评审阻塞"],
    }

    async def fake_get_checkpoint_state(workflow_id):
        return dict(state)

    async def fake_resume_persistent_workflow_after_node(next_state, workflow_id, node):
        captured["state"] = next_state
        captured["workflow_id"] = workflow_id
        captured["node"] = node
        return {"workflow_id": workflow_id, "status": "running"}

    monkeypatch.setattr("autodev_ai.workflow._get_checkpoint_state", fake_get_checkpoint_state)
    monkeypatch.setattr(
        "autodev_ai.workflow._resume_persistent_workflow_after_node",
        fake_resume_persistent_workflow_after_node,
    )

    result = await resume_workflow("wf-blocked", action="retry")

    assert result == {"workflow_id": "wf-blocked", "status": "running"}
    assert captured["node"] == "coding"
    assert captured["state"]["current_phase"] == "coding_complete"
    assert captured["state"]["error"] is None
    assert captured["state"]["events"][-1] == "code_review: 重新执行"


def test_phase_result_raises_on_worker_error_for_checkpoint_resume():
    with pytest.raises(RuntimeError, match="coding interrupted"):
        _phase_result(
            {"error": "coding interrupted"},
            "coding_result",
            "coding_complete",
        )

"""Shared workflow stage schema used by execution and projection layers."""

from __future__ import annotations

from .types import NodeName

DEFAULT_MAX_PRD_REVIEW_ITERATIONS = 2
DEFAULT_MAX_CODE_REVIEW_ITERATIONS = 3

WORKFLOW_ARTIFACTS: dict[str, dict[str, str]] = {
    "chat": {
        "state_key": "chat_result",
        "name": "需求澄清结果",
        "kind": "workflow-chat",
    },
    "report": {
        "state_key": "feasibility_report",
        "name": "可行性分析报告",
        "kind": "workflow-report",
    },
    "prd": {
        "state_key": "prd_result",
        "name": "产品需求文档",
        "kind": "workflow-prd",
    },
    "prd_review": {
        "state_key": "prd_review_result",
        "name": "需求评审",
        "kind": "workflow-prd-review",
    },
    "development": {
        "state_key": "development_plan",
        "name": "研发计划",
        "kind": "workflow-development-plan",
    },
    "coding": {
        "state_key": "coding_result",
        "name": "代码生成结果",
        "kind": "workflow-coding",
    },
    "code_review": {
        "state_key": "code_review_result",
        "name": "代码评审",
        "kind": "workflow-code-review",
    },
    "summary": {
        "state_key": "workflow_summary",
        "name": "项目完成总结",
        "kind": "workflow-summary",
    },
}

WORKFLOW_ORDER = tuple(WORKFLOW_ARTIFACTS.keys())

WORKFLOW_PREVIOUS_NODE: dict[str, NodeName] = {
    "report": "chat",
    "prd": "report",
    "prd_review": "prd",
    "development": "prd_review",
    "coding": "development",
    "code_review": "coding",
    "summary": "code_review",
}

WORKFLOW_NODE_COMPLETE_PHASE: dict[NodeName, str] = {
    "chat": "chat_complete",
    "report": "report_complete",
    "prd": "prd_complete",
    "prd_review": "prd_review_complete",
    "development": "development_complete",
    "coding": "coding_complete",
    "code_review": "code_review_complete",
    "summary": "workflow_complete",
}

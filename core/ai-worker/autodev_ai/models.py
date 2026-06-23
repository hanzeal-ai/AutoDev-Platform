"""Pydantic models — shared request/response schemas."""

from __future__ import annotations

import re

from pydantic import BaseModel, Field, field_validator

VALID_STAGES = {"feasibility", "prd", "ui", "development", "testing", "release", "maintenance"}
ID_PATTERN = re.compile(r"^[a-zA-Z0-9_-]{1,128}$")


# ---------- Stage Generation ----------

class StageContext(BaseModel):
    """Context passed from Rust daemon for stage AI generation."""
    project_id: str
    project_name: str = Field(max_length=256)
    stage: str
    objective: str = Field(default="", max_length=4096)
    input_contexts: list[str] = Field(default_factory=list)
    step_progress: list[dict] = Field(default_factory=list)
    risk_items: list[str] = Field(default_factory=list)
    event_flow: list[str] = Field(default_factory=list)
    primary_action: str = Field(default="", max_length=1024)
    secondary_actions: list[str] = Field(default_factory=list)
    work_units: list[dict] = Field(default_factory=list)
    feasibility: dict | None = None

    @field_validator("project_id")
    @classmethod
    def validate_project_id(cls, v: str) -> str:
        v = v.strip()
        if not v or not ID_PATTERN.match(v):
            raise ValueError("invalid project_id: must be alphanumeric with - or _")
        return v

    @field_validator("stage")
    @classmethod
    def validate_stage(cls, v: str) -> str:
        if v not in VALID_STAGES:
            raise ValueError(f"invalid stage: {v}, must be one of {VALID_STAGES}")
        return v

    @field_validator("project_name")
    @classmethod
    def validate_project_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("project_name must not be empty")
        return v


class WorkUnit(BaseModel):
    id: str = Field(max_length=128)
    title: str = Field(max_length=512)
    agent_role: str = Field(max_length=256)
    status: str = "queued"
    progress: float = 0.0
    depends_on: list[str] = Field(default_factory=list)
    current_output: str | None = Field(default=None, max_length=8192)
    next_step: str = Field(default="", max_length=1024)


class StepProgress(BaseModel):
    title: str = Field(max_length=512)
    status: str = "queued"


class StageResult(BaseModel):
    """Structured output from the synthesizer node."""
    objective: str = Field(max_length=4096)
    input_contexts: list[str] = Field(default_factory=list)
    step_progress: list[StepProgress] = Field(default_factory=list)
    risk_items: list[str] = Field(default_factory=list)
    event_flow: list[str] = Field(default_factory=list)
    primary_action: str = Field(default="", max_length=1024)
    secondary_actions: list[str] = Field(default_factory=list)
    work_units: list[WorkUnit] = Field(default_factory=list)


# ---------- Feasibility Report ----------

class ReportContext(BaseModel):
    """Context for feasibility report generation."""
    thread_id: str
    draft: dict = Field(default_factory=dict)
    messages: list[dict] = Field(default_factory=list)
    materials: list[dict] = Field(default_factory=list)

    @field_validator("thread_id")
    @classmethod
    def validate_thread_id(cls, v: str) -> str:
        v = v.strip()
        if not v or not ID_PATTERN.match(v):
            raise ValueError("invalid thread_id: must be alphanumeric with - or _")
        return v


class FeasibilityReport(BaseModel):
    project_name: str = Field(default="", max_length=256)
    problem_definition: str = Field(default="", max_length=4096)
    target_users: str = Field(default="", max_length=2048)
    core_capabilities: list[str] = Field(default_factory=list)
    risks_and_constraints: list[str] = Field(default_factory=list)
    initial_delivery_plan: list[str] = Field(default_factory=list)
    feasibility_conclusion: str = Field(default="", max_length=4096)


# ---------- Chat Clarification ----------

class ChatMessage(BaseModel):
    role: str = Field(max_length=32)
    content: str = Field(max_length=8192)


class ChatMaterial(BaseModel):
    name: str = Field(max_length=256)
    type_hint: str = Field(default="", max_length=128)
    size_hint: str = Field(default="", max_length=128)
    status: str = Field(default="", max_length=64)


class ChatContext(BaseModel):
    """Context for a single clarification turn in a creation thread."""
    thread_id: str
    user_message: str = Field(max_length=4096)
    draft: dict = Field(default_factory=dict)
    messages: list[ChatMessage] = Field(default_factory=list)
    materials: list[ChatMaterial] = Field(default_factory=list)

    @field_validator("thread_id")
    @classmethod
    def validate_thread_id(cls, v: str) -> str:
        v = v.strip()
        if not v or not ID_PATTERN.match(v):
            raise ValueError("invalid thread_id: must be alphanumeric with - or _")
        return v

    @field_validator("user_message")
    @classmethod
    def validate_user_message(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("user_message must not be empty")
        return v


class ClarificationResult(BaseModel):
    """Response from a clarification turn."""
    assistant_reply: str = Field(max_length=8192)
    report_patch: dict = Field(default_factory=dict)


# ---------- SSE Delta ----------

class StreamDelta(BaseModel):
    """A single SSE delta event sent back to Rust."""
    kind: str = Field(max_length=16)  # "delta" | "result" | "error"
    content: str = Field(default="", max_length=16384)
    structured: dict | None = None


# ---------- PRD Structured Output ----------

class ScopeItem(BaseModel):
    """A single feature/capability in the PRD scope."""
    id: str = Field(max_length=64)
    name: str = Field(max_length=256)
    description: str = Field(default="", max_length=2048)
    priority: str = Field(default="P1", max_length=8)  # P0/P1/P2
    category: str = Field(default="frontend", max_length=32)  # frontend/backend/infra/cross-cutting


class AcceptanceCriterion(BaseModel):
    """Acceptance criterion linked to a scope item."""
    id: str = Field(max_length=64)
    scope_item_id: str = Field(default="", max_length=64)
    statement: str = Field(max_length=2048)
    criticality: str = Field(default="must", max_length=16)  # must/should/nice-to-have


class Milestone(BaseModel):
    id: str = Field(max_length=64)
    title: str = Field(max_length=256)
    scope_item_ids: list[str] = Field(default_factory=list)
    target_description: str = Field(default="", max_length=1024)


class PRDResult(BaseModel):
    """Structured PRD output — the core deliverable of the PRD stage."""
    project_name: str = Field(max_length=256)
    summary: str = Field(default="", max_length=2048)
    goals: list[str] = Field(default_factory=list)
    non_goals: list[str] = Field(default_factory=list)
    scope_items: list[ScopeItem] = Field(default_factory=list)
    technical_constraints: list[str] = Field(default_factory=list)
    acceptance_criteria: list[AcceptanceCriterion] = Field(default_factory=list)
    milestones: list[Milestone] = Field(default_factory=list)


class PRDContext(BaseModel):
    """Context passed from Rust daemon for PRD generation."""
    project_id: str
    project_name: str = Field(max_length=256)
    feasibility: dict | None = None

    @field_validator("project_id")
    @classmethod
    def validate_project_id(cls, v: str) -> str:
        v = v.strip()
        if not v or not ID_PATTERN.match(v):
            raise ValueError("invalid project_id")
        return v

    @field_validator("project_name")
    @classmethod
    def validate_project_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("project_name must not be empty")
        return v


# ---------- Development Structured Output ----------

class TechStack(BaseModel):
    language: str = Field(max_length=64)
    framework: str = Field(default="", max_length=128)
    build_tool: str = Field(default="", max_length=64)
    package_manager: str = Field(default="", max_length=64)
    runtime: str = Field(default="", max_length=64)
    additional: list[str] = Field(default_factory=list)


class ModuleSpec(BaseModel):
    id: str = Field(max_length=64)
    name: str = Field(max_length=256)
    responsibility: str = Field(default="", max_length=1024)
    depends_on: list[str] = Field(default_factory=list)
    files: list[str] = Field(default_factory=list)


class APIContract(BaseModel):
    id: str = Field(max_length=64)
    method: str = Field(max_length=8)  # GET/POST/PUT/DELETE
    path: str = Field(max_length=512)
    description: str = Field(default="", max_length=1024)
    request_schema: str = Field(default="", max_length=4096)
    response_schema: str = Field(default="", max_length=4096)
    scope_item_id: str = Field(default="", max_length=64)


class ScaffoldFile(BaseModel):
    path: str = Field(max_length=512)
    content: str = Field(default="", max_length=32768)
    language: str = Field(default="", max_length=32)
    purpose: str = Field(default="", max_length=256)


class DevelopmentPlan(BaseModel):
    """Structured development plan — the core deliverable of the development stage."""
    architecture_summary: str = Field(default="", max_length=4096)
    tech_stack: TechStack
    modules: list[ModuleSpec] = Field(default_factory=list)
    api_contracts: list[APIContract] = Field(default_factory=list)
    scaffold_files: list[ScaffoldFile] = Field(default_factory=list)


class DevelopmentContext(BaseModel):
    """Context passed from Rust daemon for development plan generation."""
    project_id: str
    project_name: str = Field(max_length=256)
    prd: dict | None = None
    feasibility: dict | None = None

    @field_validator("project_id")
    @classmethod
    def validate_project_id(cls, v: str) -> str:
        v = v.strip()
        if not v or not ID_PATTERN.match(v):
            raise ValueError("invalid project_id")
        return v

    @field_validator("project_name")
    @classmethod
    def validate_project_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("project_name must not be empty")
        return v


# ---------- Development Coding (sub-step 2) ----------

class CodeFile(BaseModel):
    """A generated implementation code file."""
    path: str = Field(max_length=512)
    content: str = Field(default="", max_length=65536)
    language: str = Field(default="", max_length=32)
    module_id: str = Field(default="", max_length=64)
    purpose: str = Field(default="", max_length=256)


class CodingResult(BaseModel):
    """Structured coding result — implementation code files."""
    summary: str = Field(default="", max_length=4096)
    code_files: list[CodeFile] = Field(default_factory=list)
    openspec_tasks: list[dict] = Field(default_factory=list)


class CodingContext(BaseModel):
    """Context for coding generation — takes the task breakdown as input."""
    project_id: str
    project_name: str = Field(max_length=256)
    task_breakdown: dict  # The DevelopmentPlan output from sub-step 1
    project_workspace: str = Field(default="", max_length=2048)

    @field_validator("project_id")
    @classmethod
    def validate_project_id(cls, v: str) -> str:
        v = v.strip()
        if not v or not ID_PATTERN.match(v):
            raise ValueError("invalid project_id")
        return v

    @field_validator("project_name")
    @classmethod
    def validate_project_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("project_name must not be empty")
        return v


# ---------- Unified Workflow ----------

class WorkflowStartContext(BaseModel):
    """Input for the unified AutoDev workflow graph."""
    workflow_id: str = Field(default="", max_length=128)
    thread_id: str
    project_id: str
    project_name: str = Field(max_length=256)
    user_message: str = Field(max_length=4096)
    action: str = Field(default="continue", max_length=32)
    draft: dict = Field(default_factory=dict)
    messages: list[ChatMessage] = Field(default_factory=list)
    materials: list[ChatMaterial] = Field(default_factory=list)

    @field_validator("workflow_id")
    @classmethod
    def validate_workflow_id(cls, v: str) -> str:
        v = v.strip()
        if v and not ID_PATTERN.match(v):
            raise ValueError("invalid workflow_id")
        return v

    @field_validator("thread_id")
    @classmethod
    def validate_workflow_thread_id(cls, v: str) -> str:
        v = v.strip()
        if not v or not ID_PATTERN.match(v):
            raise ValueError("invalid thread_id")
        return v

    @field_validator("project_id")
    @classmethod
    def validate_workflow_project_id(cls, v: str) -> str:
        v = v.strip()
        if not v or not ID_PATTERN.match(v):
            raise ValueError("invalid project_id")
        return v

    @field_validator("project_name")
    @classmethod
    def validate_workflow_project_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("project_name must not be empty")
        return v

    @field_validator("user_message")
    @classmethod
    def validate_workflow_user_message(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("user_message must not be empty")
        return v

    @field_validator("action")
    @classmethod
    def validate_start_workflow_action(cls, v: str) -> str:
        v = v.strip().lower() or "continue"
        if v not in {"continue", "retry", "rerun", "skip"}:
            raise ValueError("invalid workflow action")
        return v


class WorkflowResumeContext(BaseModel):
    """Request body for resuming or inspecting a checkpointed workflow."""
    workflow_id: str = Field(max_length=128)
    action: str = Field(default="continue", max_length=32)

    @field_validator("workflow_id")
    @classmethod
    def validate_resume_workflow_id(cls, v: str) -> str:
        v = v.strip()
        if not v or not ID_PATTERN.match(v):
            raise ValueError("invalid workflow_id")
        return v

    @field_validator("action")
    @classmethod
    def validate_workflow_action(cls, v: str) -> str:
        v = v.strip().lower() or "continue"
        if v not in {"continue", "retry", "rerun", "skip"}:
            raise ValueError("invalid workflow action")
        return v


class WorkflowArtifactContext(WorkflowResumeContext):
    """Request body for fetching one checkpointed workflow artifact."""

    artifact_id: str = Field(max_length=256)

    @field_validator("artifact_id")
    @classmethod
    def validate_artifact_id(cls, v: str) -> str:
        v = v.strip()
        if not v or not re.match(r"^[a-zA-Z0-9_:-]{1,256}$", v):
            raise ValueError("invalid artifact_id")
        return v


class WorkflowStreamContext(WorkflowStartContext):
    """Request body for streaming workflow execution events."""

    mode: str = Field(default="resume", max_length=16)

    @field_validator("mode")
    @classmethod
    def validate_workflow_stream_mode(cls, v: str) -> str:
        v = v.strip().lower() or "resume"
        if v not in {"start", "resume"}:
            raise ValueError("invalid workflow stream mode")
        return v

"""Pydantic models — shared request/response schemas."""

from __future__ import annotations
from pydantic import BaseModel, Field


# ---------- Stage Generation ----------

class StageContext(BaseModel):
    """Context passed from Rust daemon for stage AI generation."""
    project_id: str
    project_name: str
    stage: str
    objective: str = ""
    input_contexts: list[str] = Field(default_factory=list)
    step_progress: list[dict] = Field(default_factory=list)
    risk_items: list[str] = Field(default_factory=list)
    event_flow: list[str] = Field(default_factory=list)
    primary_action: str = ""
    secondary_actions: list[str] = Field(default_factory=list)
    work_units: list[dict] = Field(default_factory=list)
    feasibility: dict | None = None


class WorkUnit(BaseModel):
    id: str
    title: str
    agent_role: str
    status: str = "queued"
    progress: float = 0.0
    depends_on: list[str] = Field(default_factory=list)
    current_output: str | None = None
    next_step: str = ""


class StepProgress(BaseModel):
    title: str
    status: str = "queued"


class StageResult(BaseModel):
    """Structured output from the synthesizer node."""
    objective: str
    input_contexts: list[str] = Field(default_factory=list)
    step_progress: list[StepProgress] = Field(default_factory=list)
    risk_items: list[str] = Field(default_factory=list)
    event_flow: list[str] = Field(default_factory=list)
    primary_action: str = ""
    secondary_actions: list[str] = Field(default_factory=list)
    work_units: list[WorkUnit] = Field(default_factory=list)


# ---------- Feasibility Report ----------

class ReportContext(BaseModel):
    """Context for feasibility report generation."""
    thread_id: str
    draft: dict = Field(default_factory=dict)
    messages: list[dict] = Field(default_factory=list)
    materials: list[dict] = Field(default_factory=list)


class FeasibilityReport(BaseModel):
    project_name: str = ""
    problem_definition: str = ""
    target_users: str = ""
    core_capabilities: list[str] = Field(default_factory=list)
    risks_and_constraints: list[str] = Field(default_factory=list)
    initial_delivery_plan: list[str] = Field(default_factory=list)
    feasibility_conclusion: str = ""


# ---------- SSE Delta ----------

class StreamDelta(BaseModel):
    """A single SSE delta event sent back to Rust."""
    kind: str  # "delta" | "result" | "error"
    content: str = ""
    structured: dict | None = None

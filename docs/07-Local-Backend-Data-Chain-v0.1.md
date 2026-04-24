# Local Backend Data Chain v0.1

## Goal

This round moves the macOS app from in-memory sample state to a minimal real local backend data chain:

- Project library
- Creation threads
- New thread
- Send creation message
- Add materials
- Confirm feasibility
- Stage detail

The scope is intentionally minimal and local-first:

- `rusqlite` only
- No remote database
- No event bus
- No complex repository abstraction

## Runtime Layout

All runtime files are stored under:

- `~/Library/Application Support/com.sanmws.autodev/`

Layout:

- `ipc/daemon.sock`
- `data/app.db`
- `blobs/reports/...`
- `blobs/materials/...`

## SQLite Schema (v0.1)

### `projects`

- `id` (TEXT, PK)
- `title`
- `current_phase`
- `lifecycle_stage` (`feasibility|prd|ui|development|testing|release|maintenance`)
- `progress` (REAL, `0..1`)
- `current_goal`
- `next_action`
- `risk` (`low|medium|high`)
- `block_reason` (nullable)
- `status` (`running|queued|awaiting_confirmation|blocked|failed|completed|archived`)
- `owner`
- `updated_at_ms`
- `created_at_ms`

### `project_stages`

- `project_id` + `stage` (PK)
- `objective`
- `input_contexts_json`
- `step_progress_json`
- `risk_items_json`
- `event_flow_json`
- `primary_action`
- `secondary_actions_json`
- `updated_at_ms`

### `creation_threads`

- `id` (PK)
- `title`
- `is_archived`
- `linked_project_id` (nullable)
- `lifecycle_stage`
- `last_updated_ms`
- `created_at_ms`

### `creation_messages`

- `id` (PK)
- `thread_id` (FK)
- `role` (`ai|user`)
- `content`
- `created_at_ms`

### `feasibility_reports`

- `thread_id` (PK/FK)
- `project_name`
- `problem_definition`
- `target_users`
- `core_capabilities_json`
- `risks_constraints_json`
- `delivery_plan_json`
- `feasibility_conclusion`
- `version`
- `report_file_path` (nullable)
- `updated_at_ms`

### `materials`

- `id` (PK)
- `thread_id` (FK)
- `name`
- `type_hint`
- `size_hint`
- `analysis_status` (`queued|analyzed`)
- `added_at_ms`
- `blob_path` (nullable)

### `stage_artifacts`

- `id` (PK)
- `project_id` (FK)
- `stage`
- `name`
- `kind`
- `updated_at_ms`
- `file_path` (nullable)
- `content_type` (nullable)

### `stage_events`

- `id` (PK)
- `project_id` (FK)
- `stage`
- `title`
- `detail`
- `created_at_ms`

## Seed Rules

- On daemon startup:
  - create dirs
  - open `app.db`
  - create tables
  - seed only when `projects` is empty

Seed includes:

- one feasibility project
- one linked creation thread
- initial conversation
- one feasibility report file
- one material file
- stage artifact and stage event

After seed, all changes are persisted and survive restart.

## IPC Contract (JSON over Unix socket)

### Queries

- `query.get_health` -> `query.get_health.ok`
- `query.get_overview` -> `query.get_overview.ok`
- `query.list_projects` -> `query.list_projects.ok`
- `query.list_creation_threads` -> `query.list_creation_threads.ok`
- `query.get_project_stage_detail` -> `query.get_project_stage_detail.ok`

### Commands

- `command.create_creation_thread` -> `command.create_creation_thread.ok`
- `command.rename_creation_thread` -> `command.rename_creation_thread.ok`
- `command.archive_creation_thread` -> `command.archive_creation_thread.ok`
- `command.delete_creation_thread` -> `command.delete_creation_thread.ok`
- `command.add_creation_message` -> `command.add_creation_message.ok`
- `command.add_creation_materials` -> `command.add_creation_materials.ok`
- `command.confirm_feasibility` -> `command.confirm_feasibility.ok`

### Key Payloads

`query.get_project_stage_detail`:

- input: `project_id`, optional `stage`
- output: `detail` (objective/input/output/step/risk/event/actions/downloads)

`command.add_creation_message`:

- input: `thread_id`, `content`
- behavior: write user message + AI follow-up + update feasibility draft

`command.add_creation_materials`:

- input: `thread_id`, `materials[]` (`path`, optional `name`)
- behavior: copy files into `blobs/materials/` and store metadata

`command.confirm_feasibility`:

- input: `thread_id`
- behavior:
  - create project when missing
  - initialize PRD stage state
  - update thread `linked_project_id` + lifecycle stage to `prd`
  - append stage event and artifact

## Status Flow (v0.1)

Current enforced flow for this round:

1. Creation thread in `feasibility`
2. Send messages and upload materials
3. Confirm feasibility
4. Thread moves to `prd`
5. Linked project appears in project library
6. Stage detail reads PRD detail from daemon

## Swift Integration (v0.1)

`ShellDataMode.liveDaemon` now uses daemon-backed data/actions:

- startup loads health + overview + projects + threads
- project detail fetches real stage detail from daemon
- creation actions call daemon commands then refresh state
- Preview keeps sample state (`ShellDataMode.sampleOnly`)

Download behavior:

- Feasibility report/material buttons open local file path when present
- fallback is status hint when file path is missing

## Stage Detail Contract Alignment (v0.2 draft)

This section freezes the next backend contract expected by the stage detail UI.

### Positioning

- Stage detail is an execution control page.
- Event flow accepts only real-time `detail.events`.
- Downloads are structured as `stage.downloads[]`; frontend no longer relies on scattered ad-hoc buttons.
- Development execution progress is structured as `stage.work_units[]`; frontend shows the active work unit first, then the dependency-aware unit list.

### Suggested detail payload shape

- `project_id`
- `stage`
- `status`
- `updated_at`
- `objective`
- `input_contexts[]`
- `output_artifacts[]`
- `risk_items[]`
- `blocker_reason?`
- `events[]`
- `primary_action`
- `secondary_actions[]` (max 2)
- `downloads[]`
- `work_units[]`

### `downloads[]` schema

- `id`
- `title`
- `category` (`raw_input|stage_snapshot|audit_archive`)
- `availability` (`ready|pending|view_only`)
- `file_path` (nullable)
- `updated_at_ms` (nullable)
- `content_type` (nullable)

### `work_units[]` schema

- `id`
- `title`
- `agent_role`
- `status` (`queued|running|blocked|failed|completed`)
- `progress` (`0..1`)
- `depends_on[]`
- `current_output` (nullable)
- `next_step`

### Stage download strategy

- feasibility: feasibility report + raw reference materials
- prd: PRD snapshot
- ui: optional UI snapshot (view-first)
- development: task split docs + Git/GitHub coordination + stable preview + review/test/archive records
- testing: test report + acceptance snapshot
- release: release record/package + rollback archive
- maintenance: optional maintenance record (view-first)

Development work unit display strategy:

- show the first `running` work unit as the current focus
- if none is running, show the first `blocked|queued` work unit
- keep dependency order explicit; do not start dependent units until required outputs exist
- use frontend placeholders only until backend `work_units[]` arrives

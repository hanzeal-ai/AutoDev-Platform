use super::{Store, StoreResult};

impl Store {
    pub fn init_schema(&self) -> StoreResult<()> {
        self.conn
            .execute_batch(
                r#"
CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  current_phase TEXT NOT NULL,
  lifecycle_stage TEXT NOT NULL,
  progress REAL NOT NULL,
  current_goal TEXT NOT NULL,
  next_action TEXT NOT NULL,
  risk TEXT NOT NULL,
  block_reason TEXT,
  status TEXT NOT NULL,
  owner TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS project_stages (
  project_id TEXT NOT NULL,
  stage TEXT NOT NULL,
  objective TEXT NOT NULL,
  input_contexts_json TEXT NOT NULL,
  step_progress_json TEXT NOT NULL,
  risk_items_json TEXT NOT NULL,
  event_flow_json TEXT NOT NULL,
  primary_action TEXT NOT NULL,
  secondary_actions_json TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY (project_id, stage),
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS creation_threads (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  is_archived INTEGER NOT NULL DEFAULT 0,
  linked_project_id TEXT,
  lifecycle_stage TEXT NOT NULL,
  last_updated_ms INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL,
  FOREIGN KEY (linked_project_id) REFERENCES projects(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS creation_messages (
  id TEXT PRIMARY KEY,
  thread_id TEXT NOT NULL,
  role TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  FOREIGN KEY (thread_id) REFERENCES creation_threads(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS feasibility_reports (
  thread_id TEXT PRIMARY KEY,
  project_name TEXT NOT NULL,
  problem_definition TEXT NOT NULL,
  target_users TEXT NOT NULL,
  core_capabilities_json TEXT NOT NULL,
  risks_constraints_json TEXT NOT NULL,
  delivery_plan_json TEXT NOT NULL,
  feasibility_conclusion TEXT NOT NULL,
  version TEXT NOT NULL,
  report_file_path TEXT,
  updated_at_ms INTEGER NOT NULL,
  FOREIGN KEY (thread_id) REFERENCES creation_threads(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS materials (
  id TEXT PRIMARY KEY,
  thread_id TEXT NOT NULL,
  name TEXT NOT NULL,
  type_hint TEXT NOT NULL,
  size_hint TEXT NOT NULL,
  analysis_status TEXT NOT NULL,
  added_at_ms INTEGER NOT NULL,
  blob_path TEXT,
  FOREIGN KEY (thread_id) REFERENCES creation_threads(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS stage_artifacts (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  stage TEXT NOT NULL,
  name TEXT NOT NULL,
  kind TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  file_path TEXT,
  content_type TEXT,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS stage_events (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  stage TEXT NOT NULL,
  title TEXT NOT NULL,
  detail TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS stage_ai_runs (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  stage TEXT NOT NULL,
  status TEXT NOT NULL,
  started_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  first_delta_at_ms INTEGER,
  last_delta_at_ms INTEGER,
  delta_count INTEGER NOT NULL DEFAULT 0,
  error_message TEXT,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_projects_status_updated
ON projects(status, updated_at_ms DESC);

CREATE INDEX IF NOT EXISTS idx_projects_lifecycle_stage
ON projects(lifecycle_stage);

CREATE INDEX IF NOT EXISTS idx_creation_threads_updated
ON creation_threads(is_archived, last_updated_ms DESC);

CREATE INDEX IF NOT EXISTS idx_creation_threads_project_updated
ON creation_threads(linked_project_id, last_updated_ms DESC);

CREATE INDEX IF NOT EXISTS idx_creation_messages_thread_created
ON creation_messages(thread_id, created_at_ms ASC);

CREATE INDEX IF NOT EXISTS idx_materials_thread_added
ON materials(thread_id, added_at_ms DESC);

CREATE INDEX IF NOT EXISTS idx_stage_artifacts_lookup
ON stage_artifacts(project_id, stage, updated_at_ms DESC);

CREATE INDEX IF NOT EXISTS idx_stage_events_lookup
ON stage_events(project_id, stage, created_at_ms DESC);

CREATE INDEX IF NOT EXISTS idx_stage_ai_runs_lookup
ON stage_ai_runs(project_id, stage, updated_at_ms DESC);
"#,
            )
            .map_err(|err| format!("schema initialization failed: {}", err))?;

        self.ensure_project_stage_columns()
    }

    fn ensure_project_stage_columns(&self) -> StoreResult<()> {
        self.ensure_column(
            "project_stages",
            "downloads_json",
            "ALTER TABLE project_stages ADD COLUMN downloads_json TEXT NOT NULL DEFAULT '[]'",
        )?;
        self.ensure_column(
            "project_stages",
            "work_units_json",
            "ALTER TABLE project_stages ADD COLUMN work_units_json TEXT NOT NULL DEFAULT '[]'",
        )
    }

    fn ensure_column(&self, table: &str, column: &str, alter_sql: &str) -> StoreResult<()> {
        let mut stmt = self
            .conn
            .prepare(&format!("PRAGMA table_info({table})"))
            .map_err(|err| err.to_string())?;
        let rows = stmt
            .query_map([], |row| row.get::<_, String>(1))
            .map_err(|err| err.to_string())?;

        for row in rows {
            if row.map_err(|err| err.to_string())? == column {
                return Ok(());
            }
        }

        self.conn.execute(alter_sql, [])
            .map_err(|err| format!("alter table {}.{} failed: {}", table, column, err))?;
        Ok(())
    }
}

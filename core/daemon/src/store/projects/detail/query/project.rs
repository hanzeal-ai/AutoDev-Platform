use super::super::super::super::{Store, StoreResult};
use rusqlite::{params, OptionalExtension};

pub(in crate::store::projects::detail) struct ProjectRow {
    pub(in crate::store::projects::detail) title: String,
    pub(in crate::store::projects::detail) lifecycle_stage: String,
    pub(in crate::store::projects::detail) status: String,
    pub(in crate::store::projects::detail) risk: String,
    pub(in crate::store::projects::detail) owner: String,
    pub(in crate::store::projects::detail) updated_at_ms: i64,
    pub(in crate::store::projects::detail) next_action: String,
    pub(in crate::store::projects::detail) progress: f64,
    pub(in crate::store::projects::detail) block_reason: Option<String>,
}

pub(in crate::store::projects::detail) fn load_project(
    store: &Store,
    project_id: &str,
) -> StoreResult<ProjectRow> {
    store
        .conn
        .query_row(
            r#"
SELECT title, lifecycle_stage, status, risk, owner, updated_at_ms, next_action, progress, block_reason
FROM projects
WHERE id = ?1
"#,
            params![project_id],
            |row| {
                Ok(ProjectRow {
                    title: row.get(0)?,
                    lifecycle_stage: row.get(1)?,
                    status: row.get(2)?,
                    risk: row.get(3)?,
                    owner: row.get(4)?,
                    updated_at_ms: row.get(5)?,
                    next_action: row.get(6)?,
                    progress: row.get(7)?,
                    block_reason: row.get(8)?,
                })
            },
        )
        .optional()
        .map_err(|err| err.to_string())?
        .ok_or_else(|| format!("project not found: {project_id}"))
}

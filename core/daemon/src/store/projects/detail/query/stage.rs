use super::super::super::super::{Store, StoreResult};
use rusqlite::{params, OptionalExtension};

pub(in crate::store::projects::detail) struct StageRow {
    pub(in crate::store::projects::detail) objective: String,
    pub(in crate::store::projects::detail) input_contexts_json: String,
    pub(in crate::store::projects::detail) step_progress_json: String,
    pub(in crate::store::projects::detail) risk_items_json: String,
    pub(in crate::store::projects::detail) event_flow_json: String,
    pub(in crate::store::projects::detail) primary_action: String,
    pub(in crate::store::projects::detail) secondary_actions_json: String,
    pub(in crate::store::projects::detail) downloads_json: String,
    pub(in crate::store::projects::detail) work_units_json: String,
}

pub(in crate::store::projects::detail) fn load_stage(
    store: &Store,
    project_id: &str,
    stage: &str,
) -> StoreResult<Option<StageRow>> {
    store
        .conn
        .query_row(
            r#"
SELECT objective, input_contexts_json, step_progress_json, risk_items_json, event_flow_json,
       primary_action, secondary_actions_json, downloads_json, work_units_json
FROM project_stages
WHERE project_id = ?1 AND stage = ?2
"#,
            params![project_id, stage],
            |row| {
                Ok(StageRow {
                    objective: row.get(0)?,
                    input_contexts_json: row.get(1)?,
                    step_progress_json: row.get(2)?,
                    risk_items_json: row.get(3)?,
                    event_flow_json: row.get(4)?,
                    primary_action: row.get(5)?,
                    secondary_actions_json: row.get(6)?,
                    downloads_json: row.get(7)?,
                    work_units_json: row.get(8)?,
                })
            },
        )
        .optional()
        .map_err(|err| err.to_string())
}

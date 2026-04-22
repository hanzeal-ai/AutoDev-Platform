use super::super::super::super::helpers::relative_label;
use super::super::super::super::{Store, StoreResult};
use rusqlite::{params, OptionalExtension};
use serde_json::{json, Value};

pub(in crate::store::projects::detail) fn latest_ai_run(
    store: &Store,
    project_id: &str,
    stage: &str,
) -> StoreResult<Option<Value>> {
    store
        .conn
        .query_row(
            r#"
SELECT id, status, started_at_ms, updated_at_ms, first_delta_at_ms,
       last_delta_at_ms, delta_count, error_message
FROM stage_ai_runs
WHERE project_id = ?1 AND stage = ?2
ORDER BY updated_at_ms DESC
LIMIT 1
"#,
            params![project_id, stage],
            |row| {
                let started_at_ms: i64 = row.get(2)?;
                let updated_at_ms: i64 = row.get(3)?;
                let first_delta_at_ms: Option<i64> = row.get(4)?;
                let last_delta_at_ms: Option<i64> = row.get(5)?;
                Ok(json!({
                    "id": row.get::<_, String>(0)?,
                    "status": row.get::<_, String>(1)?,
                    "started_at": relative_label(started_at_ms),
                    "updated_at": relative_label(updated_at_ms),
                    "started_at_ms": started_at_ms,
                    "updated_at_ms": updated_at_ms,
                    "first_delta_at_ms": first_delta_at_ms,
                    "last_delta_at_ms": last_delta_at_ms,
                    "delta_count": row.get::<_, i64>(6)?,
                    "error_message": row.get::<_, Option<String>>(7)?,
                }))
            },
        )
        .optional()
        .map_err(|err| err.to_string())
}

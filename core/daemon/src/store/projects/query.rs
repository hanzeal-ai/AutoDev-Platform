use super::super::helpers::relative_label;
use super::super::{Store, StoreResult};
use serde_json::{json, Value};

impl Store {
    pub fn list_projects(&self) -> StoreResult<Value> {
        let mut stmt = self
            .conn
            .prepare(
                r#"
SELECT
  id, title, current_phase, lifecycle_stage, progress, current_goal, next_action,
  risk, block_reason, status, owner, updated_at_ms
FROM projects
ORDER BY updated_at_ms DESC
"#,
            )
            .map_err(|err| err.to_string())?;

        let rows = stmt
            .query_map([], |row| {
                let updated_at_ms: i64 = row.get(11)?;
                Ok(json!({
                    "id": row.get::<_, String>(0)?,
                    "title": row.get::<_, String>(1)?,
                    "current_phase": row.get::<_, String>(2)?,
                    "lifecycle_stage": row.get::<_, String>(3)?,
                    "progress": row.get::<_, f64>(4)?,
                    "current_goal": row.get::<_, String>(5)?,
                    "next_action": row.get::<_, String>(6)?,
                    "risk": row.get::<_, String>(7)?,
                    "block_reason": row.get::<_, Option<String>>(8)?,
                    "status": row.get::<_, String>(9)?,
                    "owner": row.get::<_, String>(10)?,
                    "updated_at": relative_label(updated_at_ms),
                    "updated_at_ms": updated_at_ms
                }))
            })
            .map_err(|err| err.to_string())?;

        let mut projects = Vec::new();
        for row in rows {
            projects.push(row.map_err(|err| err.to_string())?);
        }

        Ok(json!({ "projects": projects }))
    }
}

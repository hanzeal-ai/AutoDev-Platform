use super::super::{Store, StoreResult};
use serde_json::{json, Value};

impl Store {
    pub(super) fn lifecycle_distribution(&self) -> StoreResult<Vec<Value>> {
        let mut stmt = self
            .conn
            .prepare(
                r#"
SELECT lifecycle_stage, COUNT(*)
FROM projects
GROUP BY lifecycle_stage
"#,
            )
            .map_err(|err| err.to_string())?;
        let rows = stmt
            .query_map([], |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)?))
            })
            .map_err(|err| err.to_string())?;

        let mut counts = std::collections::HashMap::<String, i64>::new();
        for row in rows {
            let (stage, count) = row.map_err(|err| err.to_string())?;
            counts.insert(stage, count);
        }

        let ordered = [
            "feasibility",
            "prd",
            "ui",
            "development",
            "testing",
            "release",
            "maintenance",
        ];

        Ok(ordered
            .iter()
            .map(|stage| {
                json!({
                    "stage": *stage,
                    "count": counts.get(*stage).copied().unwrap_or(0)
                })
            })
            .collect())
    }
}

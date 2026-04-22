use super::super::super::helpers::relative_label;
use super::super::super::{Store, StoreResult};
use serde_json::{json, Value};
use uuid::Uuid;

pub(super) fn progress_notices(store: &Store) -> StoreResult<Vec<Value>> {
    let mut stmt = store
        .conn
        .prepare(
            r#"
SELECT title, detail, created_at_ms
FROM (
  SELECT
    CASE stage
      WHEN 'feasibility' THEN '立项推进'
      WHEN 'prd' THEN 'PRD 更新'
      WHEN 'ui' THEN 'UI 更新'
      WHEN 'development' THEN '研发推进'
      WHEN 'testing' THEN '测试推进'
      WHEN 'release' THEN '发布推进'
      ELSE '维护更新'
    END AS title,
    detail AS detail,
    created_at_ms
  FROM stage_events
  ORDER BY created_at_ms DESC
  LIMIT 8
)
"#,
        )
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map([], |row| {
            Ok(json!({
                "id": Uuid::new_v4().to_string(),
                "title": row.get::<_, String>(0)?,
                "detail": row.get::<_, String>(1)?,
                "time": relative_label(row.get::<_, i64>(2)?)
            }))
        })
        .map_err(|err| err.to_string())?;

    let mut out = Vec::new();
    for row in rows {
        out.push(row.map_err(|err| err.to_string())?);
    }
    Ok(out)
}

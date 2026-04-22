use super::super::{SeedFiles, SeedIds};
use crate::store::{Store, StoreResult};
use rusqlite::params;
use uuid::Uuid;

pub(super) fn insert_stage_records(
    store: &Store,
    ids: &SeedIds,
    seed_files: &SeedFiles,
    now: i64,
) -> StoreResult<()> {
    insert_stage_artifact(store, ids, seed_files, now)?;
    insert_stage_event(store, ids, now)?;
    Ok(())
}

fn insert_stage_artifact(
    store: &Store,
    ids: &SeedIds,
    seed_files: &SeedFiles,
    now: i64,
) -> StoreResult<()> {
    store
        .conn
        .execute(
            r#"
INSERT INTO stage_artifacts (
  id, project_id, stage, name, kind, updated_at_ms, file_path, content_type
) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
"#,
            params![
                Uuid::new_v4().to_string(),
                ids.project_id,
                "feasibility",
                "可行性报告 v0.1",
                "报告",
                now,
                seed_files.report_file.display().to_string(),
                "text/markdown"
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

fn insert_stage_event(store: &Store, ids: &SeedIds, now: i64) -> StoreResult<()> {
    store
        .conn
        .execute(
            r#"
INSERT INTO stage_events (id, project_id, stage, title, detail, created_at_ms)
VALUES (?1, ?2, ?3, ?4, ?5, ?6)
"#,
            params![
                Uuid::new_v4().to_string(),
                ids.project_id,
                "feasibility",
                "可行性草稿已生成",
                "系统已根据对话和资料更新立项结论。",
                now
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

use super::super::super::helpers::human_file_size;
use super::super::{SeedFiles, SeedIds};
use crate::store::{Store, StoreResult};
use rusqlite::params;
use std::fs;

pub(super) fn insert_material_record(
    store: &Store,
    ids: &SeedIds,
    seed_files: &SeedFiles,
    now: i64,
) -> StoreResult<()> {
    let material_size = fs::metadata(&seed_files.material_file)
        .map_err(|err| err.to_string())?
        .len();
    store
        .conn
        .execute(
            r#"
INSERT INTO materials (
  id, thread_id, name, type_hint, size_hint, analysis_status, added_at_ms, blob_path
) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
"#,
            params![
                ids.material_id,
                ids.thread_id,
                "业务背景访谈.md",
                "MD",
                human_file_size(material_size),
                "analyzed",
                now,
                seed_files.material_file.display().to_string()
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

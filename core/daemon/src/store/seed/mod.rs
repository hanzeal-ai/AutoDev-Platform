mod files;
mod records;

use super::helpers::now_ms;
use super::{Store, StoreResult};
use std::path::PathBuf;
use uuid::Uuid;

pub(super) struct SeedIds {
    pub(super) project_id: String,
    pub(super) thread_id: String,
    pub(super) material_id: String,
}

pub(super) struct SeedFiles {
    pub(super) report_file: PathBuf,
    pub(super) material_file: PathBuf,
}

impl SeedIds {
    fn generate() -> Self {
        Self {
            project_id: Uuid::new_v4().to_string(),
            thread_id: Uuid::new_v4().to_string(),
            material_id: Uuid::new_v4().to_string(),
        }
    }
}

impl Store {
    pub fn seed_if_empty(&self) -> StoreResult<()> {
        if self.project_count()? > 0 {
            return Ok(());
        }

        let now = now_ms();
        let ids = SeedIds::generate();
        let seed_files = files::write_seed_files(self, &ids)?;
        records::insert_seed_records(self, &ids, &seed_files, now)
    }

    fn project_count(&self) -> StoreResult<i64> {
        self.conn
            .query_row("SELECT COUNT(*) FROM projects", [], |row| row.get(0))
            .map_err(|err| err.to_string())
    }
}

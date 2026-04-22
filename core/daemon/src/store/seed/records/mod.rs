mod artifact;
mod material;
mod project;
mod thread;

use super::super::{Store, StoreResult};
use super::{SeedFiles, SeedIds};

pub(super) fn insert_seed_records(
    store: &Store,
    ids: &SeedIds,
    seed_files: &SeedFiles,
    now: i64,
) -> StoreResult<()> {
    project::insert_project_records(store, ids, now)?;
    thread::insert_thread_records(store, ids, seed_files, now)?;
    material::insert_material_record(store, ids, seed_files, now)?;
    artifact::insert_stage_records(store, ids, seed_files, now)?;
    Ok(())
}

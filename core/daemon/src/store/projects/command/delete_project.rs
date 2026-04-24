use super::super::super::helpers::now_ms;
use crate::logger;
use crate::store::{Store, StoreResult};
use rusqlite::params;
use serde_json::{json, Value};
use std::fs;

impl Store {
    pub fn delete_project(&self, project_id: &str) -> StoreResult<Value> {
        let project_id = project_id.trim().to_lowercase();
        if project_id.is_empty() {
            return Err("project_id must not be empty".to_string());
        }

        let exists: bool = self
            .conn
            .query_row(
                "SELECT COUNT(*) > 0 FROM projects WHERE id = ?1",
                params![&project_id],
                |row| row.get(0),
            )
            .map_err(|err| err.to_string())?;
        if !exists {
            return Err(format!("project not found: {project_id}"));
        }

        // Collect blob paths before deleting DB rows
        let artifact_paths = self.collect_artifact_blob_paths(&project_id)?;

        // CASCADE deletes project_stages, stage_artifacts, stage_events, stage_ai_runs
        self.conn
            .execute("DELETE FROM projects WHERE id = ?1", params![&project_id])
            .map_err(|err| err.to_string())?;

        // Clean up blob files on disk
        let cleaned = cleanup_blob_files(&artifact_paths);

        logger::info(&format!(
            "project deleted: {} (blobs cleaned: {}/{})",
            project_id,
            cleaned,
            artifact_paths.len()
        ));

        Ok(json!({
            "project_id": project_id,
            "deleted_at_ms": now_ms()
        }))
    }

    fn collect_artifact_blob_paths(&self, project_id: &str) -> StoreResult<Vec<String>> {
        let mut stmt = self
            .conn
            .prepare("SELECT file_path FROM stage_artifacts WHERE project_id = ?1")
            .map_err(|err| err.to_string())?;
        let paths = stmt
            .query_map(params![project_id], |row| row.get::<_, String>(0))
            .map_err(|err| err.to_string())?
            .filter_map(|r| r.ok())
            .filter(|p| !p.is_empty())
            .collect();
        Ok(paths)
    }
}

fn cleanup_blob_files(paths: &[String]) -> usize {
    let mut cleaned = 0;
    for path in paths {
        if let Err(err) = fs::remove_file(path) {
            if err.kind() != std::io::ErrorKind::NotFound {
                logger::error_fields(
                    "blob_cleanup_failed",
                    &[("path", path.clone()), ("error", err.to_string())],
                );
            }
        } else {
            cleaned += 1;
        }
    }
    cleaned
}

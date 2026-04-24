use super::super::helpers::{ensure_parent_dir, file_name_or_default, human_file_size, now_ms};
use super::super::{MaterialInput, Store, StoreResult};
use rusqlite::params;
use serde_json::{json, Value};
use std::fs;
use std::path::{Path, PathBuf};
use uuid::Uuid;

pub(super) fn add_creation_materials(
    store: &Store,
    thread_id: &str,
    material_inputs: &[MaterialInput],
) -> StoreResult<Value> {
    let now = now_ms();
    let mut added = 0usize;

    for item in material_inputs {
        let material_id = Uuid::new_v4().to_string();
        let source = PathBuf::from(&item.path);

        // Path traversal guard
        if item.path.contains("..") {
            return Err(format!("material path must not contain '..': {}", item.path));
        }

        // File size limit (100 MB)
        const MAX_MATERIAL_SIZE: u64 = 100 * 1024 * 1024;
        if source.exists() {
            let file_size = std::fs::metadata(&source)
                .map_err(|err| format!("failed to read metadata for {}: {}", source.display(), err))?
                .len();
            if file_size > MAX_MATERIAL_SIZE {
                return Err(format!(
                    "material too large ({} bytes, max {} bytes): {}",
                    file_size, MAX_MATERIAL_SIZE, item.path
                ));
            }
        }

        let name = item
            .name
            .clone()
            .unwrap_or_else(|| file_name_or_default(&source, "资料"));
        let type_hint = type_hint(&source);
        let dest = material_dest(store, &material_id, &name);
        ensure_parent_dir(&dest)?;

        let (size_hint, analysis_status) = copy_or_stub_material(&source, &dest)?;
        persist_material_record(
            store,
            thread_id,
            &material_id,
            &name,
            &type_hint,
            &size_hint,
            &analysis_status,
            now,
            &dest,
        )?;
        added += 1;
    }

    store.touch_thread(thread_id, now)?;
    Ok(json!({ "thread_id": thread_id, "added_count": added }))
}

fn type_hint(source: &Path) -> String {
    source
        .extension()
        .and_then(|value| value.to_str())
        .filter(|value| !value.is_empty())
        .map(|value| value.to_ascii_uppercase())
        .unwrap_or_else(|| "资料".to_string())
}

fn material_dest(store: &Store, material_id: &str, name: &str) -> PathBuf {
    store
        .paths
        .blobs_dir()
        .join("materials")
        .join(format!("{material_id}-{name}"))
}

fn copy_or_stub_material(source: &Path, dest: &Path) -> StoreResult<(String, String)> {
    if source.exists() {
        fs::copy(source, dest)
            .map_err(|err| format!("fs::copy {} -> {}: {}", source.display(), dest.display(), err))?;
        match fs::metadata(dest) {
            Ok(meta) => Ok((human_file_size(meta.len()), "completed".to_string())),
            Err(err) => {
                let _ = fs::remove_file(dest);
                Err(err.to_string())
            }
        }
    } else {
        fs::write(dest, format!("原始路径不存在：{}", source.display()))
            .map_err(|err| err.to_string())?;
        Ok(("待识别".to_string(), "queued".to_string()))
    }
}

fn persist_material_record(
    store: &Store,
    thread_id: &str,
    material_id: &str,
    name: &str,
    type_hint: &str,
    size_hint: &str,
    analysis_status: &str,
    now: i64,
    dest: &Path,
) -> StoreResult<()> {
    store
        .conn
        .execute(
            r#"
INSERT INTO materials (
  id, thread_id, name, type_hint, size_hint, analysis_status, added_at_ms, blob_path
) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
"#,
            params![
                material_id,
                thread_id,
                name,
                type_hint,
                size_hint,
                analysis_status,
                now,
                dest.display().to_string()
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

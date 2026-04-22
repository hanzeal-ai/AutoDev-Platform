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
        let name = item
            .name
            .clone()
            .unwrap_or_else(|| file_name_or_default(&source, "资料"));
        let type_hint = type_hint(&source);
        let dest = material_dest(store, &material_id, &name);
        ensure_parent_dir(&dest)?;

        let size_hint = copy_or_stub_material(&source, &dest)?;
        persist_material_record(
            store,
            thread_id,
            &material_id,
            &name,
            &type_hint,
            &size_hint,
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

fn copy_or_stub_material(source: &Path, dest: &Path) -> StoreResult<String> {
    if source.exists() {
        fs::copy(source, dest).map_err(|err| err.to_string())?;
        let size = fs::metadata(dest).map_err(|err| err.to_string())?.len();
        Ok(human_file_size(size))
    } else {
        fs::write(dest, format!("原始路径不存在：{}", source.display()))
            .map_err(|err| err.to_string())?;
        Ok("待识别".to_string())
    }
}

fn persist_material_record(
    store: &Store,
    thread_id: &str,
    material_id: &str,
    name: &str,
    type_hint: &str,
    size_hint: &str,
    now: i64,
    dest: &Path,
) -> StoreResult<()> {
    store
        .conn
        .execute(
            r#"
INSERT INTO materials (
  id, thread_id, name, type_hint, size_hint, analysis_status, added_at_ms, blob_path
) VALUES (?1, ?2, ?3, ?4, ?5, 'queued', ?6, ?7)
"#,
            params![
                material_id,
                thread_id,
                name,
                type_hint,
                size_hint,
                now,
                dest.display().to_string()
            ],
        )
        .map_err(|err| err.to_string())?;
    Ok(())
}

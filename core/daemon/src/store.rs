mod helpers;
mod materials;
mod overview;
mod projects;
mod reports;
mod schema;
mod threads;

use crate::runtime::RuntimePaths;
use rusqlite::Connection;
use serde_json::Value;

pub struct Store {
    pub(super) conn: Connection,
    pub(super) paths: RuntimePaths,
}

pub struct MaterialInput {
    pub path: String,
    pub name: Option<String>,
}

#[derive(Clone)]
pub(super) struct StageDownloadDefaults {
    pub(super) id: &'static str,
    pub(super) title: &'static str,
    pub(super) category: &'static str,
    pub(super) availability: &'static str,
    pub(super) file_path: Option<&'static str>,
    pub(super) updated_at_ms: Option<i64>,
    pub(super) content_type: Option<&'static str>,
}

#[derive(Clone)]
pub(super) struct StageWorkUnitDefaults {
    pub(super) id: &'static str,
    pub(super) title: &'static str,
    pub(super) agent_role: &'static str,
    pub(super) status: &'static str,
    pub(super) progress: f64,
    pub(super) depends_on: Vec<&'static str>,
    pub(super) current_output: Option<&'static str>,
    pub(super) next_step: &'static str,
}

#[derive(Clone)]
pub(super) struct StageDefaults {
    pub(super) objective: &'static str,
    pub(super) input_contexts: Vec<&'static str>,
    pub(super) step_progress: Value,
    pub(super) risk_items: Vec<&'static str>,
    pub(super) event_flow: Vec<&'static str>,
    pub(super) primary_action: &'static str,
    pub(super) secondary_actions: Vec<&'static str>,
    pub(super) downloads: Vec<StageDownloadDefaults>,
    pub(super) work_units: Vec<StageWorkUnitDefaults>,
}

pub(super) type StoreResult<T> = Result<T, String>;

impl Store {
    pub fn open(paths: &RuntimePaths) -> StoreResult<Self> {
        let conn = Connection::open(paths.db_path()).map_err(|err| err.to_string())?;
        conn.execute_batch(
            r#"
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 5000;
PRAGMA temp_store = MEMORY;
"#,
        )
        .map_err(|err| err.to_string())?;

        Ok(Self {
            conn,
            paths: paths.clone(),
        })
    }
}

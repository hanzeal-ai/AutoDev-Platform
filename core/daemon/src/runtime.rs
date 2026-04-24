use crate::protocol;
use serde_json::{json, Value};
use std::error::Error;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

#[derive(Clone)]
pub struct RuntimePaths {
    app_support_root: PathBuf,
    socket_path: PathBuf,
    data_dir: PathBuf,
    db_path: PathBuf,
    default_blobs_dir: PathBuf,
}

impl RuntimePaths {
    pub fn discover() -> Result<Self, Box<dyn Error>> {
        let app_support_root = app_support_root()?;
        let socket_path = app_support_root.join("ipc").join("daemon.sock");
        let data_dir = app_support_root.join("data");
        let db_path = data_dir.join("app.db");
        let default_blobs_dir = app_support_root.join("blobs");

        Ok(Self {
            app_support_root,
            socket_path,
            data_dir,
            db_path,
            default_blobs_dir,
        })
    }

    pub fn app_support_root(&self) -> &Path {
        &self.app_support_root
    }

    pub fn socket_path(&self) -> &Path {
        &self.socket_path
    }

    pub fn db_path(&self) -> &Path {
        &self.db_path
    }

    /// Returns the effective blobs directory, checking config.json each time
    /// so user changes take effect without restarting the daemon.
    pub fn blobs_dir(&self) -> PathBuf {
        read_custom_blobs_dir(&self.app_support_root)
            .unwrap_or_else(|| self.default_blobs_dir.clone())
    }

    #[cfg(test)]
    pub(crate) fn test_defaults() -> Self {
        Self {
            app_support_root: PathBuf::from("/tmp/autodev-test"),
            socket_path: PathBuf::from("/tmp/autodev-test/ipc/daemon.sock"),
            data_dir: PathBuf::from("/tmp/autodev-test/data"),
            db_path: PathBuf::from("/tmp/autodev-test/data/app.db"),
            default_blobs_dir: PathBuf::from("/tmp/autodev-test/blobs"),
        }
    }

    pub fn ensure_runtime_dirs(&self) -> Result<(), Box<dyn Error>> {
        let dir = self
            .socket_path
            .parent()
            .ok_or_else(|| "socket path has no parent".to_string())?;
        fs::create_dir_all(dir)?;
        fs::set_permissions(dir, fs::Permissions::from_mode(0o700))?;
        fs::create_dir_all(&self.data_dir)?;
        fs::create_dir_all(&self.blobs_dir())?;
        Ok(())
    }
}

pub fn health_payload(paths: &RuntimePaths) -> Value {
    let deepseek = DeepSeekConfig::from_env().ok();
    let ai_worker_available = crate::store::reports::llm::worker::worker_available();
    json!({
        "status": "ok",
        "daemon_version": env!("CARGO_PKG_VERSION"),
        "protocol_version": protocol::SCHEMA_VERSION,
        "app_support_root": paths.app_support_root().display().to_string(),
        "database_path": paths.db_path().display().to_string(),
        "blobs_path": paths.blobs_dir().display().to_string(),
        "deepseek_configured": deepseek.is_some(),
        "deepseek_model": deepseek.as_ref().map(|config| config.model()),
        "deepseek_base_url": deepseek.as_ref().map(|config| config.endpoint()),
        "ai_worker_available": ai_worker_available,
    })
}

#[derive(Clone)]
pub struct DeepSeekConfig {
    #[allow(dead_code)]
    api_key: String,
    base_url: String,
    model: String,
}

impl DeepSeekConfig {
    pub fn from_env() -> Result<Self, String> {
        let api_key = required_env("DEEPSEEK_API_KEY")?;
        let base_url = optional_env("DEEPSEEK_BASE_URL")
            .unwrap_or_else(|| "https://api.deepseek.com/v1".to_string());
        let model = optional_env("DEEPSEEK_MODEL").unwrap_or_else(|| "deepseek-chat".to_string());
        Ok(Self {
            api_key,
            base_url: base_url.trim_end_matches('/').to_string(),
            model,
        })
    }

    pub fn endpoint(&self) -> String {
        format!("{}/chat/completions", self.base_url)
    }

    pub fn model(&self) -> &str {
        &self.model
    }
}

fn app_support_root() -> Result<PathBuf, Box<dyn Error>> {
    let home = std::env::var("HOME")?;
    let mut root = PathBuf::from(home);
    root.push("Library");
    root.push("Application Support");
    root.push("com.sanmws.autodev");
    Ok(root)
}

/// Read a user-configured blobs directory from the shared config file.
/// Config file: `{app_support_root}/config.json` with `{"blobs_dir": "/custom/path"}`
/// Returns None if config file doesn't exist or doesn't contain a valid blobs_dir.
fn read_custom_blobs_dir(app_support_root: &Path) -> Option<PathBuf> {
    let config_path = app_support_root.join("config.json");
    let content = fs::read_to_string(&config_path).ok()?;
    let config: Value = serde_json::from_str(&content).ok()?;
    let blobs_dir = config.get("blobs_dir")?.as_str()?;
    if blobs_dir.is_empty() {
        return None;
    }
    let path = PathBuf::from(blobs_dir);
    // Only accept absolute paths to prevent path traversal
    if path.is_absolute() {
        Some(path)
    } else {
        None
    }
}

fn required_env(key: &str) -> Result<String, String> {
    optional_env(key).ok_or_else(|| format!("缺少环境变量 {key}"))
}

fn optional_env(key: &str) -> Option<String> {
    std::env::var(key)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

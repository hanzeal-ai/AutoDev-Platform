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
    blobs_dir: PathBuf,
}

impl RuntimePaths {
    pub fn discover() -> Result<Self, Box<dyn Error>> {
        let app_support_root = app_support_root()?;
        let socket_path = app_support_root.join("ipc").join("daemon.sock");
        let data_dir = app_support_root.join("data");
        let db_path = data_dir.join("app.db");
        let blobs_dir = app_support_root.join("blobs");

        Ok(Self {
            app_support_root,
            socket_path,
            data_dir,
            db_path,
            blobs_dir,
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

    pub fn blobs_dir(&self) -> &Path {
        &self.blobs_dir
    }

    pub fn ensure_runtime_dirs(&self) -> Result<(), Box<dyn Error>> {
        let dir = self
            .socket_path
            .parent()
            .ok_or_else(|| "socket path has no parent".to_string())?;
        fs::create_dir_all(dir)?;
        fs::set_permissions(dir, fs::Permissions::from_mode(0o700))?;
        fs::create_dir_all(&self.data_dir)?;
        fs::create_dir_all(&self.blobs_dir)?;
        Ok(())
    }
}

pub fn health_payload(paths: &RuntimePaths) -> Value {
    let deepseek = DeepSeekConfig::from_env().ok();
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
    })
}

#[derive(Clone)]
pub struct DeepSeekConfig {
    api_key: String,
    base_url: String,
    model: String,
}

impl DeepSeekConfig {
    pub fn from_env() -> Result<Self, String> {
        let api_key = required_env("DEEPSEEK_API_KEY")?;
        let base_url = optional_env("DEEPSEEK_BASE_URL")
            .unwrap_or_else(|| "https://api.deepseek.com".to_string());
        let model = optional_env("DEEPSEEK_MODEL").unwrap_or_else(|| "deepseek-chat".to_string());
        Ok(Self {
            api_key,
            base_url: base_url.trim_end_matches('/').to_string(),
            model,
        })
    }

    pub fn api_key(&self) -> &str {
        &self.api_key
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

fn required_env(key: &str) -> Result<String, String> {
    optional_env(key).ok_or_else(|| format!("缺少环境变量 {key}"))
}

fn optional_env(key: &str) -> Option<String> {
    std::env::var(key)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

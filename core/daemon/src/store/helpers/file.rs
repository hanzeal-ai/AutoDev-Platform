use std::path::Path;

pub(in crate::store) fn human_file_size(size: u64) -> String {
    const KB: f64 = 1024.0;
    const MB: f64 = KB * 1024.0;

    if (size as f64) >= MB {
        format!("{:.1} MB", (size as f64) / MB)
    } else if (size as f64) >= KB {
        format!("{:.0} KB", (size as f64) / KB)
    } else {
        format!("{size} B")
    }
}

pub(in crate::store) fn file_name_or_default(path: &Path, fallback: &str) -> String {
    path.file_name()
        .and_then(|value| value.to_str())
        .map(ToString::to_string)
        .unwrap_or_else(|| fallback.to_string())
}

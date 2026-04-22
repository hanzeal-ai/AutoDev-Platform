use chrono::Local;

pub(crate) fn info(message: impl AsRef<str>) {
    log("INFO", message.as_ref(), &[]);
}

pub(crate) fn error_fields(message: impl AsRef<str>, fields: &[(&str, String)]) {
    log("ERROR", message.as_ref(), fields);
}

fn log(level: &str, message: &str, fields: &[(&str, String)]) {
    eprintln!("{} [{}] {}", timestamp(), level, message);
    for (key, value) in fields {
        eprintln!("{} [{}] {}={}", timestamp(), level, key, sanitize(value));
    }
}

fn timestamp() -> String {
    Local::now().format("[%Y-%m-%d %H:%M:%S%.3f %:z]").to_string()
}

fn sanitize(value: &str) -> String {
    value.replace('\r', "\\r").replace('\n', "\\n")
}

mod http;
mod parse;

use super::super::{Store, StoreResult};
use rusqlite::params;

pub(super) const MAX_CONTEXT_MESSAGES: usize = 8;
pub(super) const MAX_CONTEXT_MATERIALS: usize = 6;

#[derive(Debug, Clone, serde::Serialize)]
pub(super) struct MessageContext {
    pub(super) role: String,
    pub(super) content: String,
}

#[derive(Debug, Clone, serde::Serialize)]
pub(super) struct MaterialContext {
    pub(super) name: String,
    pub(super) type_hint: String,
    pub(super) size_hint: String,
    pub(super) status: String,
}

pub(crate) use http::request_chat_message_streaming;
pub(crate) use http::request_json_object;

pub(super) fn list_recent_messages(
    store: &Store,
    thread_id: &str,
    limit: usize,
) -> StoreResult<Vec<MessageContext>> {
    let mut stmt = store
        .conn
        .prepare(
            r#"
SELECT role, content
FROM creation_messages
WHERE thread_id = ?1
ORDER BY created_at_ms DESC
LIMIT ?2
"#,
        )
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map(params![thread_id, limit as i64], |row| {
            Ok(MessageContext {
                role: row.get::<_, String>(0)?,
                content: row.get::<_, String>(1)?,
            })
        })
        .map_err(|err| err.to_string())?;

    let mut out = Vec::new();
    for row in rows {
        out.push(row.map_err(|err| err.to_string())?);
    }
    out.reverse();
    Ok(out)
}

pub(super) fn list_recent_materials(
    store: &Store,
    thread_id: &str,
    limit: usize,
) -> StoreResult<Vec<MaterialContext>> {
    let mut stmt = store
        .conn
        .prepare(
            r#"
SELECT name, type_hint, size_hint, analysis_status
FROM materials
WHERE thread_id = ?1
ORDER BY added_at_ms DESC
LIMIT ?2
"#,
        )
        .map_err(|err| err.to_string())?;
    let rows = stmt
        .query_map(params![thread_id, limit as i64], |row| {
            Ok(MaterialContext {
                name: row.get::<_, String>(0)?,
                type_hint: row.get::<_, String>(1)?,
                size_hint: row.get::<_, String>(2)?,
                status: row.get::<_, String>(3)?,
            })
        })
        .map_err(|err| err.to_string())?;

    let mut out = Vec::new();
    for row in rows {
        out.push(row.map_err(|err| err.to_string())?);
    }
    Ok(out)
}

pub(crate) fn truncate_text(input: &str, max_chars: usize) -> String {
    let mut out = String::new();
    for ch in input.chars().take(max_chars) {
        out.push(ch);
    }
    if input.chars().count() > max_chars {
        out.push_str("...");
    }
    out
}



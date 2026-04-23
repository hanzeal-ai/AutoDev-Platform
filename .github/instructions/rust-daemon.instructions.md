---
description: "Use when writing Rust daemon code — handlers, store methods, protocol constants, router dispatch. Covers error handling, logging, ID normalization, and module structure."
applyTo: "core/daemon/src/**/*.rs"
---
# Rust Daemon Conventions

## Error Handling

Use `StoreResult<T>` (alias for `Result<T, String>`). Convert all errors with `.map_err(|e| e.to_string())?`.

```rust
let conn = Connection::open(path).map_err(|err| err.to_string())?;
```

Never use `unwrap()` or `expect()` in production paths.

## Logging

Use `logger::info()`, `logger::error_fields()` with structured fields — not `println!` or `eprintln!`.

```rust
logger::error_fields("store_open_failed", &[("path", path.to_string())]);
```

## ID Normalization

Normalize all inbound IDs to lowercase before any DB operation:

```rust
let thread_id = inbound.payload_string("thread_id")?.to_lowercase();
```

## Store Pattern

Open a fresh `Store` per request — SQLite WAL mode handles concurrency:

```rust
let store = store::Store::open(runtime_paths)?;
```

## Query Handler Pattern

In `router/dispatch_query.rs`, add a match arm:

```rust
protocol::MESSAGE_QUERY_YOUR_QUERY => {
    let store = store::Store::open(runtime_paths);
    Some(store.and_then(|store| {
        Ok((protocol::MESSAGE_QUERY_YOUR_QUERY_OK, store.your_method()?))
    }))
}
```

## Command Handler Pattern

Create a handler file in `router/dispatch_command/`, expose `handle_*` functions:

```rust
pub(super) fn handle_your_command(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    let id = inbound.payload_string("id")?.to_lowercase();
    let store = store::Store::open(runtime_paths)?;
    Ok((protocol::MESSAGE_COMMAND_YOUR_COMMAND_OK, store.your_method(&id)?))
}
```

## Store Module Structure

Organize under `store/<domain>/`:
- `mod.rs` — declares submodules, `impl Store` blocks delegate to inner functions
- `query/` — read operations returning `StoreResult<Value>`
- `command/` — write operations

All SQL functions take `&Store` as first param, use `store.conn` for queries:

```rust
pub(super) fn your_query(store: &Store) -> StoreResult<Value> {
    let mut stmt = store.conn
        .prepare("SELECT ... FROM ...")
        .map_err(|err| err.to_string())?;
    // ...
    Ok(json!({ "items": items }))
}
```

## Message Type Constants

Define in `protocol/constants.rs` with naming pattern:
- Query: `MESSAGE_QUERY_<ACTION>` / `MESSAGE_QUERY_<ACTION>_OK`
- Command: `MESSAGE_COMMAND_<ACTION>` / `MESSAGE_COMMAND_<ACTION>_OK`

Always add both the request and `_OK` response constants.

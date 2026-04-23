---
description: "Generate a new Rust daemon store submodule with query and command files following project conventions."
agent: "agent"
argument-hint: "Domain name, e.g. 'reports' or 'workflows'"
---
Generate a new store submodule for the Rust daemon at `core/daemon/src/store/{{domain}}/`.

Create the following file structure:

```
store/{{domain}}/
├── mod.rs       # Declares submodules, impl Store delegation
├── query.rs     # Read operations (StoreResult<Value>)
└── command.rs   # Write operations (StoreResult<Value>)
```

Follow these conventions from the existing codebase:

1. **mod.rs** — Declare `mod query;` and `mod command;`, add `impl Store` blocks that delegate to inner functions:
```rust
mod command;
mod query;

use super::{Store, StoreResult};
use serde_json::Value;

impl Store {
    pub fn list_{{domain}}(&self) -> StoreResult<Value> {
        query::list_{{domain}}(self)
    }
}
```

2. **query.rs** — Functions take `&Store`, use `store.conn` for SQL, return `StoreResult<Value>`:
```rust
use super::super::{Store, StoreResult};
use serde_json::{json, Value};

pub(super) fn list_{{domain}}(store: &Store) -> StoreResult<Value> {
    let mut stmt = store.conn
        .prepare("SELECT ... FROM {{domain}} ...")
        .map_err(|err| err.to_string())?;
    // query_map, collect, return json!
}
```

3. **command.rs** — Same pattern for writes, use `rusqlite::params![]`:
```rust
use super::super::{Store, StoreResult};
use serde_json::{json, Value};
use rusqlite::params;

pub(super) fn create_{{domain}}_item(store: &Store, ...) -> StoreResult<Value> {
    store.conn.execute("INSERT INTO ...", params![...])
        .map_err(|err| err.to_string())?;
    Ok(json!({ "id": id }))
}
```

4. **Register** the module in `core/daemon/src/store.rs` by adding `mod {{domain}};`

5. All errors use `.map_err(|err| err.to_string())?`
6. All IDs normalized to lowercase
7. Timestamps use `crate::protocol::time::now_ms()`

Reference existing modules for patterns: [store/threads/](core/daemon/src/store/threads/), [store/projects/](core/daemon/src/store/projects/)

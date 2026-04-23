---
name: add-ipc-message
description: "Add a new IPC message type (query or command) across both Rust daemon and Swift app. Use when adding a new daemon endpoint, new query, or new command. Handles constants, handlers, store methods, and Swift-side contract sync."
argument-hint: "e.g. 'query.list_reports' or 'command.delete_project'"
---
# Add IPC Message Type

End-to-end workflow for adding a new query or command to the IPC protocol.

## When to Use
- Adding a new daemon endpoint (query or command)
- Extending daemon capabilities with new read/write operations

## Procedure

### Step 1: Determine Type

- **Query** (`query.*`): Read-only, returns data. No side effects.
- **Command** (`command.*`): Write operation, modifies state.

### Step 2: Add Rust Constants

In [core/daemon/src/protocol/constants.rs](../../../core/daemon/src/protocol/constants.rs), add both request and response constants:

```rust
// Query example
pub const MESSAGE_QUERY_YOUR_ACTION: &str = "query.your_action";
pub const MESSAGE_QUERY_YOUR_ACTION_OK: &str = "query.your_action.ok";

// Command example
pub const MESSAGE_COMMAND_YOUR_ACTION: &str = "command.your_action";
pub const MESSAGE_COMMAND_YOUR_ACTION_OK: &str = "command.your_action.ok";
```

### Step 3: Add Store Method

Create or extend a store submodule in `core/daemon/src/store/<domain>/`:

```rust
pub(super) fn your_method(store: &Store) -> StoreResult<Value> {
    // SQL query using store.conn
    // Return json!({...})
}
```

Expose via `impl Store` block in the submodule's `mod.rs`.

### Step 4: Add Router Handler

**For queries** — add match arm in [core/daemon/src/router/dispatch_query.rs](../../../core/daemon/src/router/dispatch_query.rs):

```rust
protocol::MESSAGE_QUERY_YOUR_ACTION => {
    let store = store::Store::open(runtime_paths);
    Some(store.and_then(|store| {
        Ok((protocol::MESSAGE_QUERY_YOUR_ACTION_OK, store.your_method()?))
    }))
}
```

**For commands** — create handler file in `core/daemon/src/router/dispatch_command/`:

```rust
pub(super) fn handle_your_action(
    inbound: &protocol::EnvelopeIn,
    runtime_paths: &runtime::RuntimePaths,
) -> Result<(&'static str, Value), String> {
    let id = inbound.payload_string("id")?.to_lowercase();
    let store = store::Store::open(runtime_paths)?;
    Ok((protocol::MESSAGE_COMMAND_YOUR_ACTION_OK, store.your_method(&id)?))
}
```

Then add match arm in `dispatch_command/mod.rs` and declare the module.

### Step 5: Sync Swift Constants

In [apps/macos/AutoDevDesktop/Sources/AutoDevDesktop/Services/IPC/Contract/IPCMessageType.swift](../../../apps/macos/AutoDevDesktop/Sources/AutoDevDesktop/Services/IPC/Contract/IPCMessageType.swift), add:

```swift
static let yourActionQuery = "query.your_action"
static let yourActionSuccess = "query.your_action.ok"
```

String values MUST match the Rust constants exactly.

### Step 6: Add DaemonClient Method

1. Add method to `DaemonQuerying` protocol in `Services/Daemon/DaemonQuerying.swift`
2. Implement in `DaemonClient` extensions (`DaemonClientQueries.swift` or `DaemonClientCommands.swift`)
3. Add request builder in `DaemonClientRequestBuilding.swift`
4. Add response decoder in `DaemonClientDecoding.swift` if new payload type

### Step 7: Verify

```bash
cargo build --manifest-path core/daemon/Cargo.toml
cargo test --manifest-path core/daemon/Cargo.toml
cd apps/macos/AutoDevDesktop && swift build
```

## Checklist

- [ ] Rust constants added (request + `.ok` response)
- [ ] Store method implemented with `StoreResult<Value>`
- [ ] Router handler added (query dispatch or command dispatch)
- [ ] Command module declared in `dispatch_command/mod.rs` (commands only)
- [ ] Swift `IPCContract.MessageType` constants added (matching strings)
- [ ] `DaemonQuerying` protocol updated
- [ ] `DaemonClient` implementation added
- [ ] Both Rust and Swift build successfully

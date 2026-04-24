# Desktop Initialization Plan v0.1

## 1. Source Constraint

This bootstrap plan is derived from:

- `01-System-Blueprint-v0.1.md`
- `04-SwiftUI-Rust-Process-Communication-v0.1.md`

Non-negotiable direction:

- native `SwiftUI/AppKit` macOS client
- separate `Rust core daemon`
- process boundary through local IPC
- UI is thin shell; daemon owns write path

## 2. Minimum Buildable Scope

Build the smallest vertical slice that proves the architecture seam:

1. macOS app starts and renders shell UI.
2. Rust daemon runs as an independent process.
3. UI connects to daemon through Unix domain socket.
4. UI sends `GetHealth` query and displays result.

No domain write logic or event store is required in this first slice.

## 3. Why This Is The Shortest Path

- validates process split early (main architectural risk)
- provides immediate UI preview loop for product iteration
- creates stable place to add protocol/versioning next
- avoids fake monolithic UI-first implementation

## 4. First Iteration Decisions

- IPC transport in iteration 1:
  - Unix domain socket
  - newline framed JSON for bootstrap speed
- Compatibility target:
  - message envelope already includes `message_id`, `correlation_id`, `message_type`, `schema_version`, `timestamp`, `payload`
- Upgrade path:
  - keep handler boundaries ready for framed Protobuf migration

## 5. Output Of This Iteration

- `apps/macos/AutoDevDesktop`: runnable SwiftUI/AppKit shell
- `core/daemon`: runnable Rust daemon
- `scripts/dev-preview.sh`: local one-command preview flow

## 6. Not Implemented Yet (Explicitly Deferred)

- `launchd` supervision and plist installation
- framed Protobuf and schema codegen pipeline
- projection database read layer
- command bus/event store/projection engine modules
- auth/session verification

## 7. Exit Criteria For v0.1 Bootstrap

- app window opens with daemon status panel
- clicking health check returns daemon version and protocol version
- app can reconnect after daemon restart


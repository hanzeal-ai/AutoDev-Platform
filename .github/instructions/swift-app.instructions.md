---
description: "Use when writing Swift/SwiftUI code for the macOS app — views, view models, IPC contracts, daemon client. Covers MVVM pattern, threading, protocol injection, and optimistic UI."
applyTo: "apps/macos/AutoDevDesktop/**/*.swift"
---
# Swift App Conventions

## Architecture

MVVM with centralized state:
- `ShellViewModel` — `@MainActor` coordinator, owns `ShellViewState`
- `ShellViewState` — single source of truth for all UI state
- Views — `@ObservedObject` binding to `viewModel`, call `viewModel.method()` only

Never call `DaemonClient` directly from views. Always inject `DaemonQuerying` protocol.

## Threading

- `@MainActor` on all view models
- `async/await` for all daemon calls — no completion handlers
- Use `.task { }` modifier for view lifecycle async work

## DaemonQuerying Protocol

All daemon communication goes through this protocol for testability:

```swift
protocol DaemonQuerying {
    func getHealth() async throws -> DaemonHealth
    func listProjects() async throws -> [DaemonProject]
    // ... all query/command methods
}
```

Inject via init: `init(daemonClient: DaemonQuerying = DaemonClient())`

## IPC Message Types

Define in `Services/IPC/Contract/IPCMessageType.swift` as static properties on `IPCContract.MessageType`:

```swift
extension IPCContract {
    enum MessageType {
        static let yourQuery = "query.your_action"
        static let yourQuerySuccess = "query.your_action.ok"
    }
}
```

Keep in sync with `core/daemon/src/protocol/constants.rs` — same string values.

## Request Envelope

Use `IPCRequestEnvelope.make()` factory:

```swift
let envelope = IPCRequestEnvelope.make(
    messageType: IPCContract.MessageType.yourCommand,
    payload: ["id": id]
)
```

## Optimistic UI

For immediate feedback, use transient state:
1. Append transient item to UI state
2. Send command to daemon
3. On response, remove transient item and merge daemon data

## File Organization

Folders mirror functional domains:
- `State/` — ViewModels, ViewState, extensions by concern
- `Services/Daemon/` — Client, protocol, bootstrapper
- `Services/IPC/Contract/` — Message types, envelopes, decoder
- `Models/` — DTOs grouped by domain (`Daemon/`, `Creation/`, `Execution/`)
- `Views/Pages/` — Full-screen views
- `Views/Components/` — Reusable UI components

## UI Strings

UI strings are in Chinese (e.g., "总览", "项目库", "刚刚"). Maintain this convention.

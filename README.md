# AI AutoDev Platform

AI-driven software delivery platform. The native SwiftUI/AppKit desktop app talks to a Rust backend API over HTTP RPC, so the same contract can run locally or behind a deployed server endpoint.

## Current Architectural Stance

- Mac-first client with server-deployable backend.
- `SwiftUI/AppKit` for native macOS experience.
- `Rust` as the system core language.
- `Artifact Graph + Event Log` as the system of record.
- Modular monolith first, event-driven inside, workers for async integration.
- Server-oriented execution with local development defaults.

## What Is Intentionally Not Frozen Yet

- Exact database schemas
- Exact API payloads
- Exact sync protocol format
- Exact model vendors and routing policy
- Exact plugin SDK surface

These should be designed after the bounded contexts and event contracts are stable.

## Bootstrap Skeleton (Implemented)

- `apps/macos/AutoDevDesktop`
  - Native macOS shell app (`SwiftUI + AppKit`).
- `core/daemon`
  - Rust backend API that owns runtime boundary and exposes HTTP RPC, including the structured stage-detail payload used by the shell.
- `scripts/dev-preview.sh`
  - Starts the daemon and opens the Xcode project for normal macOS development.
- `scripts/dev-daemon.sh`
  - Runs the Rust daemon independently while Xcode handles the app.

## Code Boundaries

- `apps/macos/AutoDevDesktop/Sources/AutoDevDesktop/ContentView.swift`
  - UI shell only: layout, presentation, and user interaction wiring.
- `apps/macos/AutoDevDesktop/Sources/AutoDevDesktop/ShellViewModel.swift`
  - UI-facing state and async orchestration, but no core business rules.
- `apps/macos/AutoDevDesktop/Sources/AutoDevDesktop/IPCContract.swift`
  - Swift-side envelope contract and payload decoding.
- `apps/macos/AutoDevDesktop/Sources/AutoDevDesktop/DaemonClient.swift`
  - HTTP backend client configuration.
- `core/daemon/src/protocol.rs`
  - Rust-side envelopes and message contract.
- `core/daemon/src/runtime.rs`
  - Runtime paths and daemon-owned runtime metadata.
- `core/daemon/src/main.rs`
  - Process entrypoint and request routing.

## Standard macOS Development Flow

1. Start the backend API in one terminal:

```bash
./scripts/dev-daemon.sh
```

1. Open the project in Xcode:

```bash
open apps/macos/AutoDevDesktop/AutoDevDesktop.xcodeproj
```

1. Use the normal Xcode loop:

- run the `AutoDevDesktop` scheme
- use SwiftUI Preview in `ContentView.swift` (recommended entry file)
- iterate on UI without needing the daemon for previews

## Quick Start

### Local environment

Create a local `.env` file before starting the AI worker. This file contains
private API keys and must not be committed.

Required values:

```bash
DEEPSEEK_API_KEY=your_deepseek_key
LANGSMITH_TRACING=true
LANGSMITH_ENDPOINT=https://api.smith.langchain.com
LANGSMITH_API_KEY=your_langsmith_key
LANGSMITH_PROJECT=autodev
```

### Option A: One-command preview

```bash
./scripts/dev-preview.sh
```

### Option B: Split terminals

Terminal 1:

```bash
./scripts/dev-daemon.sh
```

Terminal 2:

```bash
open apps/macos/AutoDevDesktop/AutoDevDesktop.xcodeproj
```

The app opens a shell window and runs a backend health check through HTTP RPC. Local development defaults to `http://127.0.0.1:7373`; set `AUTODEV_API_BASE_URL` for a deployed server endpoint.

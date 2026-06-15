# AI AutoDev Platform

Mac-first AI-driven software delivery platform. The native SwiftUI/AppKit desktop app talks to a Rust daemon over local Unix socket IPC.

## Current Architectural Stance

- Mac-first product, cloud-assisted collaboration.
- `SwiftUI/AppKit` for native macOS experience.
- `Rust` as the system core language.
- `Artifact Graph + Event Log` as the system of record.
- Modular monolith first, event-driven inside, workers for async integration.
- Local-first execution with cloud sync.

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
  - Rust daemon that owns runtime boundary and listens on Unix domain socket, including the structured stage-detail payload used by the shell.
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
  - Swift-side IPC contract and payload decoding.
- `apps/macos/AutoDevDesktop/Sources/AutoDevDesktop/DaemonClient.swift`
  - Unix socket transport only.
- `core/daemon/src/protocol.rs`
  - Rust-side IPC envelopes and message contract.
- `core/daemon/src/runtime.rs`
  - Runtime paths and daemon-owned runtime metadata.
- `core/daemon/src/main.rs`
  - Process entrypoint and request routing.

## Standard macOS Development Flow

1. Start the daemon in one terminal:

```bash
./scripts/dev-daemon.sh
```

2. Open the project in Xcode:

```bash
open apps/macos/AutoDevDesktop/AutoDevDesktop.xcodeproj
```

3. Use the normal Xcode loop:

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

The app opens a shell window and runs a daemon health check through local Unix socket IPC.

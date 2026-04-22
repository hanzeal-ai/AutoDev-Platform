# AI AutoDev System Architecture

This folder contains the first formal architecture drafts for the Mac-first software delivery system.

## Documents

1. `01-System-Blueprint-v0.1.md`
   Defines the system boundary, architecture principles, context map, runtime topology, and key non-functional requirements.
2. `02-Core-Domain-Model-v0.1.md`
   Defines bounded contexts, aggregates, ownership, state transitions, and artifact relationships.
3. `03-Command-Event-Catalog-v0.1.md`
   Defines the command and domain event contracts used to decouple modules.
4. `04-SwiftUI-Rust-Process-Communication-v0.1.md`
   Defines the macOS client process topology, IPC transport, read/write split, crash recovery, and protocol rules between the Swift UI and the Rust core daemon.
5. `06-macOS-UI-Shell-v1.md`
   Defines the current macOS UI shell layout, component boundaries, backend data contracts, and page split between overview control panel, project library directory, and AI conversation-driven project creation flow.
6. `07-Local-Backend-Data-Chain-v0.1.md`
   Defines the local SQLite schema, runtime file layout, IPC message contract, and the first real data chain between Swift UI and Rust daemon.
7. `08-Figma-AI-Budget-and-UI-Constraints-v1.md`
   Defines the Figma AI free-plan budget facts and the prompt-batching rules for future UI design work on this project.

## Reading Order

1. Read the system blueprint first.
2. Read the core domain model second.
3. Read the command and event catalog third.
4. Read the process communication design fourth.

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

- `05-Desktop-Initialization-Plan-v0.1.md`
  - Minimal desktop initialization strategy derived from docs `01` and `04`.
- `apps/macos/AutoDevDesktop`
  - Native macOS shell app (`SwiftUI + AppKit`).
- `06-macOS-UI-Shell-v1.md`
  - UI-shell documentation for `sidebar + header + body` structure, narrowed/collapsible sidebar, control-panel overview modules, project-library interactions, AI creation threads, stage-detail control view, and backend field requirements.
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

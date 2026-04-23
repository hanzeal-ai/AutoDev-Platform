# Project Guidelines

## Overview

Mac-first AI-driven software delivery platform. SwiftUI/AppKit frontend communicates with a Rust daemon over Unix domain socket IPC using line-delimited JSON envelopes.

Architecture docs: [01-System-Blueprint-v0.1.md](01-System-Blueprint-v0.1.md) → [02-Core-Domain-Model-v0.1.md](02-Core-Domain-Model-v0.1.md) → [03-Command-Event-Catalog-v0.1.md](03-Command-Event-Catalog-v0.1.md) → [04-SwiftUI-Rust-Process-Communication-v0.1.md](04-SwiftUI-Rust-Process-Communication-v0.1.md)

## Code Boundaries

| Layer | Path | Language | Responsibility |
|-------|------|----------|----------------|
| macOS App | `apps/macos/AutoDevDesktop/Sources/AutoDevDesktop/` | Swift 5.5+ / SwiftUI | UI shell, state, IPC client |
| Rust Daemon | `core/daemon/src/` | Rust 2021 | Business logic, SQLite, AI integration |
| Scripts | `scripts/` | Bash | Dev tooling, log routing |
| Architecture Docs | `*.md` (root) | Markdown | System design specs |

Never put business logic in the Swift layer. The daemon owns all domain rules and write paths.

## Build and Test

### Rust Daemon

```bash
# Build
cargo build --manifest-path core/daemon/Cargo.toml

# Run (dev, with log routing)
./scripts/dev-daemon.sh

# Run (cargo run, with live logs)
./scripts/dev-daemon-runner.sh

# Test
cargo test --manifest-path core/daemon/Cargo.toml
```

Requires `DEEPSEEK_API_KEY` env var for AI features. Loaded from `.env`, `.env.local`, or `~/.config/autodev/deepseek.env`.

### macOS App

```bash
# Open in Xcode
open apps/macos/AutoDevDesktop/AutoDevDesktop.xcodeproj

# Full dev loop (daemon + Xcode)
./scripts/dev-preview.sh

# Build via command line
cd apps/macos/AutoDevDesktop && swift build
```

Target: macOS 12+. Use SwiftUI Preview in `ContentView.swift` for fast UI iteration without the daemon.

## Architecture Conventions

### IPC Protocol

- Transport: Unix domain socket at `~/Library/Application Support/com.sanmws.autodev/ipc/daemon.sock`
- Format: Line-delimited JSON with envelope wrapper (see [04-SwiftUI-Rust-Process-Communication-v0.1.md](04-SwiftUI-Rust-Process-Communication-v0.1.md))
- Schema version: `1`
- Message types defined in `core/daemon/src/protocol/constants.rs` (Rust) and `Sources/AutoDevDesktop/Services/IPC/Contract/` (Swift) — keep both in sync
- Queries are read-only (`query.*`), commands are writes (`command.*`)

### Rust Daemon Conventions

- Error handling: `Result<T, String>` via `StoreResult<T>` alias — use `.map_err(|e| e.to_string())?`
- Logging: `logger::info()`, `logger::error_fields()` with structured fields
- IDs: Normalize to lowercase before DB operations
- Store: Open fresh `Store` per request (SQLite WAL mode handles concurrency)
- Database: SQLite with `PRAGMA foreign_keys = ON; journal_mode = WAL; synchronous = NORMAL`
- New message types: Add constant in `protocol/constants.rs`, handler in `router/dispatch_command/` or `router/dispatch_query.rs`, store method in `store/`

### Swift App Conventions

- Pattern: MVVM — `ShellViewModel` (coordinator) + `ShellViewState` (single source of truth) + SwiftUI views
- Threading: `@MainActor` on view models, `async/await` for all daemon calls
- Testability: Inject `DaemonQuerying` protocol, never call `DaemonClient` directly from views
- Optimistic UI: Use transient state for immediate feedback, reconcile on daemon response
- File organization: Folders mirror functional domains (`State/`, `Services/`, `Models/`, `Views/`)
- UI strings are in Chinese (e.g., "总览", "项目库")

## Git Workflow

```
main (release) ← preview (stable) ← develop (integration) ← agent/* (feature branches)
```

See [09-Development-Orchestration-Workflow-v0.1.md](09-Development-Orchestration-Workflow-v0.1.md) for merge gates and preview policy.

## Runtime Paths

```
~/Library/Application Support/com.sanmws.autodev/
├── ipc/daemon.sock    # Unix socket
├── data/app.db        # SQLite database
└── blobs/             # File storage
```

Logs: `logs/autodev-daemon/` (combined, info, warn, error — routed by `scripts/log-router.sh`)

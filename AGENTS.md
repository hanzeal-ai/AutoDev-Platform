# Project Guidelines

## Overview

Mac-first AI-driven software delivery platform. SwiftUI/AppKit frontend communicates with a Rust backend API over HTTP RPC using JSON envelopes.

Architecture docs: [01-System-Blueprint-v0.1.md](01-System-Blueprint-v0.1.md) → [02-Core-Domain-Model-v0.1.md](02-Core-Domain-Model-v0.1.md) → [03-Command-Event-Catalog-v0.1.md](03-Command-Event-Catalog-v0.1.md) → [04-SwiftUI-Rust-Process-Communication-v0.1.md](04-SwiftUI-Rust-Process-Communication-v0.1.md)

## Code Boundaries

| Layer | Path | Language | Responsibility |
|-------|------|----------|----------------|
| macOS App | `apps/macos/AutoDevDesktop/Sources/AutoDevDesktop/` | Swift 5.5+ / SwiftUI | UI shell, state, HTTP API client |
| Rust Daemon | `core/daemon/src/` | Rust 2021 | Business logic, SQLite, AI integration |
| AI Worker | `core/ai-worker/` | Python | LLM workflow, LangGraph orchestration, OpenSpec coding provider, AI Worker HTTP service |
| Scripts | `scripts/` | Bash | Dev tooling, log routing |
| Private Design Docs | `docs/` | Markdown / diagrams | Local project design notes; ignored and not published |

Never put business logic in the Swift layer. The daemon owns all domain rules and write paths.
Do not put persistence ownership or UI state into the AI Worker. It should return structured AI outputs and workflow events to the daemon.

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

### AI Worker

```bash
# Run tests
core/ai-worker/.venv/bin/pytest core/ai-worker/tests -q
```

Requires model credentials from local `.env`. OpenSpec is used only inside the coding phase for the generated target project. Its `openspec/` and generated Codex skill files must be created under that target project's workspace, not inside this AutoDev platform repository.

## Architecture Conventions

### Backend RPC Protocol

- Transport: HTTP RPC at `AUTODEV_API_BASE_URL` (default `http://127.0.0.1:7373`)
- Format: JSON envelope wrapper over `POST /rpc`; streaming commands return newline-delimited JSON envelopes.
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
├── data/app.db        # SQLite database
└── blobs/             # File storage
```

Logs: `logs/autodev-daemon/` (combined, info, warn, error — routed by `scripts/log-router.sh`)

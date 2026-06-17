#!/usr/bin/env bash
# -------------------------------------------------------------------
# dev-preview.sh — Start the full dev stack:
#   1. Python AI Worker  (LangGraph + FastAPI, port 9720)
#   2. Rust Backend API  (HTTP RPC, port 7373 by default)
#   3. Xcode             (SwiftUI app)
#
# Ctrl-C or closing the terminal stops all processes cleanly.
# -------------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/apps/macos/AutoDevDesktop"
PROJECT_FILE="$PROJECT_DIR/AutoDevDesktop.xcodeproj"
LOG_DIR="$ROOT_DIR/logs"
WORKER_LOG="$LOG_DIR/autodev-ai-worker"

WORKER_PID=""
DAEMON_PID=""

# ── Cleanup on exit ────────────────────────────────────────────────
cleanup() {
  echo ""
  echo "[dev-preview] Shutting down..."

  if [[ -n "$DAEMON_PID" ]]; then
    echo "[dev-preview] Stopping Rust Backend API (pid $DAEMON_PID)"
    kill "$DAEMON_PID" 2>/dev/null || true
    wait "$DAEMON_PID" 2>/dev/null || true
  fi

  if [[ -n "$WORKER_PID" ]]; then
    echo "[dev-preview] Stopping AI Worker (pid $WORKER_PID)"
    kill "$WORKER_PID" 2>/dev/null || true
    wait "$WORKER_PID" 2>/dev/null || true
  fi

  echo "[dev-preview] All services stopped."
}

trap cleanup EXIT INT TERM

# ── Validate prerequisites ─────────────────────────────────────────
if [[ ! -d "$PROJECT_FILE" ]]; then
  echo "[dev-preview] Missing Xcode project: $PROJECT_FILE" >&2
  exit 1
fi

mkdir -p "$LOG_DIR" "$WORKER_LOG"

# ── 1. Start Python AI Worker ─────────────────────────────────────
echo "[dev-preview] Starting Python AI Worker..."
"$ROOT_DIR/scripts/dev-ai-worker.sh" \
  >"$WORKER_LOG/combined.log" 2>&1 &
WORKER_PID=$!

# Wait briefly and verify worker started
sleep 2
if ! kill -0 "$WORKER_PID" 2>/dev/null; then
  if grep -q "AI Worker already running" "$WORKER_LOG/combined.log" 2>/dev/null; then
    echo "[dev-preview] AI Worker already running"
  else
    echo "[dev-preview] ⚠ AI Worker failed to start (check $WORKER_LOG/combined.log)"
    echo "[dev-preview] Continuing without AI Worker — Rust will use direct DeepSeek fallback."
  fi
  WORKER_PID=""
else
  echo "[dev-preview] AI Worker started (pid $WORKER_PID)"
fi

# ── 2. Start Rust Backend API ─────────────────────────────────────
echo "[dev-preview] Starting Rust Backend API..."
"$ROOT_DIR/scripts/dev-daemon.sh" &
DAEMON_PID=$!
sleep 1
echo "[dev-preview] Rust Backend API started (pid $DAEMON_PID, ${AUTODEV_API_BASE_URL:-http://127.0.0.1:7373})"

# ── 3. Open Xcode ─────────────────────────────────────────────────
echo "[dev-preview] Opening Xcode..."
open -a Xcode "$PROJECT_FILE"

# ── Wait for daemon (primary process) ─────────────────────────────
echo "[dev-preview] All services running. Press Ctrl-C to stop."
wait "$DAEMON_PID"

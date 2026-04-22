#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/apps/macos/AutoDevDesktop"
PROJECT_FILE="$PROJECT_DIR/AutoDevDesktop.xcodeproj"
LOG_DIR="$ROOT_DIR/logs"

cleanup() {
  if [[ -n "${DAEMON_PID:-}" ]]; then
    kill "$DAEMON_PID" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT INT TERM

mkdir -p "$LOG_DIR"
"$ROOT_DIR/scripts/dev-daemon.sh" &
DAEMON_PID=$!

if [[ ! -d "$PROJECT_FILE" ]]; then
  echo "Missing Xcode project: $PROJECT_FILE" >&2
  exit 1
fi

open -a Xcode "$PROJECT_FILE"
wait "$DAEMON_PID"

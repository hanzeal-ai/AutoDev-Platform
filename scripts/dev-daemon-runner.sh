#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DAEMON_MANIFEST="$ROOT_DIR/core/daemon/Cargo.toml"
LOG_DIR="$ROOT_DIR/logs"
LOG_BASE="autodev-daemon"

export PATH="/opt/homebrew/bin:/opt/homebrew/opt/rust/bin:/usr/local/bin:$HOME/.cargo/bin:$PATH"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %z'
}

resolve_cargo() {
  local candidates=(
    "/opt/homebrew/bin/cargo"
    "/usr/local/bin/cargo"
    "$HOME/.cargo/bin/cargo"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  command -v cargo
}

CARGO_BIN="$(resolve_cargo)"
if [[ -z "${CARGO_BIN:-}" ]]; then
  mkdir -p "$LOG_DIR/$LOG_BASE"
  echo "[$(timestamp)] [ERROR] cargo not found" >"$LOG_DIR/$LOG_BASE/error.log"
  exit 1
fi

"$CARGO_BIN" run --manifest-path "$DAEMON_MANIFEST" 2>&1 | "$ROOT_DIR/scripts/log-router.sh" "$LOG_DIR" "$LOG_BASE"

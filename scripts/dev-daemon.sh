#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DAEMON_MANIFEST="$ROOT_DIR/core/daemon/Cargo.toml"
DAEMON_BIN="$ROOT_DIR/core/daemon/target/debug/autodev-daemon"
LOG_BASE="autodev-daemon"

export PATH="/opt/homebrew/bin:/opt/homebrew/opt/rust/bin:/usr/local/bin:$HOME/.cargo/bin:$PATH"

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

load_env_file() {
  local env_file="$1"
  if [[ -f "$env_file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        ""|\#*) continue ;;
      esac

      local key="${line%%=*}"
      local value="${line#*=}"

      key="${key#"${key%%[![:space:]]*}"}"
      key="${key%"${key##*[![:space:]]}"}"
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"

      if [[ -z "$key" || -z "$value" ]]; then
        continue
      fi

      export "$key=$value"
    done < "$env_file"
  fi
}

load_env_file "$ROOT_DIR/.env"
load_env_file "$ROOT_DIR/.env.local"
load_env_file "$HOME/.config/autodev/deepseek.env"

# ── Timezone guard ───────────────────────────────────────────────────────────
# Read the real system timezone directly from /etc/localtime and force-export
# TZ so that chrono::Local (Rust) and time.localtime (Python) both show the
# correct local time even when a proxy or parent shell has injected TZ=UTC.
_autodev_tz="$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')"
if [[ -n "$_autodev_tz" ]]; then
    export TZ="$_autodev_tz"
else
    # Fallback: unset so libc reads /etc/localtime directly
    unset TZ 2>/dev/null || true
fi
unset _autodev_tz

if pgrep -x autodev-daemon >/dev/null 2>&1; then
  pkill -x autodev-daemon >/dev/null 2>&1 || true
  for _ in {1..30}; do
    if ! pgrep -x autodev-daemon >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done
  pkill -9 -x autodev-daemon >/dev/null 2>&1 || true
fi

mkdir -p "$ROOT_DIR/logs/$LOG_BASE"
CARGO_BIN="$(resolve_cargo)"
if [[ -z "${CARGO_BIN:-}" ]]; then
  echo "cargo not found" >>"$ROOT_DIR/logs/$LOG_BASE/error.log"
  exit 1
fi

"$CARGO_BIN" build --manifest-path "$DAEMON_MANIFEST" >>"$ROOT_DIR/logs/$LOG_BASE/combined.log" 2>&1
echo "Starting autodev-daemon HTTP server on ${AUTODEV_BIND_ADDR:-127.0.0.1:7373}" >>"$ROOT_DIR/logs/$LOG_BASE/combined.log"
exec "$DAEMON_BIN" >>"$ROOT_DIR/logs/$LOG_BASE/combined.log" 2>&1

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT_DIR/scripts/dev-daemon-runner.sh"
LOG_BASE="autodev-daemon"

if [[ ! -x "$RUNNER" ]]; then
  echo "Missing daemon runner: $RUNNER" >&2
  exit 1
fi

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
exec nohup "$RUNNER"

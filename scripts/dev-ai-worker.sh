#!/usr/bin/env bash
# Start the Python AI Worker (LangGraph + FastAPI) for development.
# Usage: ./scripts/dev-ai-worker.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORKER_DIR="$PROJECT_ROOT/core/ai-worker"

# Load env vars
for envfile in "$PROJECT_ROOT/.env" "$PROJECT_ROOT/.env.local" "$HOME/.config/autodev/deepseek.env"; do
  if [[ -f "$envfile" ]]; then
    set -a
    source "$envfile"
    set +a
  fi
done

# ── Timezone guard ───────────────────────────────────────────────────────────
# Read the real system timezone from /etc/localtime and force-export TZ so
# that Python's time.localtime() shows the correct local time even when a
# proxy or parent shell has injected TZ=UTC into the environment.
_autodev_tz="$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')"
if [[ -n "$_autodev_tz" ]]; then
    export TZ="$_autodev_tz"
else
    unset TZ 2>/dev/null || true
fi
unset _autodev_tz

# Check Python
if ! command -v python3 &>/dev/null; then
  echo "Error: python3 not found"
  exit 1
fi

# Setup venv if needed
VENV_DIR="$WORKER_DIR/.venv"
if [[ ! -d "$VENV_DIR" ]]; then
  echo "Creating virtual environment..."
  python3 -m venv "$VENV_DIR"
  "$VENV_DIR/bin/pip" install -e "$WORKER_DIR[dev]"
fi

PORT="${AI_WORKER_PORT:-9720}"

# Skip if already running on the target port
if lsof -iTCP:"$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "AI Worker already running on port $PORT, skipping."
  exit 0
fi

echo "Starting AI Worker on port $PORT..."
exec "$VENV_DIR/bin/uvicorn" autodev_ai.main:app \
  --host 127.0.0.1 \
  --port "$PORT" \
  --reload \
  --app-dir "$WORKER_DIR"

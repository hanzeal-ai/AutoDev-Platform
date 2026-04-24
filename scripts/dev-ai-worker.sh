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

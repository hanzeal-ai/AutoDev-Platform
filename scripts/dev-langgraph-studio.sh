#!/usr/bin/env bash
set -euo pipefail

# Starts a LangGraph Agent Server for LangSmith Studio.
# This is separate from scripts/dev-ai-worker.sh and does not serve /generate/*.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export PYTHONPATH="$ROOT_DIR/core/ai-worker${PYTHONPATH:+:$PYTHONPATH}"

if [[ ! -x ".venv/bin/langgraph" ]]; then
  echo "langgraph CLI not found. Install dev dependencies in .venv first."
  echo "Example: cd core/ai-worker && ../../.venv/bin/python -m pip install -e '.[dev]' langgraph-cli[inmem]"
  exit 1
fi

exec .venv/bin/langgraph dev --host 127.0.0.1 --port "${LANGGRAPH_STUDIO_PORT:-2024}"

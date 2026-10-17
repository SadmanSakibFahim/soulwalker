#!/usr/bin/env bash
# Start the API with reload. Expects Postgres + venv already set up.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/backend"

exec ./.venv/bin/uvicorn soulwalker.main:app --reload --app-dir src --host 0.0.0.0 --port 8000

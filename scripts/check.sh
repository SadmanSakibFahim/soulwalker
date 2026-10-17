#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT/backend"
./.venv/bin/ruff check src tests alembic
./.venv/bin/ruff format --check src tests alembic
./.venv/bin/mypy
./.venv/bin/python -m soulwalker lint-content
./.venv/bin/pytest

if command -v flutter >/dev/null 2>&1; then
  cd "$ROOT/apps/mobile"
  flutter analyze
  flutter test
else
  echo "flutter not on PATH; skipped mobile checks" >&2
fi

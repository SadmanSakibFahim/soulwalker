#!/usr/bin/env bash
# Launch the mobile app with playtest hacks enabled.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/apps/mobile"

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

API_BASE="${API_BASE:-http://127.0.0.1:8000}"

exec flutter run \
  --dart-define=SOULWALKER_DEV=true \
  --dart-define=API_BASE="$API_BASE" \
  "$@"

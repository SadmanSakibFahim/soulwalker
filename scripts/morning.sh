#!/usr/bin/env bash
# Morning load-up: Postgres, migration, seed, API. Prints the phone command.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! docker info >/dev/null 2>&1; then
  echo "Docker isn't running. Opening Docker Desktop."
  open -a Docker || true
  echo "Wait until Docker says it is running, then run ./scripts/morning.sh again."
  exit 1
fi

docker compose up -d

echo "Waiting for Postgres..."
ready=0
for _ in $(seq 1 40); do
  if docker compose exec -T db pg_isready -U soulwalker -d soulwalker >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [[ "$ready" -ne 1 ]]; then
  echo "Postgres did not become ready. Check: docker compose ps"
  exit 1
fi

cd "$ROOT/backend"
.venv/bin/alembic upgrade head
.venv/bin/python -m soulwalker seed
cd "$ROOT"

LOG="${TMPDIR:-/tmp}/soulwalker-api.log"
if curl -sf http://127.0.0.1:8000/health >/dev/null; then
  echo "API is already on http://127.0.0.1:8000"
else
  nohup "$ROOT/scripts/run-api.sh" >"$LOG" 2>&1 &
  echo $! >"${TMPDIR:-/tmp}/soulwalker-api.pid"
  echo "Starting the API. Log: $LOG"
  up=0
  for _ in $(seq 1 30); do
    if curl -sf http://127.0.0.1:8000/health >/dev/null; then
      up=1
      break
    fi
    sleep 1
  done
  if [[ "$up" -ne 1 ]]; then
    echo "The API did not start. Last log lines:"
    tail -n 40 "$LOG" || true
    exit 1
  fi
fi

echo "Health: $(curl -sf http://127.0.0.1:8000/health)"
echo "Dev: $(curl -sf http://127.0.0.1:8000/v1/dev/status || true)"

IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
if [[ -z "$IP" ]]; then
  IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi

echo ""
echo "Phone and Mac on the same Wi-Fi. Plug in the iPhone, unlock it, and trust this Mac."
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  echo ""
  echo "Xcode needs its license accepted once before the phone build:"
  echo "  sudo /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -license accept"
fi
echo ""
if [[ -n "$IP" ]]; then
  echo "Then, from anywhere:"
  echo "  API_BASE=http://${IP}:8000 $ROOT/scripts/run-mobile-dev.sh --release"
else
  echo "No Wi-Fi address found. Run: ipconfig getifaddr en0"
  echo "  API_BASE=http://THAT_ADDRESS:8000 $ROOT/scripts/run-mobile-dev.sh --release"
fi
echo ""
echo "In the app: Connect API. Allow Steps and Walking + Running Distance."
echo "Sync Apple Health banks today's Fitness steps, including steps from before you opened Soulwalker."
echo "If the sheet does not list them: Health app → Sharing → Apps → Soulwalker."

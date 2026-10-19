#!/usr/bin/env bash
# Walk the live API with a fresh sample walker. Leaves devwalker alone.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API="${API_BASE:-http://127.0.0.1:8000}"
NAME="demo$(date +%Y%m%d%H%M%S)"
PASSWORD="demopass8"
LAST="$(mktemp)"
trap 'rm -f "$LAST"' EXIT

step() {
  echo
  echo "── $1"
  echo "$2"
}

show() {
  python3 - "$1" "$LAST" <<'PY'
import json
import sys

kind, path = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)

def km(meters: int) -> str:
    return f"{meters / 1000:.1f} km"

def progress(body: dict) -> None:
    tiers = body["unlocked_armament_tiers"] or ["none"]
    events = ", ".join(body["events"]) or "none"
    open_day = body["progress_date"] if body["progress_date"] else "not open"
    print(f"  walked {km(body['total_distance_m'])}    today {km(body['today_distance_m'])}    open day {open_day}")
    print(
        f"  streak {body['current_encounter_streak_days']} of {body['encounter_length_days']}"
        f"    attempt {body['encounter_attempt']}"
        f"    finished encounters {body['encounters_completed']}"
    )
    print(f"  armament tiers: {', '.join(str(tier) for tier in tiers)}")
    print(f"  events: {events}")

if kind == "health":
    print(f"  status: {data['status']}")
elif kind == "dev":
    print(f"  dev_mode: {str(data['dev_mode']).lower()}")
elif kind == "worlds":
    for world in data:
        pillars = ", ".join(world["pillars"])
        print(f"  {world['name']} ({world['world_key']})")
        print(f"  tone: {world['tone']}")
        print(f"  pillars: {pillars}")
        print(f"  active: {str(world['active']).lower()}")
elif kind == "token":
    print(f"  player_id: {data['player_id']}")
elif kind == "me":
    print(f"  {data['display_name']}  id {data['id']}  world {data['active_world_id']}")
    print(f"  walked {km(data['total_distance_m'])}    streak {data['current_encounter_streak_days']}    affliction {data['affliction_status']}")
elif kind == "terms":
    labels = {
        "CHECKPOINT_NAME": "checkpoint screen",
        "STANDINGS_NAME": "standings screen",
        "SUMMONS_NAME": "summons screen",
        "DEATH_MARKER_NAME": "death-marker screen",
    }
    terms = data["terms"]
    print(f"  world: {data['world_key']}")
    for key in ("CHECKPOINT_NAME", "STANDINGS_NAME", "SUMMONS_NAME", "DEATH_MARKER_NAME"):
        print(f"  {labels[key]}: {terms[key]}")
    print("  other labels:")
    for key in sorted(term for term in terms if term not in labels):
        print(f"    {key}: {terms[key]}")
elif kind == "progress":
    progress(data)
elif kind == "lore":
    value = data["trigger_value"]
    shown = "none" if value is None else str(value)
    print(f"  {data['fragment_key']}  ({data['trigger_type']} / {shown})")
    print(f"  {data['text']}")
else:
    raise SystemExit(f"unknown show kind: {kind}")
PY
}

request() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local args=(-sS -o "$LAST" -w "%{http_code}" -X "$method" "${API}${path}" -H "Accept: application/json")
  if [[ -n "${TOKEN:-}" ]]; then
    args+=(-H "Authorization: Bearer ${TOKEN}")
  fi
  if [[ -n "$body" ]]; then
    args+=(-H "Content-Type: application/json" --data "$body")
  fi
  local code
  code="$(curl "${args[@]}")"
  if [[ "$code" -lt 200 || "$code" -ge 300 ]]; then
    echo "Request failed: ${method} ${path} → HTTP ${code}" >&2
    cat "$LAST" >&2
    echo >&2
    exit 1
  fi
}

field() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "$LAST" "$1"
}

echo "Soulwalker local demo"
echo "Bringing up Postgres, the world pack, and the API."
"$ROOT/scripts/morning.sh"

step "1. API is up" "Health and the playtest flag."
request GET /health
show health
request GET /v1/dev/status
show dev

step "2. World pack" "Content seeded into Postgres. The engine only stores keys; these are the labels."
request GET /v1/worlds
show worlds

step "3. Register a sample walker" "New player ${NAME}. devwalker is not touched."
request POST /v1/auth/register "{\"display_name\":\"${NAME}\",\"password\":\"${PASSWORD}\"}"
show token
PLAYER_ID="$(field player_id)"

step "4. Log in" "Same name and password, a new token."
request POST /v1/auth/login "{\"display_name\":\"${NAME}\",\"password\":\"${PASSWORD}\"}"
TOKEN="$(field access_token)"
show token

step "5. Who you are" "GET /v1/auth/me"
request GET /v1/auth/me
show me

step "6. Screen names" "Resolved from the active world. These are the four tabs."
request GET /v1/worlds/current/terminology
show terms

step "7. Empty progress" "No distance yet. The open day starts on the first walk."
request GET /v1/progress
show progress

step "8. Walk 3 km" "Tier 1 unlocks at 3 km. The day counts at 5 km, so this day has not counted."
request POST /v1/progress/distance '{"meters":3000}'
show progress

step "9. Lore for 3 km and the first armament" "milestone_km / 3, then armament_unlock / 1."
request POST /v1/lore/deliver '{"trigger_type":"milestone_km","trigger_value":3}'
show lore
request POST /v1/lore/deliver '{"trigger_type":"armament_unlock","trigger_value":1}'
show lore

step "10. Walk 2 km more" "Today reaches 5 km, so the day counts. Tier 2 unlocks. Nothing past tier 2."
request POST /v1/progress/distance '{"meters":2000}'
show progress

step "11. Lore for 5 km and the second armament" "milestone_km / 5, then armament_unlock / 2."
request POST /v1/lore/deliver '{"trigger_type":"milestone_km","trigger_value":5}'
show lore
request POST /v1/lore/deliver '{"trigger_type":"armament_unlock","trigger_value":2}'
show lore

step "12. Close the counted day" "The streak stays. Today goes back to 0. Lifetime distance stays."
request POST /v1/progress/close-day
show progress

step "13. Close the next day with no walk" "A missed day while a streak is active resets that attempt only."
request POST /v1/progress/close-day
show progress
PROGRESS_DATE="$(field progress_date)"

step "14. Lore for the failed attempt" "boss_death / 1. The marker itself is not saved."
request POST /v1/lore/deliver '{"trigger_type":"boss_death","trigger_value":1}'
show lore

step "15. Five counted days from Apple Health dates" "POST /v1/progress/activity. Each date is that day's cumulative meters. A later date closes the days before it."
ACTIVITY="$(python3 -c '
from datetime import date, timedelta
import json, sys
start = date.fromisoformat(sys.argv[1])
days = [{"date": (start + timedelta(days=i)).isoformat(), "distance_m": 5000} for i in range(5)]
print(json.dumps({"days": days}))
' "$PROGRESS_DATE")"
echo "  dates start at ${PROGRESS_DATE}, 5 km each"
request POST /v1/progress/activity "$ACTIVITY"
show progress

step "16. Lore for the finished encounter" "boss_kill / 1, checkpoint_return / 1, a daily line, and affliction status 0."
request POST /v1/lore/deliver '{"trigger_type":"boss_kill","trigger_value":1}'
show lore
request POST /v1/lore/deliver '{"trigger_type":"checkpoint_return","trigger_value":1}'
show lore
request POST /v1/lore/deliver '{"trigger_type":"daily_ambient"}'
show lore
request POST /v1/lore/deliver '{"trigger_type":"affliction_status","trigger_value":0}'
show lore

step "17. Final progress" "The encounter is finished. The failed attempt is still attempt 2. Both armament tiers remain."
request GET /v1/progress
show progress

python3 - "$LAST" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    body = json.load(handle)

problems: list[str] = []
if body["encounters_completed"] != 1:
    problems.append(f"finished encounters is {body['encounters_completed']}, expected 1")
if body["encounter_attempt"] != 2:
    problems.append(f"attempt is {body['encounter_attempt']}, expected 2")
if body["unlocked_armament_tiers"] != [1, 2]:
    problems.append(f"armament tiers are {body['unlocked_armament_tiers']}, expected [1, 2]")
if body["total_distance_m"] != 30_000:
    problems.append(f"walked {body['total_distance_m']} m, expected 30000")
if problems:
    print("Demo check failed:", file=sys.stderr)
    for problem in problems:
        print(f"  {problem}", file=sys.stderr)
    raise SystemExit(1)
print("  check: finished 1, attempt 2, tiers 1 and 2, walked 30.0 km")
PY

step "Not in this build" "These screens and paths exist as names only."
cat <<'EOF'
  the Quiet Census — no live standings
  a Shared Vigil — no nearby players
  a Failed Waking — the failed attempt resets the streak, and the marker is not saved
  Health Connect — Android still uses the motion step counter
  The phone Health sheet — this script only posts the server side of that sync
EOF

echo
echo "Sample walker ${NAME} (id ${PLAYER_ID}) is in Postgres. Run this again for a new one."
echo "API: ${API}/docs"

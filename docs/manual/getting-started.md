# Getting started — run Soulwalker locally

Soulwalker is a **mobile walking app** with a dark-fantasy skin. Real kilometres unlock armaments and boss encounters. This repo is a Flutter client plus a FastAPI + PostgreSQL backend. V1 is still a foundation: you can open the four main screens, resolve world terminology, and (with playtest hacks) fake walks, lore, and death markers.

Product spec: [`docs/specs/v1.md`](../specs/v1.md).

---

## What you should see

After startup you get a dark, serif UI with four tabs. Labels come from the world pack *The Endless Paralysis*, not from hardcoded mythos names:

| Tab | What it is |
|---|---|
| a Held Breath | Checkpoint — banked walk progress |
| the Quiet Census | Standings / leaderboard (empty until you log distance) |
| a Shared Vigil | Nearby partners (not wired yet) |
| a Failed Waking | Anonymous death markers (fixed type, no free text) |

With **dev mode** on, an amber `DEV` bar and a science FAB appear. Use those to add kilometres and lore on the simulator. On an iPhone, **Sync Apple Health** reads Steps and Walking + Running Distance. See [`guide.md`](../../guide.md).

---

## Prerequisites (once)

Install these on the Mac:

1. **Docker Desktop** — Postgres 16
2. **Python 3.12+** (3.14 is fine)
3. **Flutter** (Homebrew: `brew install --cask flutter`)
4. **Xcode** (iOS Simulator) and/or Android Studio (emulator)

Check:

```bash
docker info
python3 --version
flutter doctor
```

`flutter doctor` should show at least one device (iOS Simulator is enough).

---

## First-time setup

From the repo root (`soulwalker/`):

### 1. Environment

```bash
cp .env.example .env
```

`.env.example` sets `DEV_MODE=true` so playtest API routes are mounted. Never ship with that on.

### 2. Database

```bash
docker compose up -d
```

Postgres is on **localhost:5433** (not 5432) so it will not fight a local Postgres install.

Wait until healthy:

```bash
docker compose ps
```

### 3. Backend venv, schema, world pack

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -e ".[dev]"
.venv/bin/alembic upgrade head
.venv/bin/python -m soulwalker lint-content
.venv/bin/python -m soulwalker seed
cd ..
```

Seed loads `content/worlds/endless_paralysis/` into Postgres.

### 4. Flutter packages

```bash
cd apps/mobile
flutter pub get
cd ../..
```

---

## Daily start (whip the app up)

You need **two terminals**. Order matters: database, then API, then the phone UI.

### Terminal A — API

```bash
docker compose up -d          # skip if already running
./scripts/run-api.sh
```

You should see Uvicorn on **http://127.0.0.1:8000**. Quick check:

```bash
curl -s http://127.0.0.1:8000/health
# {"status":"ok"}

curl -s http://127.0.0.1:8000/v1/dev/status
# {"dev_mode":true}
```

API docs: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs).

### Terminal B — mobile (dev hacks on)

Open a simulator first if needed:

```bash
open -a Simulator
```

Then:

```bash
./scripts/run-mobile-dev.sh
```

If several devices are attached, pick one:

```bash
flutter devices
./scripts/run-mobile-dev.sh -d iPhone
```

That script is:

```bash
flutter run \
  --dart-define=SOULWALKER_DEV=true \
  --dart-define=API_BASE=http://127.0.0.1:8000
```

**Without** `SOULWALKER_DEV=true` you get the same four tabs but no amber bar and no hack panel. That is the “real” app shell.

### Android emulator

The emulator cannot see `127.0.0.1` on your Mac. Use:

```bash
API_BASE=http://10.0.2.2:8000 ./scripts/run-mobile-dev.sh -d emulator-5554
```

### Physical phone

1. Run the API with `--host 0.0.0.0` (already in `scripts/run-api.sh`).
2. Phone and Mac on the same Wi-Fi.
3. Pass your Mac’s LAN IP. `--release` lets you unplug and pocket the phone:

```bash
API_BASE=http://192.168.1.20:8000 ./scripts/run-mobile-dev.sh --release
```

On **a Held Breath**, **Connect API**, then allow **Steps** and **Walking + Running Distance**. That banks today's Apple Health distance, including steps taken before the app was opened. **Start walk** is the motion-coprocessor fallback. See [`guide.md`](../../guide.md).

---

## Playtest hacks (dev mode)

All hacks live in two folders so they are easy to rip out:

- Flutter: `apps/mobile/lib/dev/`
- API: `backend/src/soulwalker/dev/`

They are **off** unless you opt in (`SOULWALKER_DEV=true` on the client, `DEV_MODE=true` on the API).

The panel works **offline**. Connect API is optional; if Uvicorn is down, +km / Close day / lore / death markers still update the UI from local state. The open day is UTC until a device-local date exists.

| Control | What it does |
|---|---|
| Connect API | Creates playtest user `devwalker` / `devdevdev8` and stores a JWT |
| +1 / +3 / +5 km | Adds distance for the open day. 5 km counts the day. 3 km and 5 km unlock armaments. Syncs if connected |
| Close day | Ends the open day. A counted day keeps the streak. A missed day, while a streak is active, resets that attempt only |
| Pull lore | Fetches a fragment from the API, or cycles bundled sample lines |
| Drop death marker | Adds a fixed-type marker (`Died here, attempt #N`) on a Failed Waking |
| Reset local | Clears in-memory walk / markers / lore (does not wipe the DB) |

Open **a Held Breath** after +km to see `Walked X.X km`. Open **a Failed Waking** after dropping a marker.

### API playtest routes (only if `DEV_MODE=true`)

| Method | Path | Auth |
|---|---|---|
| GET | `/v1/dev/status` | none |
| POST | `/v1/dev/bootstrap` | none — upserts `devwalker` |
| POST | `/v1/dev/grant-distance` | Bearer `{ "meters": 3000 }` — same rules as `/v1/progress/distance` |
| POST | `/v1/dev/close-day` | Bearer — same rules as `/v1/progress/close-day` |
| POST | `/v1/dev/deliver-lore` | Bearer `{ "trigger_type": "daily_ambient" }` |
| POST | `/v1/dev/reset-lore` | Bearer — clears seen fragments |

These must not exist in production.

---

## How to remove the hacks

When you are done playing:

1. Delete `apps/mobile/lib/dev/`
2. Delete `backend/src/soulwalker/dev/`
3. In [`apps/mobile/lib/app.dart`](../../apps/mobile/lib/app.dart) drop the `dev/` imports, `kSoulwalkerDev` branch, and set `debugShowCheckedModeBanner: false`
4. In [`backend/src/soulwalker/main.py`](../../backend/src/soulwalker/main.py) drop the `if get_settings().dev_mode:` block
5. In [`backend/src/soulwalker/config.py`](../../backend/src/soulwalker/config.py) drop `dev_mode`
6. Set `DEV_MODE=false` in `.env` (or delete the line)
7. Run `scripts/check.sh`

Walk progress UI on the four screens can stay; that is real product surface, not a hack.

---

## Quality checks

```bash
./scripts/check.sh
```

Runs Ruff, MyPy, content lint, pytest, `flutter analyze`, and `flutter test`.

---

## If something fails

| Symptom | Fix |
|---|---|
| `docker compose` cannot connect | Start Docker Desktop, then retry |
| Alembic / seed cannot connect | Confirm port **5433** and `.env` `DATABASE_URL` |
| `curl /v1/dev/status` 404 | `DEV_MODE=true` in `.env`, restart Uvicorn (`get_settings` is cached at process start) |
| Flutter: no devices | `open -a Simulator` then `flutter devices` |
| Android: Connect API fails | Use `API_BASE=http://10.0.2.2:8000` |
| Amber bar missing | You launched `flutter run` without `--dart-define=SOULWALKER_DEV=true` — use `scripts/run-mobile-dev.sh` |
| `content ok` fails | YAML fragment `text:` values that contain `:` must be quoted |

---

## What is not here yet

Health Connect, live leaderboards, geo matching, Rive, and post-processing shaders are later slices. iOS reads Apple Health (steps and walking distance) and banks it through the encounter rules. Android still uses the motion step counter. Dev hacks can still add kilometres by hand.

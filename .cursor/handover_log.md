# Handover Log

Last updated: 2026-10-19

## Current state

V1 foundation, playable encounter loop, and **Apple Health sync**. Flutter + FastAPI + PostgreSQL. World pack: *The Endless Paralysis*.

**Done**
- Cursor rules, spec at `docs/specs/v1.md`, serial PK schema through `0002_encounter_loop`
- Lore delivery, JWT auth, Flutter four-tab shell with terminology keys
- Operator manual: `docs/manual/getting-started.md`. Morning path: `guide.md` and `scripts/morning.sh`
- Removable playtest hacks: `apps/mobile/lib/dev/` (dart-define `SOULWALKER_DEV`) and `backend/src/soulwalker/dev/` (`DEV_MODE=true`)
- Encounter loop: 5 km on the open day counts that day; 5 counted days finish the encounter; a day that did not count, while a streak is active, resets that attempt only. Lifetime distance, armament tiers, and finished encounters stay.
- Armaments: tier 1 at 3 km, tier 2 at 5 km. No further tiers.
- One calendar day cannot finish the encounter. Extra distance on a day that already counted does not count again.
- Checkpoint screen shows the open day, streak, attempt, finished encounters, and owned armament categories via terminology keys.
- Rest-point rows in `player_checkpoints` (origin, armament, encounter completed, return). The UI reads live stats; death does not roll distance backward.
- Dev panel: `+km` and `Close day` apply the rules locally, and sync to the API when connected. `Close day` is the simulator clock. On an iPhone, leave it alone.
- Apple Health (iOS): **Sync Apple Health** reads Steps and Walking + Running Distance for the device-local day and posts cumulative meters to `POST /v1/progress/activity`. A later local date closes the days before it. The first sync counts today only (including steps taken before the app was opened). Later syncs catch up from the open day through today, capped at 31 days. Walking distance wins; otherwise 0.78 m/step. Channel `soulwalker/health`. Entitlement: `apps/mobile/ios/Runner/Runner.entitlements`.
- Local walkthrough: `scripts/demo.sh` starts the stack and walks those routes with a new `demo…` player. It does not change `devwalker`.
- Browser UI: `apps/mobile/web/` so the same Flutter shell can run in Chrome while the Xcode license is still unaccepted. iOS and Android targets are unchanged.
- Pocket walk remains the fallback (`soulwalker/motion`). iPhone motion-coprocessor distance, Android step estimate. Using it together with Apple Health on the same outing can count those steps twice.
- Local Docker has been migrated to `0002_encounter_loop` and seeded (`w_endless_paralysis`). Postgres was left running.

**Not in this slice**
- Health Connect (Android still uses the motion step counter)
- Persisted anonymous death markers
- Live leaderboards, geo summons
- Rive, shaders, Apple/Google auth
- The iOS binary was not compiled here. `xcode-select` points at the command-line tools. `scripts/run-mobile-dev.sh` sets `DEVELOPER_DIR` to Xcode.app. The Xcode license is not accepted: `xcodebuild -checkFirstLaunchStatus` exits 69. Accept it with the sudo line in `guide.md` before the phone build.

## Canonical files

| Concern | Path |
|---|---|
| Product spec | `docs/specs/v1.md` |
| Tomorrow playtest | `guide.md` |
| Morning script | `scripts/morning.sh` |
| Local walkthrough | `scripts/demo.sh` |
| Browser UI | `apps/mobile/web/` |
| Runbook | `docs/manual/getting-started.md` |
| Rules | `.cursor/rules/*.mdc` |
| API entry | `backend/src/soulwalker/main.py` |
| Progress API | `backend/src/soulwalker/api/v1/progress.py` |
| Encounter rules | `backend/src/soulwalker/domain/encounter.py` |
| Progress service | `backend/src/soulwalker/services/progress.py` |
| Dev API (delete to remove) | `backend/src/soulwalker/dev/router.py` |
| Domain lore | `backend/src/soulwalker/domain/lore.py` |
| Terminology keys | `backend/src/soulwalker/domain/terminology.py` |
| Models | `backend/src/soulwalker/models/` |
| Migrations | `backend/alembic/versions/0001_initial.py`, `0002_encounter_loop.py` |
| World pack | `content/worlds/endless_paralysis/` |
| Flutter resolver | `apps/mobile/lib/domain/terminology_resolver.dart` |
| Flutter encounter rules | `apps/mobile/lib/domain/encounter_loop.dart` |
| Apple Health rules | `apps/mobile/lib/domain/activity_sync.dart` |
| Flutter shell | `apps/mobile/lib/presentation/app_shell.dart` |
| Health sync | `apps/mobile/lib/presentation/health_controller.dart`, `apps/mobile/lib/data/health_source.dart` |
| Pocket walk | `apps/mobile/lib/presentation/walk_controller.dart`, `apps/mobile/lib/domain/walk_credit.dart` |
| iOS Health + motion | `apps/mobile/ios/Runner/AppDelegate.swift` |
| Checkpoint screen | `apps/mobile/lib/presentation/screens/v1_screens.dart` |
| Dev host (delete to remove) | `apps/mobile/lib/dev/dev_host.dart` |
| Quality script | `scripts/check.sh` |
| Run API / mobile | `scripts/run-api.sh`, `scripts/run-mobile-dev.sh` |

Do not re-scan the tree for structure. Start from this table.

## Schema / latest migration

Revision: **`0002_encounter_loop`**. Adds `player_stats` day/attempt columns, `player_armaments`, `player_checkpoints`. No new revision for Health sync; it writes the existing day columns.

Local Docker Postgres is on this revision. `./scripts/morning.sh` upgrades again, which is a no-op if already current.

## How to run

Tomorrow: [`guide.md`](../guide.md).

```bash
./scripts/morning.sh
# then the phone command it prints, after the Xcode license line if it prints one
```

See the current API with a fresh sample walker (world pack, auth, armaments, a failed attempt, activity sync, lore):

```bash
./scripts/demo.sh
```

See the four screens in a browser (the iOS simulator still needs the Xcode license):

```bash
cd apps/mobile
flutter run -d chrome --web-port 8090 \
  --dart-define=SOULWALKER_DEV=true \
  --dart-define=API_BASE=http://127.0.0.1:8000
```

`flutter` calls `xcodebuild` on startup. Until the license is accepted, that command exits before Chrome opens.

Simulator: `./scripts/morning.sh` then `./scripts/run-mobile-dev.sh`. `+km` and **Close day** play the loop. **Sync Apple Health** reports that Health is not on the simulator.

Quality: `scripts/check.sh` (needs Postgres for the integration tests). Flutter checks do not need the Xcode license. The phone build does.

## Tests

- `backend/tests/` — 38 passed (32 unit, 6 integration) with local Postgres up
- `apps/mobile/test/` — 25 (resolver, encounter loop, activity sync, checkpoint, pocket walk, dev panel)

## Next actions (ordered)

1. Accept the Xcode license and run the phone command from `guide.md`. In the Health sheet, allow Steps and Walking + Running Distance. If signing rejects the HealthKit entitlement, add the HealthKit capability on the Runner target once.
2. Health Connect on Android, same `POST /v1/progress/activity` contract
3. Persist anonymous death markers (fixed type, attempt number, no free text)
4. Leaderboards reading world-agnostic stats
5. Nearby summons (privacy/radius still open in spec §9)

## Decided (do not re-open)

- Backend is custom FastAPI + PostgreSQL, not Firebase/Supabase
- Integer serial PKs, never UUID PKs
- Mythos strings only via terminology keys
- Tests only in `backend/tests/` and `apps/mobile/test/`
- Playtest hacks stay in `dev/` folders, gated by flags, documented for deletion
- Encounter: 5 km on one open day counts once; 5 counted days finish it; a missed day resets that attempt only
- Armaments: tier 1 at 3 km, tier 2 at 5 km, and nothing after that
- Death markers and standings were left out of this slice on purpose
- Apple Health is the iOS clock. Cumulative meters per local date. The first sync is today only. Manual **Close day** stays for the simulator.
- On a phone day, do not also tap **Close day**. That moves the open day forward and that calendar day will not take more distance.

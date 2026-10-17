# Handover Log

Last updated: 2026-08-24

## Current state

V1 foundation plus **local playtest tooling**. Flutter + FastAPI + PostgreSQL. World pack: *The Endless Paralysis*.

**Done**
- Cursor rules, spec at `docs/specs/v1.md`, serial PK schema `0001_initial`
- Lore delivery, JWT auth, Flutter four-tab shell with terminology keys
- Operator manual: `docs/manual/getting-started.md`
- Removable playtest hacks: `apps/mobile/lib/dev/` (dart-define `SOULWALKER_DEV`) and `backend/src/soulwalker/dev/` (`DEV_MODE=true`)
- Screens show walk km / streak / fixed-type death markers when fed `WalkProgress`

**Not in this slice**
- HealthKit / Health Connect
- Checkpoint/streak/armament rules beyond stubs
- Live leaderboards, geo summons, persisted death markers
- Rive, shaders, Apple/Google auth

## Canonical files

| Concern | Path |
|---|---|
| Product spec | `docs/specs/v1.md` |
| Runbook | `docs/manual/getting-started.md` |
| Rules | `.cursor/rules/*.mdc` |
| API entry | `backend/src/soulwalker/main.py` |
| Dev API (delete to remove) | `backend/src/soulwalker/dev/router.py` |
| Domain lore | `backend/src/soulwalker/domain/lore.py` |
| Terminology keys | `backend/src/soulwalker/domain/terminology.py` |
| Models | `backend/src/soulwalker/models/` |
| Migration | `backend/alembic/versions/0001_initial.py` |
| World pack | `content/worlds/endless_paralysis/` |
| Flutter resolver | `apps/mobile/lib/domain/terminology_resolver.dart` |
| Flutter shell | `apps/mobile/lib/presentation/app_shell.dart` |
| Dev host (delete to remove) | `apps/mobile/lib/dev/dev_host.dart` |
| Quality script | `scripts/check.sh` |
| Run API / mobile | `scripts/run-api.sh`, `scripts/run-mobile-dev.sh` |

Do not re-scan the tree for structure. Start from this table.

## Schema / latest migration

Revision: **`0001_initial`** (unchanged this session).

## How to run

See `docs/manual/getting-started.md`. Short form:

```bash
cp .env.example .env          # includes DEV_MODE=true
docker compose up -d
cd backend && .venv/bin/alembic upgrade head && .venv/bin/python -m soulwalker seed
./scripts/run-api.sh                    # terminal A
./scripts/run-mobile-dev.sh             # terminal B — SOULWALKER_DEV=true
```

Quality: `scripts/check.sh`

## Tests

- `backend/tests/` — 16 (unit + integration, including `/v1/dev` bootstrap)
- `apps/mobile/test/` — 5 (resolver, checkpoint, dev panel km, death marker)

## Next actions (ordered)

1. Health data sync (HealthKit / Health Connect) → write `player_stats.total_distance_m`
2. Checkpoint + encounter streak domain (5 km/day × 5 days; death resets that encounter only)
3. Persist anonymous death markers (fixed type, no free text)
4. Leaderboards reading world-agnostic stats
5. Nearby summons (privacy/radius still open in spec §9)

## Decided (do not re-open)

- Backend is custom FastAPI + PostgreSQL, not Firebase/Supabase
- Integer serial PKs, never UUID PKs
- Mythos strings only via terminology keys
- Tests only in `backend/tests/` and `apps/mobile/test/`
- Playtest hacks stay in `dev/` folders, gated by flags, documented for deletion

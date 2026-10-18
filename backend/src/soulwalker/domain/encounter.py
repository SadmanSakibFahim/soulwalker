"""World-agnostic encounter loop. Numbers and tier ids only — no fictional names.

A calendar day counts when distance credited to that day reaches 5 km.
Five counted days in a row finish the encounter. Closing a day that did not
count, while a streak is active, is death: the streak returns to 0 and the
attempt increments. Lifetime distance, owned tiers, and finished encounters stay.

The open day is `progress_date`. `close_day` advances it by one day. Activity
sync (`apply_activity_days`) is the device-local clock: each entry is one
calendar day's cumulative meters, and a later date closes the days before it.
"""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass, replace
from datetime import date, timedelta
from enum import StrEnum

MAX_DAY_DISTANCE_M = 200_000

DAILY_QUALIFY_M = 5_000
ENCOUNTER_LENGTH_DAYS = 5
ARMAMENT_UNLOCKS_M: tuple[tuple[int, int], ...] = ((1, 3_000), (2, 5_000))


class EncounterEventKind(StrEnum):
    DISTANCE_RECORDED = "distance_recorded"
    ARMAMENT_UNLOCKED = "armament_unlocked"
    DAY_QUALIFIED = "day_qualified"
    ENCOUNTER_COMPLETED = "encounter_completed"
    DEATH = "death"
    DAY_CLOSED = "day_closed"


@dataclass(frozen=True, slots=True)
class EncounterEvent:
    kind: EncounterEventKind
    tier: int | None = None


@dataclass(frozen=True, slots=True)
class DayActivity:
    """Cumulative meters Health already recorded for one local calendar day."""

    on_date: date
    distance_m: int


@dataclass(frozen=True, slots=True)
class EncounterState:
    total_distance_m: int
    today_distance_m: int
    progress_date: date | None
    last_qualified_date: date | None
    streak_days: int
    attempt: int
    encounters_completed: int
    unlocked_tiers: tuple[int, ...]


def new_state(on_date: date) -> EncounterState:
    return EncounterState(
        total_distance_m=0,
        today_distance_m=0,
        progress_date=on_date,
        last_qualified_date=None,
        streak_days=0,
        attempt=1,
        encounters_completed=0,
        unlocked_tiers=(),
    )


def ensure_open(state: EncounterState, on_date: date) -> EncounterState:
    if state.progress_date is not None:
        return state
    return replace(state, progress_date=on_date)


def unlock_for_distance(
    state: EncounterState,
) -> tuple[EncounterState, tuple[EncounterEvent, ...]]:
    owned = set(state.unlocked_tiers)
    events: list[EncounterEvent] = []
    for tier, threshold_m in ARMAMENT_UNLOCKS_M:
        if state.total_distance_m >= threshold_m and tier not in owned:
            owned.add(tier)
            events.append(EncounterEvent(EncounterEventKind.ARMAMENT_UNLOCKED, tier=tier))
    if not events:
        return state, ()
    return replace(state, unlocked_tiers=tuple(sorted(owned))), tuple(events)


def record_distance(
    state: EncounterState,
    meters: int,
) -> tuple[EncounterState, tuple[EncounterEvent, ...]]:
    if meters <= 0:
        raise ValueError("meters must be positive")
    if state.progress_date is None:
        raise ValueError("progress day is not open")

    total = state.total_distance_m + meters
    today = state.today_distance_m + meters
    events: list[EncounterEvent] = [EncounterEvent(EncounterEventKind.DISTANCE_RECORDED)]
    streak = state.streak_days
    last_qualified = state.last_qualified_date
    completed = state.encounters_completed
    already_qualified = last_qualified == state.progress_date
    if not already_qualified and today >= DAILY_QUALIFY_M:
        streak += 1
        last_qualified = state.progress_date
        events.append(EncounterEvent(EncounterEventKind.DAY_QUALIFIED))
        if streak >= ENCOUNTER_LENGTH_DAYS:
            completed += 1
            streak = 0
            events.append(EncounterEvent(EncounterEventKind.ENCOUNTER_COMPLETED))

    updated = replace(
        state,
        total_distance_m=total,
        today_distance_m=today,
        streak_days=streak,
        last_qualified_date=last_qualified,
        encounters_completed=completed,
    )
    unlocked, unlock_events = unlock_for_distance(updated)
    return unlocked, tuple([*events, *unlock_events])


def apply_activity_days(
    state: EncounterState,
    days: Sequence[DayActivity],
) -> tuple[EncounterState, tuple[EncounterEvent, ...]]:
    """Credit each local day's cumulative distance, closing days that passed.

    A second sync of the same totals adds nothing. A day before the open
    progress date is ignored. Missing dates between entries count as no walk.
    """
    if not days:
        raise ValueError("at least one day is required")

    ordered = tuple(sorted(days, key=lambda day: day.on_date))
    seen: set[date] = set()
    for day in ordered:
        if day.on_date in seen:
            raise ValueError("duplicate activity date")
        seen.add(day.on_date)
        if day.distance_m < 0:
            raise ValueError("distance must be >= 0")
        if day.distance_m > MAX_DAY_DISTANCE_M:
            raise ValueError("distance is too large")

    current = state
    events: list[EncounterEvent] = []
    for day in ordered:
        if current.progress_date is None:
            current = ensure_open(current, day.on_date)
        progress_date = current.progress_date
        if progress_date is None:
            raise RuntimeError("progress day failed to open")
        if day.on_date < progress_date:
            continue
        while current.progress_date is not None and current.progress_date < day.on_date:
            current, closed = close_day(current)
            events.extend(closed)
        today = current.today_distance_m
        delta = day.distance_m - today
        if delta > 0:
            current, recorded = record_distance(current, delta)
            events.extend(recorded)
    return current, tuple(events)


def close_day(state: EncounterState) -> tuple[EncounterState, tuple[EncounterEvent, ...]]:
    if state.progress_date is None:
        raise ValueError("progress day is not open")

    events: list[EncounterEvent] = []
    streak = state.streak_days
    attempt = state.attempt
    qualified = state.last_qualified_date == state.progress_date
    if not qualified and streak > 0:
        streak = 0
        attempt += 1
        events.append(EncounterEvent(EncounterEventKind.DEATH))
    events.append(EncounterEvent(EncounterEventKind.DAY_CLOSED))
    return (
        replace(
            state,
            today_distance_m=0,
            progress_date=state.progress_date + timedelta(days=1),
            streak_days=streak,
            attempt=attempt,
        ),
        tuple(events),
    )

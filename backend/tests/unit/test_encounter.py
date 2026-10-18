from __future__ import annotations

from dataclasses import replace
from datetime import date, timedelta

import pytest

from soulwalker.domain.encounter import (
    DAILY_QUALIFY_M,
    ENCOUNTER_LENGTH_DAYS,
    DayActivity,
    EncounterEvent,
    EncounterEventKind,
    EncounterState,
    apply_activity_days,
    close_day,
    ensure_open,
    new_state,
    record_distance,
    unlock_for_distance,
)

DAY = date(2026, 3, 1)


def _kinds(events: tuple[EncounterEvent, ...]) -> list[EncounterEventKind]:
    return [event.kind for event in events]


def test_three_km_unlocks_only_the_first_tier() -> None:
    state, events = record_distance(new_state(DAY), 3_000)
    assert state.unlocked_tiers == (1,)
    assert state.streak_days == 0
    assert state.total_distance_m == 3_000
    assert EncounterEventKind.DAY_QUALIFIED not in _kinds(events)
    assert EncounterEventKind.ARMAMENT_UNLOCKED in _kinds(events)


def test_five_km_unlocks_both_tiers_and_counts_one_day() -> None:
    state, events = record_distance(new_state(DAY), DAILY_QUALIFY_M)
    assert state.unlocked_tiers == (1, 2)
    assert state.streak_days == 1
    assert state.encounters_completed == 0
    assert EncounterEventKind.DAY_QUALIFIED in _kinds(events)
    assert EncounterEventKind.ENCOUNTER_COMPLETED not in _kinds(events)


def test_distance_past_five_km_does_not_add_a_third_tier() -> None:
    state, _events = record_distance(new_state(DAY), 15_000)
    assert state.unlocked_tiers == (1, 2)
    assert state.streak_days == 1


def test_one_grant_cannot_finish_the_encounter() -> None:
    state, events = record_distance(new_state(DAY), 25_000)
    assert state.streak_days == 1
    assert state.encounters_completed == 0
    assert EncounterEventKind.ENCOUNTER_COMPLETED not in _kinds(events)


def test_same_day_distance_counts_only_once() -> None:
    state, first = record_distance(new_state(DAY), DAILY_QUALIFY_M)
    state, second = record_distance(state, DAILY_QUALIFY_M)
    assert state.streak_days == 1
    assert state.today_distance_m == 10_000
    assert EncounterEventKind.DAY_QUALIFIED in _kinds(first)
    assert EncounterEventKind.DAY_QUALIFIED not in _kinds(second)


def test_crossing_five_km_across_two_grants() -> None:
    state, _first = record_distance(new_state(DAY), 3_000)
    assert state.unlocked_tiers == (1,)
    assert state.streak_days == 0
    state, second = record_distance(state, 2_000)
    assert state.unlocked_tiers == (1, 2)
    assert state.streak_days == 1
    assert EncounterEventKind.DAY_QUALIFIED in _kinds(second)
    unlocked = [
        event.tier for event in second if event.kind == EncounterEventKind.ARMAMENT_UNLOCKED
    ]
    assert unlocked == [2]


def test_five_counted_days_complete_the_encounter() -> None:
    state = new_state(DAY)
    for day in range(ENCOUNTER_LENGTH_DAYS):
        state, events = record_distance(state, DAILY_QUALIFY_M)
        kinds = _kinds(events)
        assert EncounterEventKind.DAY_QUALIFIED in kinds
        if day < ENCOUNTER_LENGTH_DAYS - 1:
            assert state.streak_days == day + 1
            assert EncounterEventKind.ENCOUNTER_COMPLETED not in kinds
            state, closed = close_day(state)
            assert EncounterEventKind.DEATH not in _kinds(closed)
            assert state.streak_days == day + 1
        else:
            assert state.streak_days == 0
            assert state.encounters_completed == 1
            assert EncounterEventKind.ENCOUNTER_COMPLETED in kinds

    state, extra = record_distance(state, 1_000)
    assert state.streak_days == 0
    assert state.encounters_completed == 1
    assert EncounterEventKind.DAY_QUALIFIED not in _kinds(extra)

    state, _closed = close_day(state)
    state, _next = record_distance(state, DAILY_QUALIFY_M)
    assert state.streak_days == 1
    assert state.encounters_completed == 1
    assert state.attempt == 1


def test_missed_day_resets_only_the_attempt() -> None:
    state, _events = record_distance(new_state(DAY), DAILY_QUALIFY_M)
    state, qualified_close = close_day(state)
    assert EncounterEventKind.DEATH not in _kinds(qualified_close)
    assert state.streak_days == 1

    state, death = close_day(state)
    assert EncounterEventKind.DEATH in _kinds(death)
    assert state.streak_days == 0
    assert state.attempt == 2
    assert state.total_distance_m == DAILY_QUALIFY_M
    assert state.unlocked_tiers == (1, 2)
    assert state.encounters_completed == 0
    assert state.today_distance_m == 0


def test_death_after_a_win_keeps_the_finished_encounter() -> None:
    state = new_state(DAY)
    for _day in range(ENCOUNTER_LENGTH_DAYS - 1):
        state, _events = record_distance(state, DAILY_QUALIFY_M)
        state, _closed = close_day(state)
    state, _done = record_distance(state, DAILY_QUALIFY_M)
    assert state.encounters_completed == 1
    state, _closed = close_day(state)
    state, _again = record_distance(state, DAILY_QUALIFY_M)
    state, _quiet = close_day(state)
    state, death = close_day(state)
    assert EncounterEventKind.DEATH in _kinds(death)
    assert state.encounters_completed == 1
    assert state.streak_days == 0
    assert state.attempt == 2
    assert state.unlocked_tiers == (1, 2)
    assert state.total_distance_m == DAILY_QUALIFY_M * (ENCOUNTER_LENGTH_DAYS + 1)


def test_idle_day_is_not_death() -> None:
    state, events = close_day(new_state(DAY))
    assert EncounterEventKind.DEATH not in _kinds(events)
    assert state.attempt == 1
    assert state.streak_days == 0
    assert state.progress_date == DAY + timedelta(days=1)


def test_second_miss_after_death_does_not_die_again() -> None:
    state, _events = record_distance(new_state(DAY), DAILY_QUALIFY_M)
    state, _closed = close_day(state)
    state, first_death = close_day(state)
    assert EncounterEventKind.DEATH in _kinds(first_death)
    state, second = close_day(state)
    assert EncounterEventKind.DEATH not in _kinds(second)
    assert state.attempt == 2


def test_unlock_for_distance_heals_tiers_already_reached() -> None:
    state = replace(new_state(DAY), total_distance_m=5_000, unlocked_tiers=())
    healed, events = unlock_for_distance(state)
    assert healed.unlocked_tiers == (1, 2)
    assert [event.tier for event in events] == [1, 2]
    again, quiet = unlock_for_distance(healed)
    assert again.unlocked_tiers == (1, 2)
    assert quiet == ()


def test_ensure_open_keeps_an_existing_day() -> None:
    state = new_state(DAY)
    opened = ensure_open(state, DAY + timedelta(days=3))
    assert opened.progress_date == DAY


def _unopened() -> EncounterState:
    return replace(new_state(DAY), progress_date=None)


def test_activity_sync_credits_the_cumulative_day_once() -> None:
    state, events = apply_activity_days(_unopened(), (DayActivity(DAY, 2_000),))
    assert state.progress_date == DAY
    assert state.total_distance_m == 2_000
    assert state.today_distance_m == 2_000
    assert EncounterEventKind.DAY_QUALIFIED not in _kinds(events)

    state, again = apply_activity_days(state, (DayActivity(DAY, 2_000),))
    assert state.total_distance_m == 2_000
    assert again == ()

    state, raised = apply_activity_days(state, (DayActivity(DAY, 5_000),))
    assert state.total_distance_m == 5_000
    assert state.streak_days == 1
    assert state.unlocked_tiers == (1, 2)
    assert EncounterEventKind.DAY_QUALIFIED in _kinds(raised)


def test_activity_sync_ignores_a_lower_reread_and_days_already_closed() -> None:
    state, _events = apply_activity_days(_unopened(), (DayActivity(DAY, 4_000),))
    state, quiet = apply_activity_days(state, (DayActivity(DAY, 1_000),))
    assert state.total_distance_m == 4_000
    assert quiet == ()

    state, skipped = apply_activity_days(
        state,
        (DayActivity(DAY - timedelta(days=1), 9_000),),
    )
    assert state.total_distance_m == 4_000
    assert skipped == ()


def test_activity_sync_closes_a_missed_local_day() -> None:
    state, _events = apply_activity_days(_unopened(), (DayActivity(DAY, DAILY_QUALIFY_M),))
    state, events = apply_activity_days(
        state,
        (
            DayActivity(DAY, DAILY_QUALIFY_M),
            DayActivity(DAY + timedelta(days=1), 0),
            DayActivity(DAY + timedelta(days=2), 1_000),
        ),
    )
    assert EncounterEventKind.DEATH in _kinds(events)
    assert state.attempt == 2
    assert state.streak_days == 0
    assert state.total_distance_m == 6_000
    assert state.today_distance_m == 1_000
    assert state.progress_date == DAY + timedelta(days=2)
    assert state.unlocked_tiers == (1, 2)


def test_five_local_days_finish_the_encounter() -> None:
    days = tuple(
        DayActivity(DAY + timedelta(days=offset), DAILY_QUALIFY_M)
        for offset in range(ENCOUNTER_LENGTH_DAYS)
    )
    state, events = apply_activity_days(_unopened(), days)
    assert state.encounters_completed == 1
    assert state.streak_days == 0
    assert state.progress_date == DAY + timedelta(days=4)
    assert state.today_distance_m == DAILY_QUALIFY_M
    assert EncounterEventKind.ENCOUNTER_COMPLETED in _kinds(events)


def test_activity_sync_rejects_empty_and_duplicate_days() -> None:
    with pytest.raises(ValueError, match="at least one"):
        apply_activity_days(_unopened(), ())
    with pytest.raises(ValueError, match="duplicate"):
        apply_activity_days(
            _unopened(),
            (DayActivity(DAY, 1), DayActivity(DAY, 2)),
        )


def test_rejects_non_positive_distance_and_a_closed_clock() -> None:
    closed = new_state(DAY)
    closed = ensure_open(closed, DAY)
    with pytest.raises(ValueError, match="positive"):
        record_distance(closed, 0)
    unopened = replace(new_state(DAY), progress_date=None)
    with pytest.raises(ValueError, match="not open"):
        record_distance(unopened, 1_000)
    with pytest.raises(ValueError, match="not open"):
        close_day(unopened)

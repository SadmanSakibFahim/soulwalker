"""Apply the encounter loop to a player's world-agnostic stats."""

from __future__ import annotations

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import UTC, date, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from soulwalker.domain.encounter import (
    DayActivity,
    EncounterEvent,
    EncounterEventKind,
    EncounterState,
    apply_activity_days,
    close_day,
    ensure_open,
    record_distance,
    unlock_for_distance,
)
from soulwalker.enums import CheckpointReason
from soulwalker.models.player import Player, PlayerArmament, PlayerCheckpoint, PlayerStats


@dataclass(frozen=True, slots=True)
class ProgressView:
    total_distance_m: int
    today_distance_m: int
    progress_date: date | None
    streak_days: int
    attempt: int
    encounters_completed: int
    unlocked_tiers: tuple[int, ...]
    events: tuple[str, ...]


def _utc_today() -> date:
    return datetime.now(UTC).date()


def _view(state: EncounterState, events: Sequence[EncounterEvent]) -> ProgressView:
    return ProgressView(
        total_distance_m=state.total_distance_m,
        today_distance_m=state.today_distance_m,
        progress_date=state.progress_date,
        streak_days=state.streak_days,
        attempt=state.attempt,
        encounters_completed=state.encounters_completed,
        unlocked_tiers=state.unlocked_tiers,
        events=tuple(event.kind.value for event in events),
    )


async def _load(session: AsyncSession, player: Player) -> tuple[EncounterState, bool]:
    stats = player.stats
    if stats is None:
        stats = PlayerStats(player_id=player.id)
        session.add(stats)
        player.stats = stats
        await session.flush()

    tiers = tuple(
        await session.scalars(
            select(PlayerArmament.tier)
            .where(PlayerArmament.player_id == player.id)
            .order_by(PlayerArmament.tier)
        )
    )
    checkpoint_id = await session.scalar(
        select(PlayerCheckpoint.id)
        .where(PlayerCheckpoint.player_id == player.id)
        .order_by(PlayerCheckpoint.id.desc())
        .limit(1)
    )
    state = EncounterState(
        total_distance_m=stats.total_distance_m,
        today_distance_m=stats.today_distance_m,
        progress_date=stats.progress_date,
        last_qualified_date=stats.last_qualified_date,
        streak_days=stats.current_encounter_streak_days,
        attempt=stats.encounter_attempt,
        encounters_completed=stats.encounters_completed,
        unlocked_tiers=tiers,
    )
    return state, checkpoint_id is not None


def _checkpoint_reason(events: Sequence[EncounterEvent], *, had_checkpoint: bool) -> int:
    kinds = {event.kind for event in events}
    if EncounterEventKind.DEATH in kinds:
        return int(CheckpointReason.RETURN)
    if EncounterEventKind.ENCOUNTER_COMPLETED in kinds:
        return int(CheckpointReason.ENCOUNTER_COMPLETED)
    if EncounterEventKind.ARMAMENT_UNLOCKED in kinds:
        return int(CheckpointReason.ARMAMENT)
    if not had_checkpoint:
        return int(CheckpointReason.ORIGIN)
    return int(CheckpointReason.ORIGIN)


def _should_write_checkpoint(events: Sequence[EncounterEvent], *, had_checkpoint: bool) -> bool:
    if not had_checkpoint:
        return True
    kinds = {event.kind for event in events}
    return bool(
        kinds
        & {
            EncounterEventKind.ARMAMENT_UNLOCKED,
            EncounterEventKind.ENCOUNTER_COMPLETED,
            EncounterEventKind.DEATH,
        }
    )


async def _persist(
    session: AsyncSession,
    player: Player,
    before: EncounterState,
    after: EncounterState,
    events: Sequence[EncounterEvent],
    *,
    banked_on: date,
    had_checkpoint: bool,
) -> None:
    stats = player.stats
    if stats is None:
        raise RuntimeError("player stats missing")
    stats.total_distance_m = after.total_distance_m
    stats.today_distance_m = after.today_distance_m
    stats.progress_date = after.progress_date
    stats.last_qualified_date = after.last_qualified_date
    stats.current_encounter_streak_days = after.streak_days
    stats.encounter_attempt = after.attempt
    stats.encounters_completed = after.encounters_completed

    owned = set(before.unlocked_tiers)
    for tier in after.unlocked_tiers:
        if tier not in owned:
            session.add(
                PlayerArmament(
                    player_id=player.id,
                    tier=tier,
                    unlocked_at_distance_m=after.total_distance_m,
                )
            )

    if _should_write_checkpoint(events, had_checkpoint=had_checkpoint):
        session.add(
            PlayerCheckpoint(
                player_id=player.id,
                reason=_checkpoint_reason(events, had_checkpoint=had_checkpoint),
                banked_distance_m=after.total_distance_m,
                encounters_completed=after.encounters_completed,
                banked_on=banked_on,
            )
        )
    await session.commit()


async def read_progress(session: AsyncSession, player: Player) -> ProgressView:
    before, had_checkpoint = await _load(session, player)
    healed, events = unlock_for_distance(before)
    if events:
        await _persist(
            session,
            player,
            before,
            healed,
            events,
            banked_on=before.progress_date or _utc_today(),
            had_checkpoint=had_checkpoint,
        )
    return _view(healed, ())


async def grant_distance(session: AsyncSession, player: Player, meters: int) -> ProgressView:
    before, had_checkpoint = await _load(session, player)
    opened = ensure_open(before, _utc_today())
    healed, heal_events = unlock_for_distance(opened)
    after, events = record_distance(healed, meters)
    combined = (*heal_events, *events)
    banked_on = opened.progress_date
    if banked_on is None:
        raise RuntimeError("progress day failed to open")
    await _persist(
        session,
        player,
        before,
        after,
        combined,
        banked_on=banked_on,
        had_checkpoint=had_checkpoint,
    )
    return _view(after, combined)


async def sync_activity(
    session: AsyncSession,
    player: Player,
    days: Sequence[DayActivity],
) -> ProgressView:
    before, had_checkpoint = await _load(session, player)
    healed, heal_events = unlock_for_distance(before)
    after, events = apply_activity_days(healed, days)
    combined = (*heal_events, *events)
    if after == before and not combined:
        return _view(before, ())
    banked_on = after.progress_date
    if banked_on is None:
        raise RuntimeError("progress day failed to open")
    await _persist(
        session,
        player,
        before,
        after,
        combined,
        banked_on=banked_on,
        had_checkpoint=had_checkpoint,
    )
    return _view(after, combined)


async def close_progress_day(session: AsyncSession, player: Player) -> ProgressView:
    before, had_checkpoint = await _load(session, player)
    opened = ensure_open(before, _utc_today())
    healed, heal_events = unlock_for_distance(opened)
    after, events = close_day(healed)
    combined = (*heal_events, *events)
    banked_on = opened.progress_date
    if banked_on is None:
        raise RuntimeError("progress day failed to open")
    await _persist(
        session,
        player,
        before,
        after,
        combined,
        banked_on=banked_on,
        had_checkpoint=had_checkpoint,
    )
    return _view(after, combined)

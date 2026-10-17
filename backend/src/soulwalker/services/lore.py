from __future__ import annotations

import random
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from soulwalker.domain.lore import LoreCandidate, filter_candidates, pick_fragment
from soulwalker.enums import TriggerType
from soulwalker.models.lore import LoreFragment
from soulwalker.models.player import Player, PlayerSeenFragment, PlayerWorldProgress


class LoreDeliveryError(Exception):
    pass


async def deliver_lore(
    session: AsyncSession,
    player: Player,
    trigger_type: TriggerType,
    trigger_value: int | None,
    rng: random.Random | None = None,
) -> LoreFragment:
    if player.active_world_id is None:
        raise LoreDeliveryError("player has no active world")

    progress = await session.scalar(
        select(PlayerWorldProgress)
        .options(selectinload(PlayerWorldProgress.seen_fragments))
        .where(
            PlayerWorldProgress.player_id == player.id,
            PlayerWorldProgress.world_id == player.active_world_id,
        )
    )
    if progress is None:
        raise LoreDeliveryError("player has no progress for the active world")

    fragments = (
        await session.scalars(
            select(LoreFragment).where(LoreFragment.world_id == player.active_world_id)
        )
    ).all()

    last_seen = {row.fragment_id: row.seen_at for row in progress.seen_fragments}
    candidates = [
        LoreCandidate(
            fragment_id=fragment.id,
            fragment_key=fragment.fragment_key,
            rarity_weight=fragment.rarity_weight,
            last_seen_at=last_seen.get(fragment.id),
            text=fragment.text,
            trigger_type=fragment.trigger_type,
            trigger_value=fragment.trigger_value,
        )
        for fragment in fragments
    ]
    pool = filter_candidates(candidates, trigger_type, trigger_value)
    chosen = pick_fragment(pool, set(last_seen), rng or random.Random())
    if chosen is None:
        raise LoreDeliveryError("no fragments available for trigger")

    existing = next(
        (row for row in progress.seen_fragments if row.fragment_id == chosen.fragment_id),
        None,
    )
    if existing is None:
        session.add(
            PlayerSeenFragment(
                progress_id=progress.id,
                fragment_id=chosen.fragment_id,
            )
        )
    else:
        existing.seen_at = datetime.now(UTC)

    await session.commit()
    fragment = next(item for item in fragments if item.id == chosen.fragment_id)
    return fragment

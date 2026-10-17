"""World-agnostic lore delivery. Operates on ids and keys only — no fictional names."""

from __future__ import annotations

import random
from collections.abc import Sequence, Set
from dataclasses import dataclass
from datetime import UTC, datetime

from soulwalker.enums import TriggerType

_FAR_PAST = datetime.min.replace(tzinfo=UTC)


@dataclass(frozen=True, slots=True)
class LoreCandidate:
    fragment_id: int
    fragment_key: str
    rarity_weight: int
    last_seen_at: datetime | None
    text: str
    trigger_type: TriggerType
    trigger_value: int | None


def filter_candidates(
    candidates: Sequence[LoreCandidate],
    trigger_type: TriggerType,
    trigger_value: int | None,
) -> list[LoreCandidate]:
    return [
        candidate
        for candidate in candidates
        if candidate.trigger_type == trigger_type and candidate.trigger_value == trigger_value
    ]


def pick_fragment(
    candidates: Sequence[LoreCandidate],
    seen_ids: Set[int],
    rng: random.Random,
) -> LoreCandidate | None:
    """Weighted-random unseen fragment; least-recently-seen once exhausted."""
    if not candidates:
        return None

    unseen = [candidate for candidate in candidates if candidate.fragment_id not in seen_ids]
    if unseen:
        weights = [max(int(candidate.rarity_weight), 1) for candidate in unseen]
        return rng.choices(unseen, weights=weights, k=1)[0]

    def recency_key(candidate: LoreCandidate) -> tuple[datetime, int, int]:
        seen_at = candidate.last_seen_at or _FAR_PAST
        if seen_at.tzinfo is None:
            seen_at = seen_at.replace(tzinfo=UTC)
        return (seen_at, -int(candidate.rarity_weight), candidate.fragment_id)

    return min(candidates, key=recency_key)

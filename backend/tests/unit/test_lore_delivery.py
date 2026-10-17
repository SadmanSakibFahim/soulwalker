from __future__ import annotations

import random
from datetime import UTC, datetime, timedelta

from soulwalker.domain.lore import LoreCandidate, filter_candidates, pick_fragment
from soulwalker.enums import TriggerType


def _candidate(
    fragment_id: int,
    *,
    weight: int = 1,
    seen: datetime | None = None,
    trigger: TriggerType = TriggerType.DAILY_AMBIENT,
    value: int | None = None,
) -> LoreCandidate:
    return LoreCandidate(
        fragment_id=fragment_id,
        fragment_key=f"f_{fragment_id:03d}",
        rarity_weight=weight,
        last_seen_at=seen,
        text=f"text-{fragment_id}",
        trigger_type=trigger,
        trigger_value=value,
    )


def test_filter_matches_type_and_value() -> None:
    pool = [
        _candidate(1, trigger=TriggerType.MILESTONE_KM, value=3),
        _candidate(2, trigger=TriggerType.MILESTONE_KM, value=5),
        _candidate(3, trigger=TriggerType.DAILY_AMBIENT, value=None),
    ]
    matched = filter_candidates(pool, TriggerType.MILESTONE_KM, 5)
    assert [item.fragment_id for item in matched] == [2]


def test_picks_only_unseen_when_available() -> None:
    pool = [_candidate(1), _candidate(2), _candidate(3)]
    rng = random.Random(0)
    chosen = pick_fragment(pool, {1, 3}, rng)
    assert chosen is not None
    assert chosen.fragment_id == 2


def test_weighted_choice_prefers_heavier_unseen() -> None:
    pool = [_candidate(1, weight=1), _candidate(2, weight=10_000)]
    rng = random.Random(1)
    picks = [pick_fragment(pool, set(), rng) for _ in range(40)]
    ids = [item.fragment_id for item in picks if item is not None]
    assert ids.count(2) > ids.count(1)


def test_exhausted_pool_returns_least_recently_seen() -> None:
    older = datetime(2026, 1, 1, tzinfo=UTC)
    newer = older + timedelta(days=10)
    pool = [
        _candidate(1, seen=newer, weight=99),
        _candidate(2, seen=older, weight=1),
    ]
    chosen = pick_fragment(pool, {1, 2}, random.Random(0))
    assert chosen is not None
    assert chosen.fragment_id == 2


def test_empty_pool_returns_none() -> None:
    assert pick_fragment([], set(), random.Random(0)) is None

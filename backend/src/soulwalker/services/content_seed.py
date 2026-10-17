"""Upsert YAML world packs into Postgres. Runtime engine reads the DB, not files."""

from __future__ import annotations

from pathlib import Path

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from soulwalker.enums import TriggerType
from soulwalker.models.lore import LoreFragment, LoreFragmentPillar
from soulwalker.models.world import Terminology, World, WorldPillar
from soulwalker.services.content_lint import WorldContent, load_all_worlds


async def seed_content(session: AsyncSession, content_root: Path) -> list[str]:
    loaded = load_all_worlds(content_root)
    world_keys: list[str] = []
    for world in loaded:
        await _upsert_world(session, world)
        world_keys.append(world.world_key)
    await session.commit()
    return world_keys


async def _upsert_world(session: AsyncSession, content: WorldContent) -> None:
    world = await session.scalar(select(World).where(World.world_key == content.world_key))
    if world is None:
        world = World(
            world_key=content.world_key,
            name=content.name,
            tone=content.tone,
            art_theme=content.art_theme,
            active=content.active,
        )
        session.add(world)
        await session.flush()
    else:
        world.name = content.name
        world.tone = content.tone
        world.art_theme = content.art_theme
        world.active = content.active

    pillar_ids = await _upsert_pillars(session, world.id, content)
    await _upsert_terms(session, world.id, content.terms)
    await _upsert_fragments(session, world.id, content.fragments, pillar_ids)


async def _upsert_pillars(
    session: AsyncSession,
    world_id: int,
    content: WorldContent,
) -> dict[str, int]:
    existing = (
        await session.scalars(select(WorldPillar).where(WorldPillar.world_id == world_id))
    ).all()
    by_key = {row.pillar_key: row for row in existing}
    for pillar in content.pillars:
        key = str(pillar["key"])
        sort_order = _as_int(pillar["sort_order"])
        row = by_key.get(key)
        if row is None:
            row = WorldPillar(world_id=world_id, pillar_key=key, sort_order=sort_order)
            session.add(row)
            await session.flush()
            by_key[key] = row
        else:
            row.sort_order = sort_order
    return {key: row.id for key, row in by_key.items()}


async def _upsert_terms(
    session: AsyncSession,
    world_id: int,
    terms: dict[str, str],
) -> None:
    existing = (
        await session.scalars(select(Terminology).where(Terminology.world_id == world_id))
    ).all()
    by_key = {row.term_key: row for row in existing}
    for key, value in terms.items():
        row = by_key.get(key)
        if row is None:
            session.add(Terminology(world_id=world_id, term_key=key, term_value=value))
        else:
            row.term_value = value


async def _upsert_fragments(
    session: AsyncSession,
    world_id: int,
    fragments: list[dict[str, object]],
    pillar_ids: dict[str, int],
) -> None:
    existing = (
        await session.scalars(select(LoreFragment).where(LoreFragment.world_id == world_id))
    ).all()
    by_key = {row.fragment_key: row for row in existing}
    for fragment in fragments:
        key = str(fragment["fragment_key"])
        trigger = TriggerType(str(fragment["trigger_type"]))
        raw_value = fragment.get("trigger_value")
        trigger_value = _as_int(raw_value) if raw_value is not None else None
        rarity = _as_int(fragment.get("rarity_weight", 1))
        text = str(fragment["text"])
        row = by_key.get(key)
        if row is None:
            row = LoreFragment(
                world_id=world_id,
                fragment_key=key,
                trigger_type=trigger,
                trigger_value=trigger_value,
                rarity_weight=rarity,
                text=text,
            )
            session.add(row)
            await session.flush()
            by_key[key] = row
        else:
            row.trigger_type = trigger
            row.trigger_value = trigger_value
            row.rarity_weight = rarity
            row.text = text

        await session.execute(
            delete(LoreFragmentPillar).where(LoreFragmentPillar.fragment_id == row.id)
        )
        tags = fragment.get("pillar_tags", [])
        if isinstance(tags, list):
            for tag in tags:
                pillar_id = pillar_ids[str(tag)]
                session.add(LoreFragmentPillar(fragment_id=row.id, pillar_id=pillar_id))


def _as_int(value: object) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        if isinstance(value, str):
            return int(value)
        raise TypeError(f"expected int, got {type(value).__name__}")
    return value

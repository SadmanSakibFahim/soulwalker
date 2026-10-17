"""Terminology keys the engine/UI may resolve. Values live in world content, never here."""

from __future__ import annotations

from enum import StrEnum


class TermKey(StrEnum):
    PLAYER_TITLE = "PLAYER_TITLE"
    CHECKPOINT_NAME = "CHECKPOINT_NAME"
    DEATH_MARKER_NAME = "DEATH_MARKER_NAME"
    AFFLICTION_NAME = "AFFLICTION_NAME"
    ARMAMENT_CATEGORY_WEAPON = "ARMAMENT_CATEGORY_WEAPON"
    ARMAMENT_CATEGORY_ARMOR = "ARMAMENT_CATEGORY_ARMOR"
    BOSS_ENCOUNTER_LABEL = "BOSS_ENCOUNTER_LABEL"
    SUMMONS_NAME = "SUMMONS_NAME"
    STANDINGS_NAME = "STANDINGS_NAME"


REQUIRED_TERM_KEYS: frozenset[str] = frozenset(member.value for member in TermKey)


class MissingTermError(KeyError):
    """Raised when a required key is absent from a world's terminology table."""


def resolve_term(table: dict[str, str], key: TermKey | str) -> str:
    lookup = key.value if isinstance(key, TermKey) else key
    try:
        value = table[lookup]
    except KeyError as exc:
        raise MissingTermError(lookup) from exc
    if not value.strip():
        raise MissingTermError(lookup)
    return value

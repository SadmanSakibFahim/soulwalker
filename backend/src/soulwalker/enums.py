"""Closed sets stored as PG ENUM (trigger types) or SMALLINT (statuses)."""

from __future__ import annotations

from enum import IntEnum, StrEnum


class TriggerType(StrEnum):
    DAILY_AMBIENT = "daily_ambient"
    MILESTONE_KM = "milestone_km"
    ARMAMENT_UNLOCK = "armament_unlock"
    BOSS_KILL = "boss_kill"
    BOSS_DEATH = "boss_death"
    AFFLICTION_STATUS = "affliction_status"
    CHECKPOINT_RETURN = "checkpoint_return"


class AfflictionStatus(IntEnum):
    """Stub for v1. Full affliction loop is post-v1."""

    NONE = 0
    ACTIVE = 1

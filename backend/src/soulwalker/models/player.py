from __future__ import annotations

from datetime import date, datetime

from sqlalchemy import (
    BigInteger,
    Date,
    DateTime,
    ForeignKey,
    Identity,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from soulwalker.enums import AfflictionStatus, CheckpointReason
from soulwalker.models.base import Base, TimestampMixin
from soulwalker.models.lore import LoreFragment
from soulwalker.models.world import World


class Player(TimestampMixin, Base):
    __tablename__ = "players"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    display_name: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(Text, nullable=False)
    active_world_id: Mapped[int | None] = mapped_column(
        ForeignKey("worlds.id", ondelete="SET NULL"),
        nullable=True,
    )

    active_world: Mapped[World | None] = relationship()
    stats: Mapped[PlayerStats | None] = relationship(back_populates="player")
    world_progress: Mapped[list[PlayerWorldProgress]] = relationship(
        back_populates="player",
    )
    armaments: Mapped[list[PlayerArmament]] = relationship(back_populates="player")
    checkpoints: Mapped[list[PlayerCheckpoint]] = relationship(back_populates="player")


class PlayerStats(Base):
    """World-agnostic counters. World switch must not touch this row."""

    __tablename__ = "player_stats"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    player_id: Mapped[int] = mapped_column(
        ForeignKey("players.id", ondelete="CASCADE"),
        unique=True,
        nullable=False,
    )
    total_distance_m: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    current_encounter_streak_days: Mapped[int] = mapped_column(
        SmallInteger,
        nullable=False,
        default=0,
    )
    affliction_status: Mapped[int] = mapped_column(
        SmallInteger,
        nullable=False,
        default=int(AfflictionStatus.NONE),
    )
    today_distance_m: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    progress_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    last_qualified_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    encounter_attempt: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=1)
    encounters_completed: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    player: Mapped[Player] = relationship(back_populates="stats")


class PlayerWorldProgress(Base):
    __tablename__ = "player_world_progress"
    __table_args__ = (UniqueConstraint("player_id", "world_id"),)

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    player_id: Mapped[int] = mapped_column(
        ForeignKey("players.id", ondelete="CASCADE"),
        nullable=False,
    )
    world_id: Mapped[int] = mapped_column(
        ForeignKey("worlds.id", ondelete="CASCADE"),
        nullable=False,
    )
    world_started_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    player: Mapped[Player] = relationship(back_populates="world_progress")
    world: Mapped[World] = relationship()
    seen_fragments: Mapped[list[PlayerSeenFragment]] = relationship(
        back_populates="progress",
        cascade="all, delete-orphan",
    )


class PlayerSeenFragment(Base):
    __tablename__ = "player_seen_fragments"
    __table_args__ = (UniqueConstraint("progress_id", "fragment_id"),)

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    progress_id: Mapped[int] = mapped_column(
        ForeignKey("player_world_progress.id", ondelete="CASCADE"),
        nullable=False,
    )
    fragment_id: Mapped[int] = mapped_column(
        ForeignKey("lore_fragments.id", ondelete="CASCADE"),
        nullable=False,
    )
    seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    progress: Mapped[PlayerWorldProgress] = relationship(back_populates="seen_fragments")
    fragment: Mapped[LoreFragment] = relationship()


class PlayerArmament(Base):
    """Owned armament tier. World switch must not move these rows."""

    __tablename__ = "player_armaments"
    __table_args__ = (UniqueConstraint("player_id", "tier"),)

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    player_id: Mapped[int] = mapped_column(
        ForeignKey("players.id", ondelete="CASCADE"),
        nullable=False,
    )
    tier: Mapped[int] = mapped_column(SmallInteger, nullable=False)
    unlocked_at_distance_m: Mapped[int] = mapped_column(BigInteger, nullable=False)
    unlocked_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    player: Mapped[Player] = relationship(back_populates="armaments")


class PlayerCheckpoint(Base):
    """Rest point. Death does not roll distance or armaments back to an older row."""

    __tablename__ = "player_checkpoints"

    id: Mapped[int] = mapped_column(BigInteger, Identity(), primary_key=True)
    player_id: Mapped[int] = mapped_column(
        ForeignKey("players.id", ondelete="CASCADE"),
        nullable=False,
    )
    reason: Mapped[int] = mapped_column(
        SmallInteger,
        nullable=False,
        default=int(CheckpointReason.ORIGIN),
    )
    banked_distance_m: Mapped[int] = mapped_column(BigInteger, nullable=False)
    encounters_completed: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=0)
    banked_on: Mapped[date] = mapped_column(Date, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    player: Mapped[Player] = relationship(back_populates="checkpoints")

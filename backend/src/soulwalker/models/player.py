from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    BigInteger,
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

from soulwalker.enums import AfflictionStatus
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

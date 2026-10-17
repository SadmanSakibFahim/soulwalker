from __future__ import annotations

from typing import TYPE_CHECKING

from sqlalchemy import (
    Boolean,
    ForeignKey,
    Identity,
    Integer,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from soulwalker.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from soulwalker.models.lore import LoreFragment


class World(TimestampMixin, Base):
    __tablename__ = "worlds"

    id: Mapped[int] = mapped_column(Integer, Identity(), primary_key=True)
    world_key: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    name: Mapped[str] = mapped_column(Text, nullable=False)
    tone: Mapped[str] = mapped_column(Text, nullable=False)
    art_theme: Mapped[str] = mapped_column(String(128), nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    pillars: Mapped[list[WorldPillar]] = relationship(back_populates="world")
    terminology: Mapped[list[Terminology]] = relationship(back_populates="world")
    fragments: Mapped[list[LoreFragment]] = relationship(back_populates="world")


class WorldPillar(Base):
    __tablename__ = "world_pillars"
    __table_args__ = (UniqueConstraint("world_id", "pillar_key"),)

    id: Mapped[int] = mapped_column(Integer, Identity(), primary_key=True)
    world_id: Mapped[int] = mapped_column(
        ForeignKey("worlds.id", ondelete="CASCADE"),
        nullable=False,
    )
    pillar_key: Mapped[str] = mapped_column(String(64), nullable=False)
    sort_order: Mapped[int] = mapped_column(SmallInteger, nullable=False)

    world: Mapped[World] = relationship(back_populates="pillars")


class Terminology(Base):
    __tablename__ = "terminology"
    __table_args__ = (UniqueConstraint("world_id", "term_key"),)

    id: Mapped[int] = mapped_column(Integer, Identity(), primary_key=True)
    world_id: Mapped[int] = mapped_column(
        ForeignKey("worlds.id", ondelete="CASCADE"),
        nullable=False,
    )
    term_key: Mapped[str] = mapped_column(String(64), nullable=False)
    term_value: Mapped[str] = mapped_column(Text, nullable=False)

    world: Mapped[World] = relationship(back_populates="terminology")

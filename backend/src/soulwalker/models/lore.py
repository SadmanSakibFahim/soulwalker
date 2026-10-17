from __future__ import annotations

from sqlalchemy import (
    Enum,
    ForeignKey,
    Identity,
    Integer,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from soulwalker.enums import TriggerType
from soulwalker.models.base import Base
from soulwalker.models.world import World, WorldPillar


class LoreFragment(Base):
    __tablename__ = "lore_fragments"
    __table_args__ = (UniqueConstraint("world_id", "fragment_key"),)

    id: Mapped[int] = mapped_column(Integer, Identity(), primary_key=True)
    world_id: Mapped[int] = mapped_column(
        ForeignKey("worlds.id", ondelete="CASCADE"),
        nullable=False,
    )
    fragment_key: Mapped[str] = mapped_column(String(64), nullable=False)
    trigger_type: Mapped[TriggerType] = mapped_column(
        Enum(
            TriggerType,
            name="trigger_type",
            native_enum=True,
            values_callable=lambda members: [member.value for member in members],
        ),
        nullable=False,
    )
    trigger_value: Mapped[int | None] = mapped_column(Integer, nullable=True)
    rarity_weight: Mapped[int] = mapped_column(SmallInteger, nullable=False, default=1)
    text: Mapped[str] = mapped_column(Text, nullable=False)

    world: Mapped[World] = relationship(back_populates="fragments")
    pillar_links: Mapped[list[LoreFragmentPillar]] = relationship(
        back_populates="fragment",
        cascade="all, delete-orphan",
    )


class LoreFragmentPillar(Base):
    __tablename__ = "lore_fragment_pillars"
    __table_args__ = (UniqueConstraint("fragment_id", "pillar_id"),)

    id: Mapped[int] = mapped_column(Integer, Identity(), primary_key=True)
    fragment_id: Mapped[int] = mapped_column(
        ForeignKey("lore_fragments.id", ondelete="CASCADE"),
        nullable=False,
    )
    pillar_id: Mapped[int] = mapped_column(
        ForeignKey("world_pillars.id", ondelete="CASCADE"),
        nullable=False,
    )

    fragment: Mapped[LoreFragment] = relationship(back_populates="pillar_links")
    pillar: Mapped[WorldPillar] = relationship()

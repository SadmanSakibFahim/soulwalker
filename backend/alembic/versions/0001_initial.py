"""Initial schema: serial PKs, trigger_type enum, world-agnostic player stats.

Revision ID: 0001_initial
Revises:
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0001_initial"
down_revision: str | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

trigger_type = postgresql.ENUM(
    "daily_ambient",
    "milestone_km",
    "armament_unlock",
    "boss_kill",
    "boss_death",
    "affliction_status",
    "checkpoint_return",
    name="trigger_type",
    create_type=False,
)


def upgrade() -> None:
    trigger_type.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "worlds",
        sa.Column("id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("world_key", sa.String(length=64), nullable=False),
        sa.Column("name", sa.Text(), nullable=False),
        sa.Column("tone", sa.Text(), nullable=False),
        sa.Column("art_theme", sa.String(length=128), nullable=False),
        sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint("world_key", name="uq_worlds_world_key"),
    )

    op.create_table(
        "world_pillars",
        sa.Column("id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("world_id", sa.Integer(), nullable=False),
        sa.Column("pillar_key", sa.String(length=64), nullable=False),
        sa.Column("sort_order", sa.SmallInteger(), nullable=False),
        sa.ForeignKeyConstraint(
            ["world_id"],
            ["worlds.id"],
            name="fk_world_pillars_world_id_worlds",
            ondelete="CASCADE",
        ),
        sa.UniqueConstraint("world_id", "pillar_key", name="uq_world_pillars_world_id_pillar_key"),
    )

    op.create_table(
        "terminology",
        sa.Column("id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("world_id", sa.Integer(), nullable=False),
        sa.Column("term_key", sa.String(length=64), nullable=False),
        sa.Column("term_value", sa.Text(), nullable=False),
        sa.ForeignKeyConstraint(
            ["world_id"],
            ["worlds.id"],
            name="fk_terminology_world_id_worlds",
            ondelete="CASCADE",
        ),
        sa.UniqueConstraint("world_id", "term_key", name="uq_terminology_world_id_term_key"),
    )

    op.create_table(
        "lore_fragments",
        sa.Column("id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("world_id", sa.Integer(), nullable=False),
        sa.Column("fragment_key", sa.String(length=64), nullable=False),
        sa.Column("trigger_type", trigger_type, nullable=False),
        sa.Column("trigger_value", sa.Integer(), nullable=True),
        sa.Column("rarity_weight", sa.SmallInteger(), nullable=False, server_default="1"),
        sa.Column("text", sa.Text(), nullable=False),
        sa.ForeignKeyConstraint(
            ["world_id"],
            ["worlds.id"],
            name="fk_lore_fragments_world_id_worlds",
            ondelete="CASCADE",
        ),
        sa.UniqueConstraint(
            "world_id",
            "fragment_key",
            name="uq_lore_fragments_world_id_fragment_key",
        ),
    )
    op.create_index(
        "ix_lore_fragments_world_id_trigger_type",
        "lore_fragments",
        ["world_id", "trigger_type"],
    )

    op.create_table(
        "lore_fragment_pillars",
        sa.Column("id", sa.Integer(), sa.Identity(), primary_key=True),
        sa.Column("fragment_id", sa.Integer(), nullable=False),
        sa.Column("pillar_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(
            ["fragment_id"],
            ["lore_fragments.id"],
            name="fk_lore_fragment_pillars_fragment_id_lore_fragments",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["pillar_id"],
            ["world_pillars.id"],
            name="fk_lore_fragment_pillars_pillar_id_world_pillars",
            ondelete="CASCADE",
        ),
        sa.UniqueConstraint(
            "fragment_id",
            "pillar_id",
            name="uq_lore_fragment_pillars_fragment_id_pillar_id",
        ),
    )

    op.create_table(
        "players",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("display_name", sa.String(length=32), nullable=False),
        sa.Column("password_hash", sa.Text(), nullable=False),
        sa.Column("active_world_id", sa.Integer(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["active_world_id"],
            ["worlds.id"],
            name="fk_players_active_world_id_worlds",
            ondelete="SET NULL",
        ),
        sa.UniqueConstraint("display_name", name="uq_players_display_name"),
    )

    op.create_table(
        "player_stats",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("player_id", sa.BigInteger(), nullable=False),
        sa.Column(
            "total_distance_m",
            sa.BigInteger(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "current_encounter_streak_days",
            sa.SmallInteger(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "affliction_status",
            sa.SmallInteger(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["player_id"],
            ["players.id"],
            name="fk_player_stats_player_id_players",
            ondelete="CASCADE",
        ),
        sa.UniqueConstraint("player_id", name="uq_player_stats_player_id"),
    )

    op.create_table(
        "player_world_progress",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("player_id", sa.BigInteger(), nullable=False),
        sa.Column("world_id", sa.Integer(), nullable=False),
        sa.Column(
            "world_started_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["player_id"],
            ["players.id"],
            name="fk_player_world_progress_player_id_players",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["world_id"],
            ["worlds.id"],
            name="fk_player_world_progress_world_id_worlds",
            ondelete="CASCADE",
        ),
        sa.UniqueConstraint(
            "player_id",
            "world_id",
            name="uq_player_world_progress_player_id_world_id",
        ),
    )

    op.create_table(
        "player_seen_fragments",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("progress_id", sa.BigInteger(), nullable=False),
        sa.Column("fragment_id", sa.Integer(), nullable=False),
        sa.Column(
            "seen_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["progress_id"],
            ["player_world_progress.id"],
            name="fk_player_seen_fragments_progress_id_player_world_progress",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["fragment_id"],
            ["lore_fragments.id"],
            name="fk_player_seen_fragments_fragment_id_lore_fragments",
            ondelete="CASCADE",
        ),
        sa.UniqueConstraint(
            "progress_id",
            "fragment_id",
            name="uq_player_seen_fragments_progress_id_fragment_id",
        ),
    )


def downgrade() -> None:
    op.drop_table("player_seen_fragments")
    op.drop_table("player_world_progress")
    op.drop_table("player_stats")
    op.drop_table("players")
    op.drop_table("lore_fragment_pillars")
    op.drop_index("ix_lore_fragments_world_id_trigger_type", table_name="lore_fragments")
    op.drop_table("lore_fragments")
    op.drop_table("terminology")
    op.drop_table("world_pillars")
    op.drop_table("worlds")
    trigger_type.drop(op.get_bind(), checkfirst=True)

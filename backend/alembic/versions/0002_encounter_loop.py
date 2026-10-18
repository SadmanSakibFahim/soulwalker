"""Encounter day, armament tiers, and checkpoint log.

Revision ID: 0002_encounter_loop
Revises: 0001_initial
"""

from __future__ import annotations

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0002_encounter_loop"
down_revision: str | None = "0001_initial"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "player_stats",
        sa.Column("today_distance_m", sa.BigInteger(), nullable=False, server_default="0"),
    )
    op.add_column("player_stats", sa.Column("progress_date", sa.Date(), nullable=True))
    op.add_column("player_stats", sa.Column("last_qualified_date", sa.Date(), nullable=True))
    op.add_column(
        "player_stats",
        sa.Column("encounter_attempt", sa.SmallInteger(), nullable=False, server_default="1"),
    )
    op.add_column(
        "player_stats",
        sa.Column(
            "encounters_completed",
            sa.SmallInteger(),
            nullable=False,
            server_default="0",
        ),
    )

    op.create_table(
        "player_armaments",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("player_id", sa.BigInteger(), nullable=False),
        sa.Column("tier", sa.SmallInteger(), nullable=False),
        sa.Column("unlocked_at_distance_m", sa.BigInteger(), nullable=False),
        sa.Column(
            "unlocked_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["player_id"],
            ["players.id"],
            name="fk_player_armaments_player_id_players",
            ondelete="CASCADE",
        ),
        sa.UniqueConstraint("player_id", "tier", name="uq_player_armaments_player_id_tier"),
    )

    op.create_table(
        "player_checkpoints",
        sa.Column("id", sa.BigInteger(), sa.Identity(), primary_key=True),
        sa.Column("player_id", sa.BigInteger(), nullable=False),
        sa.Column("reason", sa.SmallInteger(), nullable=False, server_default="0"),
        sa.Column("banked_distance_m", sa.BigInteger(), nullable=False),
        sa.Column(
            "encounters_completed",
            sa.SmallInteger(),
            nullable=False,
            server_default="0",
        ),
        sa.Column("banked_on", sa.Date(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.ForeignKeyConstraint(
            ["player_id"],
            ["players.id"],
            name="fk_player_checkpoints_player_id_players",
            ondelete="CASCADE",
        ),
    )
    op.create_index(
        "ix_player_checkpoints_player_id",
        "player_checkpoints",
        ["player_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_player_checkpoints_player_id", table_name="player_checkpoints")
    op.drop_table("player_checkpoints")
    op.drop_table("player_armaments")
    op.drop_column("player_stats", "encounters_completed")
    op.drop_column("player_stats", "encounter_attempt")
    op.drop_column("player_stats", "last_qualified_date")
    op.drop_column("player_stats", "progress_date")
    op.drop_column("player_stats", "today_distance_m")

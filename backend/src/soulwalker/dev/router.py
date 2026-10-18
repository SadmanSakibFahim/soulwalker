"""PLAYTEST ONLY. Delete `soulwalker/dev/` to remove these routes.

Mounted from main.py only when Settings.dev_mode is true.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import delete, select
from sqlalchemy.orm import selectinload

from soulwalker.api.deps import CurrentPlayer, SessionDep
from soulwalker.api.v1.progress import to_progress_response
from soulwalker.enums import TriggerType
from soulwalker.models.player import Player, PlayerSeenFragment, PlayerStats, PlayerWorldProgress
from soulwalker.models.world import World
from soulwalker.schemas.auth import TokenResponse
from soulwalker.schemas.lore import LoreFragmentResponse
from soulwalker.schemas.progress import DistanceRequest, ProgressResponse
from soulwalker.services.auth import create_access_token, hash_password
from soulwalker.services.lore import LoreDeliveryError, deliver_lore
from soulwalker.services.progress import close_progress_day, grant_distance

DEV_DISPLAY_NAME = "devwalker"
DEV_PASSWORD = "devdevdev8"

router = APIRouter(prefix="/v1/dev", tags=["dev"])


class DevLoreRequest(BaseModel):
    trigger_type: TriggerType = TriggerType.DAILY_AMBIENT
    trigger_value: int | None = None


@router.get("/status")
async def status_probe() -> dict[str, bool]:
    return {"dev_mode": True}


@router.post("/bootstrap", response_model=TokenResponse)
async def bootstrap(session: SessionDep) -> TokenResponse:
    player = await session.scalar(select(Player).where(Player.display_name == DEV_DISPLAY_NAME))
    if player is None:
        world = await session.scalar(select(World).where(World.active.is_(True)).limit(1))
        player = Player(
            display_name=DEV_DISPLAY_NAME,
            password_hash=hash_password(DEV_PASSWORD),
            active_world_id=world.id if world else None,
        )
        session.add(player)
        await session.flush()
        session.add(PlayerStats(player_id=player.id))
        if world is not None:
            session.add(PlayerWorldProgress(player_id=player.id, world_id=world.id))
        await session.commit()
    return TokenResponse(access_token=create_access_token(player.id), player_id=player.id)


@router.post("/grant-distance", response_model=ProgressResponse)
async def grant_distance_dev(
    body: DistanceRequest,
    player: CurrentPlayer,
    session: SessionDep,
) -> ProgressResponse:
    view = await grant_distance(session, player, body.meters)
    return to_progress_response(player, view)


@router.post("/close-day", response_model=ProgressResponse)
async def close_day_dev(player: CurrentPlayer, session: SessionDep) -> ProgressResponse:
    view = await close_progress_day(session, player)
    return to_progress_response(player, view)


@router.post("/reset-lore")
async def reset_lore(player: CurrentPlayer, session: SessionDep) -> dict[str, str]:
    if player.active_world_id is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="no active world")
    progress = await session.scalar(
        select(PlayerWorldProgress).where(
            PlayerWorldProgress.player_id == player.id,
            PlayerWorldProgress.world_id == player.active_world_id,
        )
    )
    if progress is not None:
        await session.execute(
            delete(PlayerSeenFragment).where(PlayerSeenFragment.progress_id == progress.id)
        )
        await session.commit()
    return {"status": "ok"}


@router.post("/deliver-lore", response_model=LoreFragmentResponse)
async def dev_deliver_lore(
    body: DevLoreRequest,
    player: CurrentPlayer,
    session: SessionDep,
) -> LoreFragmentResponse:
    loaded = await session.scalar(
        select(Player).options(selectinload(Player.stats)).where(Player.id == player.id)
    )
    if loaded is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="unknown player")
    try:
        fragment = await deliver_lore(session, loaded, body.trigger_type, body.trigger_value)
    except LoreDeliveryError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
    return LoreFragmentResponse(
        fragment_key=fragment.fragment_key,
        trigger_type=fragment.trigger_type,
        trigger_value=fragment.trigger_value,
        text=fragment.text,
    )

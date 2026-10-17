from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select

from soulwalker.api.deps import CurrentPlayer, SessionDep
from soulwalker.models.player import Player, PlayerStats, PlayerWorldProgress
from soulwalker.models.world import World
from soulwalker.schemas.auth import (
    LoginRequest,
    PlayerResponse,
    RegisterRequest,
    TokenResponse,
)
from soulwalker.services.auth import (
    create_access_token,
    hash_password,
    verify_password,
)

router = APIRouter(prefix="/v1/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(body: RegisterRequest, session: SessionDep) -> TokenResponse:
    existing = await session.scalar(select(Player).where(Player.display_name == body.display_name))
    if existing is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="display_name taken")

    world = await session.scalar(select(World).where(World.active.is_(True)).limit(1))
    player = Player(
        display_name=body.display_name,
        password_hash=hash_password(body.password),
        active_world_id=world.id if world else None,
    )
    session.add(player)
    await session.flush()
    session.add(PlayerStats(player_id=player.id))
    if world is not None:
        session.add(PlayerWorldProgress(player_id=player.id, world_id=world.id))
    await session.commit()
    return TokenResponse(access_token=create_access_token(player.id), player_id=player.id)


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, session: SessionDep) -> TokenResponse:
    player = await session.scalar(select(Player).where(Player.display_name == body.display_name))
    if player is None or not verify_password(body.password, player.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid credentials",
        )
    return TokenResponse(access_token=create_access_token(player.id), player_id=player.id)


@router.get("/me", response_model=PlayerResponse)
async def me(player: CurrentPlayer) -> PlayerResponse:
    stats = player.stats
    return PlayerResponse(
        id=player.id,
        display_name=player.display_name,
        active_world_id=player.active_world_id,
        total_distance_m=stats.total_distance_m if stats else 0,
        current_encounter_streak_days=(stats.current_encounter_streak_days if stats else 0),
        affliction_status=stats.affliction_status if stats else 0,
    )

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from soulwalker.api.deps import CurrentPlayer, SessionDep
from soulwalker.models.world import World
from soulwalker.schemas.world import TerminologyResponse, WorldResponse

router = APIRouter(prefix="/v1/worlds", tags=["worlds"])


@router.get("", response_model=list[WorldResponse])
async def list_worlds(session: SessionDep) -> list[WorldResponse]:
    worlds = (await session.scalars(select(World).options(selectinload(World.pillars)))).all()
    return [
        WorldResponse(
            id=world.id,
            world_key=world.world_key,
            name=world.name,
            tone=world.tone,
            art_theme=world.art_theme,
            active=world.active,
            pillars=[
                pillar.pillar_key
                for pillar in sorted(world.pillars, key=lambda item: item.sort_order)
            ],
        )
        for world in worlds
    ]


@router.get("/current/terminology", response_model=TerminologyResponse)
async def current_terminology(
    player: CurrentPlayer,
    session: SessionDep,
) -> TerminologyResponse:
    if player.active_world_id is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="no active world",
        )
    world = await session.scalar(
        select(World)
        .options(selectinload(World.terminology))
        .where(World.id == player.active_world_id)
    )
    if world is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="world missing")
    return TerminologyResponse(
        world_id=world.id,
        world_key=world.world_key,
        terms={row.term_key: row.term_value for row in world.terminology},
    )

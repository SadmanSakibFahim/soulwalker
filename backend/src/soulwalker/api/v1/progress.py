from fastapi import APIRouter, HTTPException, status

from soulwalker.api.deps import CurrentPlayer, SessionDep
from soulwalker.domain.encounter import DAILY_QUALIFY_M, ENCOUNTER_LENGTH_DAYS, DayActivity
from soulwalker.models.player import Player
from soulwalker.schemas.progress import ActivitySyncRequest, DistanceRequest, ProgressResponse
from soulwalker.services.progress import (
    ProgressView,
    close_progress_day,
    grant_distance,
    read_progress,
    sync_activity,
)

router = APIRouter(prefix="/v1/progress", tags=["progress"])


def to_progress_response(player: Player, view: ProgressView) -> ProgressResponse:
    return ProgressResponse(
        id=player.id,
        display_name=player.display_name,
        total_distance_m=view.total_distance_m,
        today_distance_m=view.today_distance_m,
        progress_date=view.progress_date,
        current_encounter_streak_days=view.streak_days,
        encounter_attempt=view.attempt,
        encounters_completed=view.encounters_completed,
        unlocked_armament_tiers=list(view.unlocked_tiers),
        daily_qualify_m=DAILY_QUALIFY_M,
        encounter_length_days=ENCOUNTER_LENGTH_DAYS,
        events=list(view.events),
    )


@router.get("", response_model=ProgressResponse)
async def get_progress(player: CurrentPlayer, session: SessionDep) -> ProgressResponse:
    view = await read_progress(session, player)
    return to_progress_response(player, view)


@router.post("/distance", response_model=ProgressResponse)
async def post_distance(
    body: DistanceRequest,
    player: CurrentPlayer,
    session: SessionDep,
) -> ProgressResponse:
    try:
        view = await grant_distance(session, player, body.meters)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return to_progress_response(player, view)


@router.post("/activity", response_model=ProgressResponse)
async def post_activity(
    body: ActivitySyncRequest,
    player: CurrentPlayer,
    session: SessionDep,
) -> ProgressResponse:
    try:
        view = await sync_activity(
            session,
            player,
            tuple(DayActivity(on_date=day.date, distance_m=day.distance_m) for day in body.days),
        )
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
    return to_progress_response(player, view)


@router.post("/close-day", response_model=ProgressResponse)
async def post_close_day(player: CurrentPlayer, session: SessionDep) -> ProgressResponse:
    view = await close_progress_day(session, player)
    return to_progress_response(player, view)

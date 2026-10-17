from fastapi import APIRouter, HTTPException, status

from soulwalker.api.deps import CurrentPlayer, SessionDep
from soulwalker.schemas.lore import LoreDeliverRequest, LoreFragmentResponse
from soulwalker.services.lore import LoreDeliveryError, deliver_lore

router = APIRouter(prefix="/v1/lore", tags=["lore"])


@router.post("/deliver", response_model=LoreFragmentResponse)
async def deliver(
    body: LoreDeliverRequest,
    player: CurrentPlayer,
    session: SessionDep,
) -> LoreFragmentResponse:
    try:
        fragment = await deliver_lore(
            session,
            player,
            body.trigger_type,
            body.trigger_value,
        )
    except LoreDeliveryError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    return LoreFragmentResponse(
        fragment_key=fragment.fragment_key,
        trigger_type=fragment.trigger_type,
        trigger_value=fragment.trigger_value,
        text=fragment.text,
    )

from __future__ import annotations

from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from soulwalker.db.session import get_session
from soulwalker.models.player import Player
from soulwalker.services.auth import AuthError, parse_access_token

bearer = HTTPBearer(auto_error=False)
SessionDep = Annotated[AsyncSession, Depends(get_session)]


async def get_current_player(
    session: SessionDep,
    credentials: Annotated[
        HTTPAuthorizationCredentials | None,
        Depends(bearer),
    ],
) -> Player:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="missing token")
    try:
        player_id = parse_access_token(credentials.credentials)
    except AuthError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid token",
        ) from exc
    player = await session.scalar(
        select(Player).options(selectinload(Player.stats)).where(Player.id == player_id)
    )
    if player is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="unknown player")
    return player


CurrentPlayer = Annotated[Player, Depends(get_current_player)]

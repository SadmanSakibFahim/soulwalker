from __future__ import annotations

from pydantic import BaseModel, Field


class RegisterRequest(BaseModel):
    display_name: str = Field(min_length=3, max_length=32)
    password: str = Field(min_length=8, max_length=72)


class LoginRequest(BaseModel):
    display_name: str = Field(min_length=3, max_length=32)
    password: str = Field(min_length=8, max_length=72)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    player_id: int


class PlayerResponse(BaseModel):
    id: int
    display_name: str
    active_world_id: int | None
    total_distance_m: int
    current_encounter_streak_days: int
    affliction_status: int

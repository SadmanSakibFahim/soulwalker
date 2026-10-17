from __future__ import annotations

from pydantic import BaseModel


class WorldResponse(BaseModel):
    id: int
    world_key: str
    name: str
    tone: str
    art_theme: str
    active: bool
    pillars: list[str]


class TerminologyResponse(BaseModel):
    world_id: int
    world_key: str
    terms: dict[str, str]

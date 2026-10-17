from __future__ import annotations

from pydantic import BaseModel

from soulwalker.enums import TriggerType


class LoreDeliverRequest(BaseModel):
    trigger_type: TriggerType
    trigger_value: int | None = None


class LoreFragmentResponse(BaseModel):
    fragment_key: str
    trigger_type: TriggerType
    trigger_value: int | None
    text: str

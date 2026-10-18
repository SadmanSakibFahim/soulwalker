from datetime import date

from pydantic import BaseModel, Field

from soulwalker.domain.encounter import MAX_DAY_DISTANCE_M


class DistanceRequest(BaseModel):
    meters: int = Field(gt=0, le=100_000)


class ActivityDayRequest(BaseModel):
    date: date
    distance_m: int = Field(ge=0, le=MAX_DAY_DISTANCE_M)


class ActivitySyncRequest(BaseModel):
    days: list[ActivityDayRequest] = Field(min_length=1, max_length=62)


class ProgressResponse(BaseModel):
    id: int
    display_name: str
    total_distance_m: int
    today_distance_m: int
    progress_date: date | None
    current_encounter_streak_days: int
    encounter_attempt: int
    encounters_completed: int
    unlocked_armament_tiers: list[int]
    daily_qualify_m: int
    encounter_length_days: int
    events: list[str]

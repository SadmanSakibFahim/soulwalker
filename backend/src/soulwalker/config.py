from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


def _repo_root() -> Path:
    # backend/src/soulwalker/config.py → repo root
    return Path(__file__).resolve().parents[3]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(_repo_root() / ".env", Path(__file__).resolve().parents[2] / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    database_url: str = "postgresql+psycopg://soulwalker:soulwalker@127.0.0.1:5433/soulwalker"
    jwt_secret: str = "change-me-in-development"
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24 * 14
    content_root: Path = _repo_root() / "content"
    # Playtest routes under /v1/dev. Keep false in any shipped environment.
    dev_mode: bool = False


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()

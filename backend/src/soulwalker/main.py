from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from soulwalker.api.v1.router import api_router
from soulwalker.config import get_settings

app = FastAPI(title="Soulwalker API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(api_router)

if get_settings().dev_mode:
    from soulwalker.dev.router import router as dev_router

    app.include_router(dev_router)

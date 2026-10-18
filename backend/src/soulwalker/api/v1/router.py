from fastapi import APIRouter

from soulwalker.api.v1 import auth, health, lore, progress, worlds

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(auth.router)
api_router.include_router(worlds.router)
api_router.include_router(lore.router)
api_router.include_router(progress.router)

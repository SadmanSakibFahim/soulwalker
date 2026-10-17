from __future__ import annotations

from collections.abc import AsyncIterator
from pathlib import Path

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from soulwalker.config import get_settings
from soulwalker.db.session import get_session
from soulwalker.main import app
from soulwalker.services.content_seed import seed_content

pytestmark = pytest.mark.integration


def _database_url() -> str:
    return get_settings().database_url


@pytest.fixture
async def client() -> AsyncClient:
    url = _database_url()
    engine = create_async_engine(url, pool_pre_ping=True)
    try:
        async with engine.connect() as connection:
            await connection.run_sync(lambda _conn: None)
    except Exception as exc:
        pytest.skip(f"postgres unavailable: {exc}")

    factory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)

    async def override_session() -> AsyncIterator[AsyncSession]:
        async with factory() as session:
            yield session

    app.dependency_overrides[get_session] = override_session
    repo_root = Path(__file__).resolve().parents[3]
    async with factory() as session:
        await seed_content(session, repo_root / "content")

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as async_client:
        yield async_client
    app.dependency_overrides.clear()
    await engine.dispose()


async def test_health(client: AsyncClient) -> None:
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


async def test_register_terminology_and_lore(client: AsyncClient) -> None:
    register = await client.post(
        "/v1/auth/register",
        json={"display_name": "halfwoken_it", "password": "password123"},
    )
    if register.status_code == 409:
        register = await client.post(
            "/v1/auth/login",
            json={"display_name": "halfwoken_it", "password": "password123"},
        )
    assert register.status_code in {200, 201}
    token = register.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    me = await client.get("/v1/auth/me", headers=headers)
    assert me.status_code == 200
    assert me.json()["total_distance_m"] == 0

    terms = await client.get("/v1/worlds/current/terminology", headers=headers)
    assert terms.status_code == 200
    body = terms.json()["terms"]
    assert body["CHECKPOINT_NAME"] == "a Held Breath"
    assert "Tarnished" not in body.values()

    lore = await client.post(
        "/v1/lore/deliver",
        headers=headers,
        json={"trigger_type": "daily_ambient"},
    )
    assert lore.status_code == 200
    assert lore.json()["fragment_key"].startswith("f_da_")


async def test_dev_bootstrap_and_grant_distance(client: AsyncClient) -> None:
    probe = await client.get("/v1/dev/status")
    if probe.status_code != 200:
        pytest.skip("dev_mode disabled")
    bootstrap = await client.post("/v1/dev/bootstrap")
    assert bootstrap.status_code == 200
    token = bootstrap.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    granted = await client.post(
        "/v1/dev/grant-distance",
        headers=headers,
        json={"meters": 3000},
    )
    assert granted.status_code == 200
    assert granted.json()["total_distance_m"] >= 3000
    assert granted.json()["display_name"] == "devwalker"

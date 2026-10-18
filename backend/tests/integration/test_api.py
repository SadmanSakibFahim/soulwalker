from __future__ import annotations

import secrets
from collections.abc import AsyncIterator
from datetime import date, timedelta
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


async def test_encounter_death_keeps_distance_and_armaments(client: AsyncClient) -> None:
    name = f"loop{secrets.token_hex(4)}"
    register = await client.post(
        "/v1/auth/register",
        json={"display_name": name, "password": "password123"},
    )
    assert register.status_code == 201
    headers = {"Authorization": f"Bearer {register.json()['access_token']}"}

    granted = await client.post(
        "/v1/progress/distance",
        headers=headers,
        json={"meters": 5000},
    )
    assert granted.status_code == 200
    body = granted.json()
    assert body["total_distance_m"] == 5000
    assert body["current_encounter_streak_days"] == 1
    assert body["unlocked_armament_tiers"] == [1, 2]
    assert "day_qualified" in body["events"]
    assert "encounter_completed" not in body["events"]

    held = await client.post("/v1/progress/close-day", headers=headers)
    assert held.status_code == 200
    assert held.json()["current_encounter_streak_days"] == 1
    assert held.json()["today_distance_m"] == 0
    assert "death" not in held.json()["events"]

    died = await client.post("/v1/progress/close-day", headers=headers)
    assert died.status_code == 200
    dead = died.json()
    assert "death" in dead["events"]
    assert dead["current_encounter_streak_days"] == 0
    assert dead["encounter_attempt"] == 2
    assert dead["total_distance_m"] == 5000
    assert dead["unlocked_armament_tiers"] == [1, 2]
    assert dead["encounters_completed"] == 0


async def test_five_days_complete_one_encounter(client: AsyncClient) -> None:
    name = f"night{secrets.token_hex(4)}"
    register = await client.post(
        "/v1/auth/register",
        json={"display_name": name, "password": "password123"},
    )
    assert register.status_code == 201
    headers = {"Authorization": f"Bearer {register.json()['access_token']}"}

    for day in range(5):
        granted = await client.post(
            "/v1/progress/distance",
            headers=headers,
            json={"meters": 5000},
        )
        assert granted.status_code == 200
        body = granted.json()
        if day < 4:
            assert body["current_encounter_streak_days"] == day + 1
            assert body["encounters_completed"] == 0
            closed = await client.post("/v1/progress/close-day", headers=headers)
            assert closed.status_code == 200
            assert "death" not in closed.json()["events"]
        else:
            assert body["encounters_completed"] == 1
            assert body["current_encounter_streak_days"] == 0
            assert "encounter_completed" in body["events"]


async def test_activity_sync_banks_new_meters_and_rolls_the_local_day(
    client: AsyncClient,
) -> None:
    name = f"health{secrets.token_hex(4)}"
    register = await client.post(
        "/v1/auth/register",
        json={"display_name": name, "password": "password123"},
    )
    assert register.status_code == 201
    headers = {"Authorization": f"Bearer {register.json()['access_token']}"}
    today = date.today()
    nxt = today + timedelta(days=1)

    first = await client.post(
        "/v1/progress/activity",
        headers=headers,
        json={"days": [{"date": today.isoformat(), "distance_m": 2000}]},
    )
    assert first.status_code == 200
    assert first.json()["today_distance_m"] == 2000
    assert first.json()["total_distance_m"] == 2000
    assert first.json()["progress_date"] == today.isoformat()

    same = await client.post(
        "/v1/progress/activity",
        headers=headers,
        json={"days": [{"date": today.isoformat(), "distance_m": 2000}]},
    )
    assert same.status_code == 200
    assert same.json()["total_distance_m"] == 2000
    assert same.json()["events"] == []

    rolled = await client.post(
        "/v1/progress/activity",
        headers=headers,
        json={
            "days": [
                {"date": today.isoformat(), "distance_m": 5000},
                {"date": nxt.isoformat(), "distance_m": 1000},
            ]
        },
    )
    assert rolled.status_code == 200
    body = rolled.json()
    assert body["total_distance_m"] == 6000
    assert body["today_distance_m"] == 1000
    assert body["progress_date"] == nxt.isoformat()
    assert body["current_encounter_streak_days"] == 1
    assert "death" not in body["events"]
    assert body["unlocked_armament_tiers"] == [1, 2]


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

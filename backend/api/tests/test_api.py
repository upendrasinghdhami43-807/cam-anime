import httpx
from sqlalchemy import select

from app.models import Feedback


async def test_health_reports_database_ok(client: httpx.AsyncClient) -> None:
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "db": "ok"}


async def test_styles_are_seeded_and_ordered(client: httpx.AsyncClient) -> None:
    response = await client.get("/v1/styles")
    assert response.status_code == 200
    items = response.json()["items"]
    assert [item["id"] for item in items] == ["original", "cel_pop", "ink_comic", "soft_pastel", "noir_sketch"]
    cel = items[1]
    assert cel["name"] == "Cel Pop"
    assert cel["version"] == 1
    assert cel["sortOrder"] == 1
    assert cel["params"]["quantize"]["bands"] == 5


async def test_get_single_style_and_404(client: httpx.AsyncClient) -> None:
    ok = await client.get("/v1/styles/noir_sketch")
    assert ok.status_code == 200
    assert ok.json()["id"] == "noir_sketch"

    missing = await client.get("/v1/styles/nope")
    assert missing.status_code == 404


async def test_config_documents_offline_only_product(client: httpx.AsyncClient) -> None:
    body = (await client.get("/v1/config")).json()
    assert body["apiVersion"] == 1
    assert body["features"] == {"offlineOnly": True, "accounts": False, "cloudBackup": False, "payments": False}


async def test_feedback_is_stored_anonymously(client: httpx.AsyncClient) -> None:
    response = await client.post(
        "/v1/feedback",
        json={"message": "  nice cartoon  ", "appVersion": "1.0.0", "device": "Pixel test"},
    )
    assert response.status_code == 201
    feedback_id = response.json()["id"]

    async with client.app.state.session_factory() as session:  # type: ignore[attr-defined]
        row = (await session.scalars(select(Feedback).where(Feedback.id == feedback_id))).one()
    assert row.message == "nice cartoon"
    assert row.app_version == "1.0.0"
    assert row.device == "Pixel test"


async def test_feedback_validation(client: httpx.AsyncClient) -> None:
    blank = await client.post("/v1/feedback", json={"message": "   ", "appVersion": "1.0.0"})
    too_long = await client.post("/v1/feedback", json={"message": "x" * 2001, "appVersion": "1.0.0"})
    missing = await client.post("/v1/feedback", json={"appVersion": "1.0.0"})
    assert blank.status_code == 422
    assert too_long.status_code == 422
    assert missing.status_code == 422


async def test_seeding_is_idempotent(client: httpx.AsyncClient) -> None:
    from app.seed import seed_styles

    async with client.app.state.session_factory() as session:  # type: ignore[attr-defined]
        assert await seed_styles(session) == 0

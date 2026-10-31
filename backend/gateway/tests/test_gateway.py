import httpx

from app.config import Settings
from app.main import create_app
from app.ratelimit import SlidingWindowLimiter


async def test_health_combines_upstream_status(harness) -> None:  # type: ignore[no-untyped-def]
    _, client = harness
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "service": "gateway", "upstream": {"status": "ok", "db": "ok"}}


async def test_health_degraded_when_upstream_down(harness) -> None:  # type: ignore[no-untyped-def]
    fake, client = harness

    def down(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("refused")

    fake.handler = down
    response = await client.get("/health")
    assert response.status_code == 503
    assert response.json()["status"] == "degraded"
    assert response.json()["upstream"] == {"status": "unreachable"}


async def test_get_is_proxied_with_query_and_request_id(harness) -> None:  # type: ignore[no-untyped-def]
    fake, client = harness
    fake.handler = lambda request: httpx.Response(200, json={"items": []})

    response = await client.get("/v1/styles?limit=3", headers={"X-Request-ID": "req-123"})

    assert response.status_code == 200
    assert response.json() == {"items": []}
    assert response.headers["X-Request-ID"] == "req-123"
    upstream_request = fake.seen[-1]
    assert upstream_request.url.path == "/v1/styles"
    assert upstream_request.url.query == b"limit=3"
    assert upstream_request.headers["X-Request-ID"] == "req-123"


async def test_post_body_and_status_are_passed_through(harness) -> None:  # type: ignore[no-untyped-def]
    fake, client = harness
    fake.handler = lambda request: httpx.Response(201, json={"id": "abc"})

    response = await client.post("/v1/feedback", json={"message": "hi", "appVersion": "1"})

    assert response.status_code == 201
    assert response.json() == {"id": "abc"}
    assert fake.seen[-1].content == b'{"message":"hi","appVersion":"1"}'


async def test_upstream_errors_are_passed_through(harness) -> None:  # type: ignore[no-untyped-def]
    fake, client = harness
    fake.handler = lambda request: httpx.Response(422, json={"detail": "bad"})

    response = await client.post("/v1/feedback", json={})

    assert response.status_code == 422


async def test_unreachable_upstream_maps_to_502_and_timeout_to_504(harness) -> None:  # type: ignore[no-untyped-def]
    fake, client = harness

    def refused(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("refused")

    def slow(request: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("slow")

    fake.handler = refused
    assert (await client.get("/v1/styles")).status_code == 502
    fake.handler = slow
    assert (await client.get("/v1/styles")).status_code == 504


async def test_only_v1_is_exposed_and_only_get_post(harness) -> None:  # type: ignore[no-untyped-def]
    fake, client = harness

    assert (await client.get("/admin")).status_code == 404
    assert (await client.delete("/v1/feedback")).status_code == 405
    assert fake.seen == []


async def test_api_key_is_enforced_when_configured() -> None:
    seen: list[httpx.Request] = []

    def upstream(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        return httpx.Response(200, json={"items": []})

    app = create_app(Settings(api_key="secret", rate_limit_per_minute=1000), transport=httpx.MockTransport(upstream))
    async with app.router.lifespan_context(app):
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://gw") as client:
            assert (await client.get("/v1/styles")).status_code == 401
            assert (await client.get("/v1/styles", headers={"X-API-Key": "wrong"})).status_code == 401
            assert (await client.get("/v1/styles", headers={"X-API-Key": "secret"})).status_code == 200
    assert len(seen) == 1


async def test_oversized_body_is_rejected() -> None:
    app = create_app(Settings(max_body_bytes=10, rate_limit_per_minute=1000), transport=httpx.MockTransport(lambda r: httpx.Response(200)))
    async with app.router.lifespan_context(app):
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://gw") as client:
            response = await client.post("/v1/feedback", content=b"x" * 50)
            assert response.status_code == 413


async def test_rate_limit_returns_429() -> None:
    app = create_app(Settings(rate_limit_per_minute=2), transport=httpx.MockTransport(lambda r: httpx.Response(200, json={})))
    async with app.router.lifespan_context(app):
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://gw") as client:
            assert (await client.get("/v1/styles")).status_code == 200
            assert (await client.get("/v1/styles")).status_code == 200
            blocked = await client.get("/v1/styles")
            assert blocked.status_code == 429
            assert blocked.headers["Retry-After"] == "60"


def test_limiter_window_expires() -> None:
    now = [0.0]
    limiter = SlidingWindowLimiter(limit=2, window_seconds=60, clock=lambda: now[0])

    assert limiter.allow("a") and limiter.allow("a")
    assert not limiter.allow("a")
    assert limiter.allow("b")
    now[0] = 61
    assert limiter.allow("a")

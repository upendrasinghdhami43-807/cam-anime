from collections.abc import AsyncIterator, Callable

import httpx
import pytest_asyncio

from app.config import Settings
from app.main import create_app

Handler = Callable[[httpx.Request], httpx.Response]


class Harness:
    """A gateway wired to a fake upstream. Set `handler` per test and inspect `seen` afterwards."""

    def __init__(self) -> None:
        self.seen: list[httpx.Request] = []
        self.handler: Handler = lambda request: httpx.Response(200, json={"status": "ok", "db": "ok"})

    def upstream(self, request: httpx.Request) -> httpx.Response:
        self.seen.append(request)
        return self.handler(request)


@pytest_asyncio.fixture
async def harness() -> AsyncIterator[tuple[Harness, httpx.AsyncClient]]:
    fake = Harness()
    settings = Settings(upstream_url="http://api:8000", rate_limit_per_minute=1000)
    app = create_app(settings, transport=httpx.MockTransport(fake.upstream))
    async with app.router.lifespan_context(app):
        async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://gw") as client:
            yield fake, client

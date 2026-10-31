from collections.abc import AsyncIterator

import httpx
import pytest_asyncio

from app.config import Settings
from app.main import create_app


@pytest_asyncio.fixture
async def client() -> AsyncIterator[httpx.AsyncClient]:
    settings = Settings(database_url="sqlite+aiosqlite:///:memory:", db_connect_retries=1, db_connect_delay_seconds=0)
    app = create_app(settings)
    # ASGITransport does not run lifespan events, so run them explicitly.
    async with app.router.lifespan_context(app):
        transport = httpx.ASGITransport(app=app)
        async with httpx.AsyncClient(transport=transport, base_url="http://api") as http_client:
            http_client.app = app  # type: ignore[attr-defined]
            yield http_client

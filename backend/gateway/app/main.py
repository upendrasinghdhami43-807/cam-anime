import hmac
import logging
import uuid
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse

from .config import Settings
from .ratelimit import SlidingWindowLimiter

log = logging.getLogger("camanime.gateway")

REQUEST_ID_HEADER = "X-Request-ID"
API_KEY_HEADER = "X-API-Key"
# Only these request headers are forwarded to the API service.
FORWARDED_REQUEST_HEADERS = {"content-type", "accept", "accept-language"}


def create_app(settings: Settings | None = None, transport: httpx.AsyncBaseTransport | None = None) -> FastAPI:
    """Single public entry point. Every /v1 call is forwarded to the API service; nothing else is exposed."""
    settings = settings or Settings()
    logging.basicConfig(level=settings.log_level)
    limiter = SlidingWindowLimiter(settings.rate_limit_per_minute)

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        app.state.upstream = httpx.AsyncClient(
            base_url=settings.upstream_url,
            timeout=settings.upstream_timeout_seconds,
            transport=transport,
        )
        yield
        await app.state.upstream.aclose()

    app = FastAPI(title="Cam-Anime Gateway", version="1.0.0", lifespan=lifespan)

    @app.middleware("http")
    async def request_context(request: Request, call_next):  # type: ignore[no-untyped-def]
        request_id = request.headers.get(REQUEST_ID_HEADER) or str(uuid.uuid4())
        request.state.request_id = request_id

        client_ip = request.client.host if request.client else "unknown"
        if not limiter.allow(client_ip):
            response: Response = JSONResponse({"detail": "Too many requests"}, status_code=429, headers={"Retry-After": "60"})
        elif request.url.path.startswith("/v1") and settings.api_key and not hmac.compare_digest(
            request.headers.get(API_KEY_HEADER, ""), settings.api_key
        ):
            response = JSONResponse({"detail": "Invalid or missing API key"}, status_code=401)
        elif int(request.headers.get("content-length") or 0) > settings.max_body_bytes:
            response = JSONResponse({"detail": "Request body too large"}, status_code=413)
        else:
            response = await call_next(request)

        response.headers[REQUEST_ID_HEADER] = request_id
        return response

    @app.get("/health")
    async def health(request: Request) -> JSONResponse:
        try:
            upstream = await request.app.state.upstream.get("/health", headers={REQUEST_ID_HEADER: request.state.request_id})
            upstream_body = upstream.json()
            ok = upstream.status_code == 200 and upstream_body.get("status") == "ok"
        except (httpx.HTTPError, ValueError):
            upstream_body = {"status": "unreachable"}
            ok = False
        return JSONResponse(
            {"status": "ok" if ok else "degraded", "service": "gateway", "upstream": upstream_body},
            status_code=200 if ok else 503,
        )

    @app.api_route("/v1/{path:path}", methods=["GET", "POST"])
    async def proxy(path: str, request: Request) -> Response:
        headers = {k: v for k, v in request.headers.items() if k.lower() in FORWARDED_REQUEST_HEADERS}
        headers[REQUEST_ID_HEADER] = request.state.request_id
        try:
            upstream = await request.app.state.upstream.request(
                request.method,
                f"/v1/{path}",
                params=request.query_params,
                content=await request.body(),
                headers=headers,
            )
        except httpx.TimeoutException:
            log.warning("upstream timeout request_id=%s path=/v1/%s", request.state.request_id, path)
            return JSONResponse({"detail": "Upstream timeout"}, status_code=504)
        except httpx.HTTPError:
            log.warning("upstream unreachable request_id=%s path=/v1/%s", request.state.request_id, path)
            return JSONResponse({"detail": "Upstream unavailable"}, status_code=502)

        return Response(
            content=upstream.content,
            status_code=upstream.status_code,
            media_type=upstream.headers.get("content-type"),
        )

    return app

import asyncio
import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import APIRouter, Depends, FastAPI, HTTPException, Request, Response
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from .config import Settings
from .db import Base, make_engine, make_session_factory
from .models import CartoonStyle, Feedback
from .schemas import ConfigOut, FeedbackIn, FeedbackOut, StyleList, StyleOut
from .seed import seed_styles

log = logging.getLogger("camanime.api")


async def _init_database(app: FastAPI, settings: Settings) -> None:
    last_error: Exception | None = None
    for attempt in range(1, settings.db_connect_retries + 1):
        try:
            async with app.state.engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
            async with app.state.session_factory() as session:
                created = await seed_styles(session)
            log.info("database ready (seeded %d styles)", created)
            return
        except Exception as error:  # noqa: BLE001 - retry on any startup connection failure
            last_error = error
            log.warning("database not ready (attempt %d/%d): %s", attempt, settings.db_connect_retries, error)
            await asyncio.sleep(settings.db_connect_delay_seconds)
    raise RuntimeError("database never became ready") from last_error


async def get_session(request: Request) -> AsyncIterator[AsyncSession]:
    async with request.app.state.session_factory() as session:
        yield session


router = APIRouter(prefix="/v1")


@router.get("/styles", response_model=StyleList)
async def list_styles(session: AsyncSession = Depends(get_session)) -> StyleList:
    rows = (
        await session.scalars(
            select(CartoonStyle).where(CartoonStyle.enabled.is_(True)).order_by(CartoonStyle.sort_order)
        )
    ).all()
    return StyleList(items=[StyleOut.model_validate(row) for row in rows])


@router.get("/styles/{style_id}", response_model=StyleOut)
async def get_style(style_id: str, session: AsyncSession = Depends(get_session)) -> StyleOut:
    row = await session.get(CartoonStyle, style_id)
    if row is None or not row.enabled:
        raise HTTPException(status_code=404, detail="Style not found")
    return StyleOut.model_validate(row)


@router.get("/config", response_model=ConfigOut)
async def app_config() -> ConfigOut:
    return ConfigOut(
        api_version=1,
        min_app_version="1.0.0",
        features={"offlineOnly": True, "accounts": False, "cloudBackup": False, "payments": False},
    )


@router.post("/feedback", response_model=FeedbackOut, status_code=201)
async def create_feedback(body: FeedbackIn, session: AsyncSession = Depends(get_session)) -> FeedbackOut:
    row = Feedback(message=body.message, app_version=body.app_version, device=body.device)
    session.add(row)
    await session.commit()
    return FeedbackOut(id=row.id)


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings()
    logging.basicConfig(level=settings.log_level)

    @asynccontextmanager
    async def lifespan(app: FastAPI) -> AsyncIterator[None]:
        app.state.engine = make_engine(settings.database_url)
        app.state.session_factory = make_session_factory(app.state.engine)
        await _init_database(app, settings)
        yield
        await app.state.engine.dispose()

    app = FastAPI(title="Cam-Anime API", version="1.0.0", lifespan=lifespan)

    @app.get("/health")
    async def health(request: Request, response: Response) -> dict[str, str]:
        try:
            async with request.app.state.session_factory() as session:
                await session.execute(text("SELECT 1"))
            return {"status": "ok", "db": "ok"}
        except Exception:  # noqa: BLE001
            response.status_code = 503
            return {"status": "degraded", "db": "error"}

    app.include_router(router)
    return app


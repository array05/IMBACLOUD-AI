import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.config import get_settings
from app.gateway_client import gateway_loop
from app.routes import router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    task = None
    if settings.gateway_url:
        task = asyncio.create_task(gateway_loop(settings))
    yield
    if task:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass


app = FastAPI(title="Imbai Worker", version="0.5.2", lifespan=lifespan)
app.include_router(router)

import asyncio
import logging

import httpx

from app.config import Settings, get_settings

logger = logging.getLogger("imbai.worker.gateway")


async def register_with_gateway(settings: Settings | None = None) -> bool:
    settings = settings or get_settings()
    if not settings.gateway_url or not settings.worker_id:
        logger.warning("GATEWAY_URL or WORKER_ID not set — skipping registration")
        return False

    payload = {
        "worker_id": settings.worker_id,
        "url": settings.worker_public_url.rstrip("/"),
        "token": settings.worker_token,
        "workspace": settings.worker_workspace,
    }
    headers = {"Authorization": f"Bearer {settings.registration_token}"}

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                f"{settings.gateway_url.rstrip('/')}/v1/workers/register",
                json=payload,
                headers=headers,
            )
            response.raise_for_status()
            data = response.json()
            logger.info("Registered with gateway: worker_id=%s", data.get("worker_id"))
            return True
    except Exception as exc:
        logger.error("Gateway registration failed: %s", exc)
        return False


async def send_heartbeat(settings: Settings | None = None) -> bool:
    settings = settings or get_settings()
    if not settings.gateway_url or not settings.worker_id:
        return False

    payload = {"worker_id": settings.worker_id}
    headers = {"Authorization": f"Bearer {settings.worker_token}"}

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                f"{settings.gateway_url.rstrip('/')}/v1/workers/heartbeat",
                json=payload,
                headers=headers,
            )
            response.raise_for_status()
            return True
    except Exception as exc:
        logger.warning("Heartbeat failed: %s", exc)
        return False


async def gateway_loop(settings: Settings | None = None) -> None:
    settings = settings or get_settings()
    await register_with_gateway(settings)

    interval = max(10, settings.heartbeat_interval)
    while True:
        await asyncio.sleep(interval)
        ok = await send_heartbeat(settings)
        if not ok:
            await register_with_gateway(settings)

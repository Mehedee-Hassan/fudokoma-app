import asyncio
import logging
from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse
from sqlalchemy import text

router = APIRouter(tags=["health"])
logger = logging.getLogger(__name__)


async def check_mysql(engine) -> None:
    async with engine.connect() as connection:
        await connection.execute(text("SELECT 1"))


async def check_redis(client) -> None:
    await client.ping()


@router.get("/health")
async def health():
    return {"status": "ok"}


@router.get("/ready")
async def ready(request: Request):
    checks = {"startup": bool(getattr(request.app.state, "started", False)),
              "mysql": False, "redis": False}
    async def probe(name, operation):
        try:
            await asyncio.wait_for(operation, timeout=3)
            checks[name] = True
        except Exception:
            # Do not expose connection strings, credentials, or driver errors.
            logger.warning("Readiness dependency unavailable: %s", name)
    await asyncio.gather(
        probe("mysql", check_mysql(request.app.state.engine)),
        probe("redis", check_redis(request.app.state.redis)),
    )
    healthy = checks["startup"] and checks["mysql"]
    return JSONResponse({"status": "ok" if healthy else "not_ready", "checks": checks},
                        status_code=200 if healthy else 503)

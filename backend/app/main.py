from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware
from redis.asyncio import Redis
from app.core.config import Settings, get_settings
from app.core.logging import configure_logging
from app.db.session import create_database
from app.api.routes.health import router
from app.api.routes.carts import router as carts_router
from app.api.routes.users import router as users_router
from app.admin.routes import router as admin_router


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings.debug)

    @asynccontextmanager
    async def lifespan(application: FastAPI):
        application.state.started = False
        engine, session_factory = create_database(settings)
        application.state.engine = engine
        application.state.session_factory = session_factory
        application.state.redis = Redis.from_url(
            settings.redis_url, socket_connect_timeout=2, socket_timeout=2)
        application.state.started = True
        try:
            yield
        finally:
            application.state.started = False
            await application.state.redis.aclose()
            await engine.dispose()

    application = FastAPI(
        title=settings.app_name, debug=settings.debug, lifespan=lifespan,
        docs_url="/docs" if settings.docs_enabled else None,
        redoc_url="/redoc" if settings.docs_enabled else None,
        openapi_url="/openapi.json" if settings.docs_enabled else None,
    )
    application.state.settings = settings
    application.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.trusted_hosts)
    if settings.cors_origins or settings.app_env != "production":
        application.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins,
                                  allow_credentials=False, allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
                                  allow_headers=["Authorization", "Content-Type"],
                                  allow_origin_regex=(
                                      r"https?://(localhost|127\.0\.0\.1)(:\d+)?"
                                      if settings.app_env != "production"
                                      else None
                                  ))
    application.include_router(router, prefix=settings.api_v1_prefix)
    application.include_router(carts_router, prefix=settings.api_v1_prefix)
    application.include_router(users_router, prefix=settings.api_v1_prefix)
    application.include_router(admin_router)
    return application


app = create_app()

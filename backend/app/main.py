from contextlib import asynccontextmanager
import secrets
from pathlib import Path

import firebase_admin
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.sessions import SessionMiddleware
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
        application.state.firebase_app = None
        if settings.firebase_project_id:
            credential_path = Path(settings.firebase_credentials_path)
            if not credential_path.is_file():
                await engine.dispose()
                raise RuntimeError("Configured Firebase credentials file is unavailable")
            firebase_app = firebase_admin.initialize_app(
                firebase_admin.credentials.Certificate(str(credential_path)),
                options={"projectId": settings.firebase_project_id},
                name=f"fudokoma-{id(application)}",
            )
            application.state.firebase_app = firebase_app
        application.state.redis = Redis.from_url(
            settings.redis_url, socket_connect_timeout=2, socket_timeout=2)
        application.state.started = True
        try:
            yield
        finally:
            application.state.started = False
            await application.state.redis.aclose()
            await engine.dispose()
            if application.state.firebase_app is not None:
                firebase_admin.delete_app(application.state.firebase_app)

    application = FastAPI(
        title=settings.app_name, debug=settings.debug, lifespan=lifespan,
        docs_url="/docs" if settings.docs_enabled else None,
        redoc_url="/redoc" if settings.docs_enabled else None,
        openapi_url="/openapi.json" if settings.docs_enabled else None,
    )
    application.state.settings = settings
    application.add_middleware(
        SessionMiddleware,
        secret_key=settings.admin_session_secret or secrets.token_urlsafe(48),
        session_cookie="fudokoma_admin_session",
        max_age=8 * 60 * 60,
        same_site="lax",
        https_only=settings.app_env == "production",
    )
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

from collections.abc import AsyncIterator
from fastapi import HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession


async def get_session(request: Request) -> AsyncIterator[AsyncSession]:
    async with request.app.state.session_factory() as session:
        yield session


async def require_local_prototype(request: Request) -> None:
    if request.app.state.settings.app_env == "production":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Unauthenticated prototype API is disabled in production",
        )

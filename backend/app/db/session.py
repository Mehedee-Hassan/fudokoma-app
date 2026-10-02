from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from app.core.config import Settings


def create_database(settings: Settings):
    engine = create_async_engine(
        settings.sqlalchemy_url, pool_pre_ping=True, pool_recycle=1800,
        pool_size=settings.db_pool_size, max_overflow=settings.db_max_overflow,
        pool_timeout=5, connect_args={"connect_timeout": 5, "init_command": "SET time_zone = '+00:00'"},
    )
    return engine, async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

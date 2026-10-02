from datetime import datetime, timezone
from uuid import UUID, uuid4
from sqlalchemy import DateTime, MetaData, Uuid, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    metadata = MetaData(naming_convention={
        "ix": "ix_%(table_name)s_%(column_0_name)s",
        "uq": "uq_%(table_name)s_%(column_0_name)s",
        "ck": "ck_%(table_name)s_%(constraint_name)s",
        "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
        "pk": "pk_%(table_name)s",
    })


def utc_now() -> datetime:
    # MySQL DATETIME has no timezone. Store naive UTC consistently.
    return datetime.now(timezone.utc).replace(tzinfo=None)


class IdentityMixin:
    id: Mapped[UUID] = mapped_column(Uuid(native_uuid=False), primary_key=True, default=uuid4)


class CreatedMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utc_now, server_default=func.now())


class TimestampMixin(CreatedMixin):
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=utc_now, server_default=func.now(), onupdate=utc_now)

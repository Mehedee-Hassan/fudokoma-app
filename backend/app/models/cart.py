from uuid import UUID
from sqlalchemy import Boolean, CheckConstraint, Double, ForeignKey, Index, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base, IdentityMixin, TimestampMixin


class Cart(IdentityMixin, TimestampMixin, Base):
    __tablename__ = "carts"
    __table_args__ = (
        CheckConstraint("latitude BETWEEN -90 AND 90", name="latitude"),
        CheckConstraint("longitude BETWEEN -180 AND 180", name="longitude"),
        Index("ix_carts_location", "latitude", "longitude"),
    )
    owner_id: Mapped[UUID] = mapped_column(Uuid(native_uuid=False), ForeignKey("users.id", ondelete="RESTRICT"), index=True)
    name: Mapped[str] = mapped_column(String(200))
    description: Mapped[str] = mapped_column(Text, default="")
    category: Mapped[str] = mapped_column(String(100), index=True)
    is_open: Mapped[bool] = mapped_column(Boolean, default=False, server_default="0", index=True)
    latitude: Mapped[float] = mapped_column(Double)
    longitude: Mapped[float] = mapped_column(Double, index=True)
    schedule: Mapped[str] = mapped_column(Text)
    image_url: Mapped[str | None] = mapped_column(String(2048))

from uuid import UUID
from sqlalchemy import Boolean, ForeignKey, Index, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base, IdentityMixin, CreatedMixin


class Notification(IdentityMixin, CreatedMixin, Base):
    __tablename__ = "notifications"
    __table_args__ = (Index("ix_notifications_user_created", "user_id", "created_at"),)
    user_id: Mapped[UUID] = mapped_column(Uuid(native_uuid=False), ForeignKey("users.id", ondelete="CASCADE"))
    cart_id: Mapped[UUID | None] = mapped_column(Uuid(native_uuid=False), ForeignKey("carts.id", ondelete="SET NULL"), index=True)
    type: Mapped[str] = mapped_column(String(50))
    title: Mapped[str] = mapped_column(String(200))
    message: Mapped[str] = mapped_column(Text)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, server_default="0")

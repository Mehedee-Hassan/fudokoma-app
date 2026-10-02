from uuid import UUID
from sqlalchemy import Boolean, ForeignKey, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base, IdentityMixin, CreatedMixin


class Follow(IdentityMixin, CreatedMixin, Base):
    __tablename__ = "follows"
    __table_args__ = (UniqueConstraint("user_id", "cart_id", name="uq_follows_user_cart"),)
    user_id: Mapped[UUID] = mapped_column(Uuid(native_uuid=False), ForeignKey("users.id", ondelete="CASCADE"))
    cart_id: Mapped[UUID] = mapped_column(Uuid(native_uuid=False), ForeignKey("carts.id", ondelete="CASCADE"), index=True)
    notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True, server_default="1")

from sqlalchemy import CheckConstraint, String, Boolean
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base, IdentityMixin, TimestampMixin


class User(IdentityMixin, TimestampMixin, Base):
    __tablename__ = "users"
    __table_args__ = (CheckConstraint("role IN ('customer', 'owner', 'admin')", name="role"),)
    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    email: Mapped[str | None] = mapped_column(String(320), index=True)
    name: Mapped[str] = mapped_column(String(200))
    role: Mapped[str] = mapped_column(String(20), default="customer", server_default="customer")
    is_blocked: Mapped[bool] = mapped_column(Boolean, default=False, server_default="0")

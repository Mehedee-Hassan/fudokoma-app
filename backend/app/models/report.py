from uuid import UUID
from sqlalchemy import CheckConstraint, ForeignKey, Index, String, Text, Uuid
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base, IdentityMixin, CreatedMixin


class Report(IdentityMixin, CreatedMixin, Base):
    __tablename__ = "reports"
    __table_args__ = (
        CheckConstraint("target_type IN ('user', 'cart')", name="target_type"),
        CheckConstraint("status IN ('open', 'reviewing', 'resolved', 'dismissed')", name="status"),
        Index("ix_reports_status_created", "status", "created_at"),
        Index("ix_reports_target", "target_type", "target_id"),
    )
    reporter_id: Mapped[UUID] = mapped_column(Uuid(native_uuid=False), ForeignKey("users.id", ondelete="RESTRICT"), index=True)
    target_type: Mapped[str] = mapped_column(String(20))
    target_id: Mapped[UUID] = mapped_column(Uuid(native_uuid=False))
    reason: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(20), default="open", server_default="open")

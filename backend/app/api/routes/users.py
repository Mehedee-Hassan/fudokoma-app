from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_session, require_local_prototype
from app.models.cart import Cart
from app.models.follow import Follow
from app.models.notification import Notification
from app.models.user import User

router = APIRouter(
    prefix="/users",
    tags=["users"],
    dependencies=[Depends(require_local_prototype)],
)


class UserCreate(BaseModel):
    firebase_uid: str = Field(min_length=1, max_length=128)
    name: str = Field(min_length=1, max_length=200)
    email: str | None = Field(default=None, max_length=320)
    role: str = Field(default="customer", pattern="^(customer|owner|admin)$")


class UserUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=200)
    email: str | None = Field(default=None, max_length=320)
    role: str | None = Field(default=None, pattern="^(customer|owner|admin)$")
    is_blocked: bool | None = None

    @model_validator(mode="after")
    def reject_null_required_fields(self):
        for field in ("name", "role", "is_blocked"):
            if field in self.model_fields_set and getattr(self, field) is None:
                raise ValueError(f"{field} cannot be null")
        return self


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    firebase_uid: str
    email: str | None
    name: str
    role: str
    is_blocked: bool
    created_at: datetime


class FollowRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    cart_id: UUID
    notifications_enabled: bool
    created_at: datetime


class NotificationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    cart_id: UUID | None
    type: str
    title: str
    message: str
    is_read: bool
    created_at: datetime


class FollowUpdate(BaseModel):
    notifications_enabled: bool = True


@router.get("", response_model=list[UserRead])
async def list_users(session: AsyncSession = Depends(get_session)):
    result = await session.execute(select(User).order_by(User.created_at.desc()))
    return result.scalars().all()


@router.get("/{user_id}", response_model=UserRead)
async def get_user(user_id: UUID, session: AsyncSession = Depends(get_session)):
    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


@router.post("", response_model=UserRead, status_code=status.HTTP_201_CREATED)
async def create_user(payload: UserCreate, session: AsyncSession = Depends(get_session)):
    existing = await session.scalar(
        select(User).where(User.firebase_uid == payload.firebase_uid)
    )
    if existing is not None:
        existing.name = payload.name
        existing.email = payload.email
        await session.commit()
        await session.refresh(existing)
        return existing
    user = User(**payload.model_dump())
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


@router.patch("/{user_id}", response_model=UserRead)
async def update_user(
    user_id: UUID,
    payload: UserUpdate,
    session: AsyncSession = Depends(get_session),
):
    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    await session.commit()
    await session.refresh(user)
    return user


@router.get("/{user_id}/follows", response_model=list[FollowRead])
async def list_follows(user_id: UUID, session: AsyncSession = Depends(get_session)):
    result = await session.execute(
        select(Follow)
        .where(Follow.user_id == user_id)
        .order_by(Follow.created_at.desc())
    )
    return result.scalars().all()


@router.put("/{user_id}/follows/{cart_id}", response_model=FollowRead)
async def follow_cart(
    user_id: UUID,
    cart_id: UUID,
    payload: FollowUpdate = FollowUpdate(),
    session: AsyncSession = Depends(get_session),
):
    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    cart = await session.get(Cart, cart_id)
    if cart is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cart not found")
    follow = await session.scalar(
        select(Follow).where(Follow.user_id == user_id, Follow.cart_id == cart_id)
    )
    if follow is None:
        follow = Follow(
            user_id=user_id,
            cart_id=cart_id,
            notifications_enabled=payload.notifications_enabled,
        )
        session.add(follow)
    else:
        follow.notifications_enabled = payload.notifications_enabled
    await session.commit()
    await session.refresh(follow)
    return follow


@router.delete("/{user_id}/follows/{cart_id}", status_code=status.HTTP_204_NO_CONTENT)
async def unfollow_cart(
    user_id: UUID,
    cart_id: UUID,
    session: AsyncSession = Depends(get_session),
):
    follow = await session.scalar(
        select(Follow).where(Follow.user_id == user_id, Follow.cart_id == cart_id)
    )
    if follow is not None:
        await session.delete(follow)
        await session.commit()


@router.get("/{user_id}/notifications", response_model=list[NotificationRead])
async def list_notifications(
    user_id: UUID,
    session: AsyncSession = Depends(get_session),
):
    result = await session.execute(
        select(Notification)
        .where(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc())
    )
    return result.scalars().all()

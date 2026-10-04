from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_session, require_admin
from app.models.cart import Cart
from app.models.follow import Follow
from app.models.notification import Notification
from app.models.user import User

router = APIRouter(
    prefix="/users",
    tags=["users"],
)


class ProfileUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=200)
    @model_validator(mode="after")
    def reject_null_name(self):
        if "name" in self.model_fields_set and self.name is None:
            raise ValueError("name cannot be null")
        return self


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


@router.get("/me", response_model=UserRead)
async def get_me(user: User = Depends(get_current_user)):
    return user


@router.patch("/me", response_model=UserRead)
async def update_me(
    payload: ProfileUpdate,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    if "name" in payload.model_fields_set:
        user.name = payload.name
    await session.commit()
    await session.refresh(user)
    return user


@router.get("", response_model=list[UserRead], dependencies=[Depends(require_admin)])
async def list_users(session: AsyncSession = Depends(get_session)):
    result = await session.execute(select(User).order_by(User.created_at.desc()))
    return result.scalars().all()


@router.get("/{user_id}", response_model=UserRead)
async def get_user(
    user_id: UUID,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    if user.id != user_id and user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You may only view your own account",
        )
    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


@router.patch("/{user_id}", response_model=UserRead)
async def update_user(
    user_id: UUID,
    payload: UserUpdate,
    current_admin: User = Depends(require_admin),
    session: AsyncSession = Depends(get_session),
):
    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    changes = payload.model_dump(exclude_unset=True)
    removes_admin_access = user.role == "admin" and (
        changes.get("role", "admin") != "admin"
        or changes.get("is_blocked", user.is_blocked)
    )
    if removes_admin_access:
        if user.id == current_admin.id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="You cannot remove your own admin access",
            )
        active_admin_count = await session.scalar(
            select(func.count())
            .select_from(User)
            .where(User.role == "admin", User.is_blocked.is_(False))
        )
        if active_admin_count <= 1:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="The last active admin cannot be demoted or blocked",
            )
    for field, value in changes.items():
        setattr(user, field, value)
    await session.commit()
    await session.refresh(user)
    return user


@router.get("/{user_id}/follows", response_model=list[FollowRead])
async def list_follows(
    user_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    if current_user.id != user_id and current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You may only view your own follows",
        )
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
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    if current_user.id != user_id and current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You may only manage your own follows",
        )
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
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    if current_user.id != user_id and current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You may only manage your own follows",
        )
    follow = await session.scalar(
        select(Follow).where(Follow.user_id == user_id, Follow.cart_id == cart_id)
    )
    if follow is not None:
        await session.delete(follow)
        await session.commit()


@router.get("/{user_id}/notifications", response_model=list[NotificationRead])
async def list_notifications(
    user_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    if current_user.id != user_id and current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You may only view your own notifications",
        )
    result = await session.execute(
        select(Notification)
        .where(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc())
    )
    return result.scalars().all()

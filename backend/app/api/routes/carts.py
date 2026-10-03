from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_session
from app.models.cart import Cart
from app.models.follow import Follow
from app.models.user import User

router = APIRouter(prefix="/carts", tags=["carts"])


class CartCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=200)
    description: str = ""
    category: str = Field(min_length=1, max_length=100)
    is_open: bool = False
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    schedule: str
    image_url: str | None = Field(default=None, max_length=2048)


class CartUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    category: str | None = Field(default=None, min_length=1, max_length=100)
    is_open: bool | None = None
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    schedule: str | None = None
    image_url: str | None = Field(default=None, max_length=2048)

    @model_validator(mode="after")
    def reject_null_required_fields(self):
        for field in ("name", "category", "is_open", "latitude", "longitude", "schedule"):
            if field in self.model_fields_set and getattr(self, field) is None:
                raise ValueError(f"{field} cannot be null")
        return self


class CartRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    owner_id: UUID
    name: str
    description: str
    category: str
    is_open: bool
    latitude: float
    longitude: float
    schedule: str
    image_url: str | None
    updated_at: datetime
    followers_count: int = 0


@router.get("", response_model=list[CartRead])
async def list_carts(session: AsyncSession = Depends(get_session)):
    result = await session.execute(
        select(Cart, func.count(Follow.id).label("followers_count"))
        .outerjoin(Follow, Follow.cart_id == Cart.id)
        .group_by(Cart.id)
        .order_by(Cart.updated_at.desc())
    )
    return [
        CartRead.model_validate(cart).model_copy(
            update={"followers_count": followers_count}
        )
        for cart, followers_count in result.all()
    ]


@router.post(
    "",
    response_model=CartRead,
    status_code=status.HTTP_201_CREATED,
)
async def create_cart(
    payload: CartCreate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    if current_user.role not in {"owner", "admin"}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cart owner role required",
        )
    cart = Cart(owner_id=current_user.id, **payload.model_dump())
    session.add(cart)
    await session.commit()
    await session.refresh(cart)
    return cart


@router.patch(
    "/{cart_id}",
    response_model=CartRead,
)
async def update_cart(
    cart_id: UUID,
    payload: CartUpdate,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    cart = await session.get(Cart, cart_id)
    if cart is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cart not found")
    if cart.owner_id != current_user.id and current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You may only update your own carts",
        )
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(cart, field, value)
    await session.commit()
    await session.refresh(cart)
    return cart

from datetime import datetime
import math
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_session
from app.models.cart import Cart
from app.models.follow import Follow
from app.models.user import User

router = APIRouter(prefix="/carts", tags=["carts"])
EARTH_RADIUS_KM = 6371.0


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


def _distance_km(
    latitude: float,
    longitude: float,
    cart_latitude: float,
    cart_longitude: float,
) -> float:
    latitude_delta = math.radians(cart_latitude - latitude)
    longitude_delta = math.radians(cart_longitude - longitude)
    haversine = (
        math.sin(latitude_delta / 2) ** 2
        + math.cos(math.radians(latitude))
        * math.cos(math.radians(cart_latitude))
        * math.sin(longitude_delta / 2) ** 2
    )
    return 2 * EARTH_RADIUS_KM * math.asin(min(1.0, math.sqrt(haversine)))


@router.get("", response_model=list[CartRead])
async def list_carts(
    latitude: float | None = Query(default=None, ge=-90, le=90),
    longitude: float | None = Query(default=None, ge=-180, le=180),
    radius_km: float = Query(default=5.0, gt=0, le=50),
    session: AsyncSession = Depends(get_session),
):
    if (latitude is None) != (longitude is None):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="latitude and longitude must be provided together",
        )

    query = (
        select(Cart, func.count(Follow.id).label("followers_count"))
        .outerjoin(Follow, Follow.cart_id == Cart.id)
        .group_by(Cart.id)
    )

    if latitude is not None and longitude is not None:
        latitude_delta = radius_km / 111.195
        min_latitude = max(-90.0, latitude - latitude_delta)
        max_latitude = min(90.0, latitude + latitude_delta)
        query = query.where(Cart.latitude.between(min_latitude, max_latitude))

        max_abs_latitude = min(90.0, abs(latitude) + latitude_delta)
        longitude_scale = math.cos(math.radians(max_abs_latitude))
        if abs(longitude_scale) > 1e-12:
            longitude_delta = min(180.0, radius_km / (111.195 * abs(longitude_scale)))
            min_longitude = longitude - longitude_delta
            max_longitude = longitude + longitude_delta
            if min_longitude < -180:
                query = query.where(
                    or_(Cart.longitude >= min_longitude + 360, Cart.longitude <= max_longitude)
                )
            elif max_longitude > 180:
                query = query.where(
                    or_(Cart.longitude >= min_longitude, Cart.longitude <= max_longitude - 360)
                )
            else:
                query = query.where(
                    Cart.longitude.between(min_longitude, max_longitude)
                )

    result = await session.execute(query.order_by(Cart.updated_at.desc()))
    rows = result.all()
    if latitude is None or longitude is None:
        return [
            CartRead.model_validate(cart).model_copy(
                update={"followers_count": followers_count}
            )
            for cart, followers_count in rows
        ]

    nearby = [
        (
            _distance_km(latitude, longitude, cart.latitude, cart.longitude),
            CartRead.model_validate(cart).model_copy(
                update={"followers_count": followers_count}
            ),
        )
        for cart, followers_count in rows
    ]
    return [
        cart
        for distance, cart in sorted(nearby, key=lambda entry: entry[0])
        if distance <= radius_km
    ]


@router.get("/mine", response_model=list[CartRead])
async def list_my_carts(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    if current_user.role not in {"owner", "admin"}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cart owner role required",
        )
    result = await session.execute(
        select(Cart, func.count(Follow.id).label("followers_count"))
        .outerjoin(Follow, Follow.cart_id == Cart.id)
        .where(Cart.owner_id == current_user.id)
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

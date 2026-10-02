from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_session, require_local_prototype
from app.models.cart import Cart
from app.models.user import User

router = APIRouter(
    prefix="/admin",
    tags=["admin dashboard"],
    dependencies=[Depends(require_local_prototype)],
)
templates = Jinja2Templates(
    directory=str(Path(__file__).resolve().parents[1] / "templates")
)


@router.get("")
async def dashboard(request: Request, session: AsyncSession = Depends(get_session)):
    users_result = await session.execute(
        select(User).order_by(User.created_at.desc())
    )
    carts_result = await session.execute(
        select(Cart).order_by(Cart.updated_at.desc())
    )
    users = users_result.scalars().all()
    carts = carts_result.scalars().all()
    return templates.TemplateResponse(
        request=request,
        name="admin/dashboard.html",
        context={
            "users": users,
            "carts": carts,
            "user_count": len(users),
            "cart_count": len(carts),
            "blocked_count": sum(user.is_blocked for user in users),
        },
    )


@router.post("/users/{user_id}/block")
async def set_user_blocked(
    user_id: UUID,
    blocked: bool,
    session: AsyncSession = Depends(get_session),
):
    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    user.is_blocked = blocked
    await session.commit()
    return RedirectResponse(
        url="/admin",
        status_code=status.HTTP_303_SEE_OTHER,
    )

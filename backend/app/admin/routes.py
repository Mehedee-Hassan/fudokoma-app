import hmac
import secrets
from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Depends, Form, HTTPException, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_session, require_local_prototype
from app.core.config import Settings
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


def credentials_configured(settings: Settings) -> bool:
    return (
        bool(settings.admin_username)
        and settings.admin_password is not None
        and len(settings.admin_session_secret) >= 32
    )


def verify_token(submitted: str, expected: str) -> bool:
    return hmac.compare_digest(submitted.encode("utf-8"), expected.encode("utf-8"))


def verify_csrf(request: Request, csrf_token: str) -> None:
    expected = request.session.get("csrf_token")
    if not isinstance(expected, str) or not verify_token(csrf_token, expected):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid CSRF token",
        )


async def require_admin(request: Request) -> None:
    if not request.session.get("admin_authenticated"):
        raise HTTPException(
            status_code=status.HTTP_303_SEE_OTHER,
            headers={"Location": "/admin/login"},
        )


@router.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    if "csrf_token" not in request.session:
        request.session["csrf_token"] = secrets.token_urlsafe(32)
    settings = request.app.state.settings
    return templates.TemplateResponse(
        request=request,
        name="admin/login.html",
        context={
            "csrf_token": request.session["csrf_token"],
            "login_enabled": credentials_configured(settings),
            "error": None,
        },
    )


@router.post("/login", response_class=HTMLResponse)
async def login(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    csrf_token: str = Form(...),
):
    verify_csrf(request, csrf_token)
    settings: Settings = request.app.state.settings
    if not credentials_configured(settings):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin login is not configured",
        )

    configured_password = settings.admin_password.get_secret_value()
    if not (
        verify_token(username, settings.admin_username)
        and verify_token(password, configured_password)
    ):
        return templates.TemplateResponse(
            request=request,
            name="admin/login.html",
            context={
                "csrf_token": csrf_token,
                "login_enabled": True,
                "error": "The username or password is incorrect.",
            },
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    request.session.clear()
    request.session["admin_authenticated"] = True
    request.session["csrf_token"] = secrets.token_urlsafe(32)
    return RedirectResponse(
        url="/admin",
        status_code=status.HTTP_303_SEE_OTHER,
    )


@router.post("/logout")
async def logout(
    request: Request,
    csrf_token: str = Form(...),
    _: None = Depends(require_admin),
):
    verify_csrf(request, csrf_token)
    request.session.clear()
    return RedirectResponse(
        url="/admin/login",
        status_code=status.HTTP_303_SEE_OTHER,
    )


@router.get("", dependencies=[Depends(require_admin)])
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
            "csrf_token": request.session["csrf_token"],
        },
    )


@router.post("/users/{user_id}/block", dependencies=[Depends(require_admin)])
async def set_user_blocked(
    user_id: UUID,
    request: Request,
    blocked: bool,
    csrf_token: str = Form(...),
    session: AsyncSession = Depends(get_session),
):
    verify_csrf(request, csrf_token)
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

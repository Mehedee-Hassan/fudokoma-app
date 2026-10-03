import hmac
import secrets
from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Depends, Form, HTTPException, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse, Response
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_session, verify_firebase_id_token
from app.core.config import Settings
from app.models.cart import Cart
from app.models.user import User

router = APIRouter(prefix="/admin", tags=["admin dashboard"])
templates = Jinja2Templates(
    directory=str(Path(__file__).resolve().parents[1] / "templates")
)


class FirebaseAdminSession(BaseModel):
    id_token: str = Field(min_length=1, max_length=8192)
    csrf_token: str = Field(min_length=1, max_length=128)


def credentials_configured(settings: Settings) -> bool:
    return (
        bool(settings.admin_username)
        and settings.admin_password is not None
        and len(settings.admin_session_secret) >= 32
    )


def firebase_web_configured(settings: Settings) -> bool:
    return bool(
        settings.firebase_web_api_key
        and settings.firebase_auth_domain
        and settings.firebase_web_app_id
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


async def require_dashboard_admin(
    request: Request,
    session: AsyncSession = Depends(get_session),
) -> User | None:
    if not request.session.get("admin_authenticated"):
        raise HTTPException(
            status_code=status.HTTP_303_SEE_OTHER,
            headers={"Location": "/admin/login"},
        )

    firebase_uid = request.session.get("admin_firebase_uid")
    if firebase_uid is None:
        if request.app.state.settings.app_env == "production":
            if (
                request.session.get("admin_auth_method") == "password"
                and credentials_configured(request.app.state.settings)
            ):
                return None
            request.session.clear()
            raise HTTPException(
                status_code=status.HTTP_303_SEE_OTHER,
                headers={"Location": "/admin/login"},
            )
        return None

    user = await session.scalar(
        select(User).where(User.firebase_uid == firebase_uid)
    )
    if user is None or user.role != "admin" or user.is_blocked:
        request.session.clear()
        raise HTTPException(
            status_code=status.HTTP_303_SEE_OTHER,
            headers={"Location": "/admin/login"},
        )
    return user


@router.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    if "csrf_token" not in request.session:
        request.session["csrf_token"] = secrets.token_urlsafe(32)
    settings: Settings = request.app.state.settings
    firebase_config = None
    if firebase_web_configured(settings):
        firebase_config = {
            "apiKey": settings.firebase_web_api_key,
            "authDomain": settings.firebase_auth_domain,
            "projectId": settings.firebase_project_id,
            "appId": settings.firebase_web_app_id,
        }
    return templates.TemplateResponse(
        request=request,
        name="admin/login.html",
        context={
            "csrf_token": request.session["csrf_token"],
            "login_enabled": credentials_configured(settings),
            "firebase_login_enabled": firebase_config is not None,
            "firebase_config": firebase_config,
            "error": None,
        },
    )


@router.post("/login", response_class=HTMLResponse)
async def local_login(
    request: Request,
    username: str = Form(...),
    password: str = Form(...),
    csrf_token: str = Form(...),
):
    verify_csrf(request, csrf_token)
    settings: Settings = request.app.state.settings
    if not credentials_configured(settings):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Username and password admin login is not configured",
        )

    configured_password = settings.admin_password.get_secret_value()
    if not (
        verify_token(username, settings.admin_username)
        and verify_token(password, configured_password)
    ):
        firebase_config = None
        if firebase_web_configured(settings):
            firebase_config = {
                "apiKey": settings.firebase_web_api_key,
                "authDomain": settings.firebase_auth_domain,
                "projectId": settings.firebase_project_id,
                "appId": settings.firebase_web_app_id,
            }
        return templates.TemplateResponse(
            request=request,
            name="admin/login.html",
            context={
                "csrf_token": csrf_token,
                "login_enabled": credentials_configured(settings),
                "firebase_login_enabled": firebase_config is not None,
                "firebase_config": firebase_config,
                "error": "The username or password is incorrect.",
            },
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    request.session.clear()
    request.session["admin_authenticated"] = True
    request.session["admin_auth_method"] = "password"
    request.session["csrf_token"] = secrets.token_urlsafe(32)
    return RedirectResponse(
        url="/admin",
        status_code=status.HTTP_303_SEE_OTHER,
    )


@router.post("/session", status_code=status.HTTP_204_NO_CONTENT)
async def create_firebase_admin_session(
    payload: FirebaseAdminSession,
    request: Request,
    session: AsyncSession = Depends(get_session),
):
    verify_csrf(request, payload.csrf_token)
    claims = await verify_firebase_id_token(request, payload.id_token)
    firebase_uid = claims.get("uid")
    if (
        not isinstance(firebase_uid, str)
        or not firebase_uid
        or claims.get("email_verified") is not True
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="A verified Firebase account is required",
        )

    user = await session.scalar(
        select(User).where(User.firebase_uid == firebase_uid)
    )
    if user is None or user.role != "admin" or user.is_blocked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="An active admin account is required",
        )

    request.session.clear()
    request.session["admin_authenticated"] = True
    request.session["admin_auth_method"] = "firebase"
    request.session["admin_firebase_uid"] = firebase_uid
    request.session["csrf_token"] = secrets.token_urlsafe(32)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/logout")
async def logout(
    request: Request,
    csrf_token: str = Form(...),
    _: User | None = Depends(require_dashboard_admin),
):
    verify_csrf(request, csrf_token)
    request.session.clear()
    return RedirectResponse(
        url="/admin/login",
        status_code=status.HTTP_303_SEE_OTHER,
    )


@router.get("", dependencies=[Depends(require_dashboard_admin)])
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


@router.post(
    "/users/{user_id}/block",
    dependencies=[Depends(require_dashboard_admin)],
)
async def set_user_blocked(
    user_id: UUID,
    request: Request,
    blocked: bool,
    csrf_token: str = Form(...),
    admin_user: User | None = Depends(require_dashboard_admin),
    session: AsyncSession = Depends(get_session),
):
    verify_csrf(request, csrf_token)
    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    if blocked and admin_user is not None and user.id == admin_user.id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You cannot block your own admin account",
        )
    if blocked and user.role == "admin":
        active_admin_count = await session.scalar(
            select(func.count())
            .select_from(User)
            .where(User.role == "admin", User.is_blocked.is_(False))
        )
        if active_admin_count <= 1:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="The last active admin cannot be blocked",
            )
    user.is_blocked = blocked
    await session.commit()
    return RedirectResponse(
        url="/admin",
        status_code=status.HTTP_303_SEE_OTHER,
    )

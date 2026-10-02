import asyncio
from collections.abc import AsyncIterator
from typing import Annotated, Any

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth
from firebase_admin.exceptions import FirebaseError
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User

bearer_scheme = HTTPBearer(auto_error=False)


async def get_session(request: Request) -> AsyncIterator[AsyncSession]:
    async with request.app.state.session_factory() as session:
        yield session


async def verify_firebase_id_token(
    request: Request,
    token: str,
) -> dict[str, Any]:
    firebase_app = getattr(request.app.state, "firebase_app", None)
    if firebase_app is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase authentication is not configured",
        )

    try:
        return await asyncio.to_thread(
            auth.verify_id_token,
            token,
            app=firebase_app,
            check_revoked=True,
        )
    except (
        auth.InvalidIdTokenError,
        auth.ExpiredIdTokenError,
        auth.RevokedIdTokenError,
        auth.UserDisabledError,
    ) as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase ID token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from error
    except auth.CertificateFetchError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase token verification is temporarily unavailable",
        ) from error
    except FirebaseError as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase token verification is temporarily unavailable",
        ) from error


async def get_current_user(
    request: Request,
    credentials: Annotated[
        HTTPAuthorizationCredentials | None,
        Depends(bearer_scheme),
    ],
    session: AsyncSession = Depends(get_session),
) -> User:
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="A Firebase ID token is required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    claims = await verify_firebase_id_token(request, credentials.credentials)

    firebase_uid = claims.get("uid")
    if not isinstance(firebase_uid, str) or not firebase_uid or len(firebase_uid) > 128:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Firebase ID token has no user identifier",
        )
    if claims.get("email") and claims.get("email_verified") is not True:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Verify your email before using this account",
        )

    user = await session.scalar(
        select(User).where(User.firebase_uid == firebase_uid)
    )
    name_claim = claims.get("name")
    email_claim = claims.get("email")
    name = (
        name_claim.strip()
        if isinstance(name_claim, str) and name_claim.strip()
        else email_claim.split("@", 1)[0]
        if isinstance(email_claim, str) and email_claim
        else "Follo Cart user"
    )
    email = email_claim if isinstance(email_claim, str) else None

    if user is None:
        user = User(
            firebase_uid=firebase_uid,
            name=name[:200],
            email=email,
        )
        session.add(user)
        try:
            await session.commit()
            await session.refresh(user)
        except IntegrityError:
            await session.rollback()
            user = await session.scalar(
                select(User).where(User.firebase_uid == firebase_uid)
            )
            if user is None:
                raise
    else:
        changed = False
        if email is not None:
            if user.email != email:
                user.email = email
                changed = True
        if name and user.name != name[:200]:
            user.name = name[:200]
            changed = True
        if changed:
            await session.commit()

    if user.is_blocked:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account is blocked",
        )
    return user


async def require_admin(
    user: Annotated[User, Depends(get_current_user)],
) -> User:
    if user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin role required",
        )
    return user

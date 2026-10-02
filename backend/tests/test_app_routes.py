from datetime import datetime
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.api.deps import get_session
from app.api.routes.carts import CartUpdate
from app.api.routes.users import UserUpdate
from app.core.config import Settings
from app.main import create_app


class FakeResult:
    def __init__(self, values):
        self._values = values

    def scalars(self):
        return self

    def all(self):
        return self._values


class FakeSession:
    def __init__(self):
        self.user = SimpleNamespace(
            id=uuid4(),
            name="<script>alert(1)</script>",
            firebase_uid="local-test-user",
            email="test@example.com",
            role="customer",
            is_blocked=False,
            created_at=datetime(2026, 10, 2),
        )
        self.cart = SimpleNamespace(
            id=uuid4(),
            name="Inage Eats",
            description="Near the station",
            category="Street food",
            owner_id=uuid4(),
            is_open=True,
            latitude=35.6327,
            longitude=140.0908,
            schedule="11 AM - 8 PM",
            updated_at=datetime(2026, 10, 2),
        )

    async def execute(self, statement):
        entity = statement.column_descriptions[0]["entity"]
        return FakeResult([self.user] if entity.__name__ == "User" else [self.cart])

    async def get(self, model, user_id):
        return self.user if user_id == self.user.id else None

    async def commit(self):
        return None


def test_unauthenticated_prototype_routes_are_disabled_in_production():
    settings = Settings(
        _env_file=None,
        app_env="production",
        admin_session_secret="s" * 40,
        mysql_password="test",
        trusted_hosts=["testserver"],
    )
    with TestClient(create_app(settings)) as client:
        assert client.get("/api/v1/carts").status_code == 403
        assert client.get("/api/v1/users").status_code == 403
        assert client.post(
            "/api/v1/users",
            json={"firebase_uid": "uid", "name": "Test user"},
        ).status_code == 403
        assert client.get("/admin").status_code == 403
        assert client.post(
            f"/admin/users/{uuid4()}/block?blocked=true"
        ).status_code == 403


def test_local_admin_dashboard_lists_users_and_carts():
    app = create_app(Settings(_env_file=None))
    fake_session = FakeSession()

    async def override_session():
        yield fake_session

    app.dependency_overrides[get_session] = override_session
    try:
        with TestClient(app) as client:
            response = client.get("/admin")
            assert response.status_code == 200
            assert "Admin dashboard" in response.text
            assert "Inage Eats" in response.text
            assert "35.6327, 140.0908" in response.text
            assert "&lt;script&gt;" in response.text
            assert "<script>alert(1)</script>" not in response.text

            blocked = client.post(
                f"/admin/users/{fake_session.user.id}/block?blocked=true",
                follow_redirects=False,
            )
            assert blocked.status_code == 303
            assert fake_session.user.is_blocked is True
            missing_user = client.post(
                f"/admin/users/{uuid4()}/block?blocked=true",
            )
            assert missing_user.status_code == 404
    finally:
        app.dependency_overrides.clear()


def test_local_cors_allows_follow_put_requests():
    with TestClient(create_app(Settings(_env_file=None))) as client:
        response = client.options(
            "/api/v1/users/user-id/follows/cart-id",
            headers={
                "Origin": "http://localhost:8080",
                "Access-Control-Request-Method": "PUT",
                "Access-Control-Request-Headers": "content-type",
            },
        )

    assert response.status_code == 200
    assert "PUT" in response.headers["access-control-allow-methods"]


@pytest.mark.parametrize(
    "payload",
    [{"name": None}, {"is_open": None}, {"latitude": None}],
)
def test_cart_update_rejects_null_for_required_fields(payload):
    with pytest.raises(ValidationError):
        CartUpdate.model_validate(payload)


@pytest.mark.parametrize(
    "payload",
    [{"name": None}, {"role": None}, {"is_blocked": None}],
)
def test_user_update_rejects_null_for_required_fields(payload):
    with pytest.raises(ValidationError):
        UserUpdate.model_validate(payload)

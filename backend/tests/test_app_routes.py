import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from app.api.routes.carts import CartUpdate
from app.api.routes.users import UserUpdate
from app.core.config import Settings
from app.main import create_app


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

from unittest.mock import AsyncMock
from fastapi.testclient import TestClient
from app.main import create_app
from app.core.config import Settings


def client():
    return TestClient(create_app(Settings(_env_file=None)))


def test_health():
    with client() as api:
        response = api.get("/api/v1/health")
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}


def test_ready_success(monkeypatch):
    monkeypatch.setattr("app.api.routes.health.check_mysql", AsyncMock())
    monkeypatch.setattr("app.api.routes.health.check_redis", AsyncMock())
    with client() as api:
        response = api.get("/api/v1/ready")
        assert response.status_code == 200
        assert response.json()["checks"] == {"startup": True, "mysql": True, "redis": True}


def test_ready_mysql_failure(monkeypatch):
    monkeypatch.setattr("app.api.routes.health.check_mysql", AsyncMock(side_effect=OSError("secret")))
    monkeypatch.setattr("app.api.routes.health.check_redis", AsyncMock())
    with client() as api:
        response = api.get("/api/v1/ready")
        assert response.status_code == 503
        assert response.json()["checks"]["mysql"] is False
        assert "secret" not in response.text


def test_redis_optional(monkeypatch):
    monkeypatch.setattr("app.api.routes.health.check_mysql", AsyncMock())
    monkeypatch.setattr("app.api.routes.health.check_redis", AsyncMock(side_effect=OSError()))
    with client() as api:
        response = api.get("/api/v1/ready")
        assert response.status_code == 200
        assert response.json()["checks"]["redis"] is False


def test_startup_required(monkeypatch):
    monkeypatch.setattr("app.api.routes.health.check_mysql", AsyncMock())
    monkeypatch.setattr("app.api.routes.health.check_redis", AsyncMock())
    with client() as api:
        api.app.state.started = False
        assert api.get("/api/v1/ready").status_code == 503


def test_untrusted_host():
    with client() as api:
        assert api.get("/api/v1/health", headers={"host": "evil.example"}).status_code == 400

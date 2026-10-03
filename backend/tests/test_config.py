import pytest
from pydantic import ValidationError
from app.core.config import Settings


def test_mysql_password_is_escaped():
    settings = Settings(_env_file=None, mysql_password="p@ss:/word")
    assert settings.sqlalchemy_url.password == "p@ss:/word"
    assert settings.sqlalchemy_url.drivername == "mysql+asyncmy"


def test_empty_admin_password_disables_dashboard_login():
    settings = Settings(
        _env_file=None,
        admin_username="",
        admin_password="",
    )
    assert settings.admin_password is None


def test_production_configuration_requires_firebase_credentials():
    with pytest.raises(ValidationError, match="FIREBASE_PROJECT_ID"):
        Settings(
            _env_file=None,
            app_env="production",
            admin_session_secret="s" * 40,
            mysql_password="test",
            trusted_hosts=["testserver"],
        )


def test_production_rejects_example_placeholders():
    with pytest.raises(ValidationError, match="placeholder"):
        Settings(
            _env_file=None,
            app_env="production",
            admin_session_secret="REPLACE_WITH_AT_LEAST_32_RANDOM_CHARACTERS",
            mysql_password="database-password",
            firebase_project_id="project-id",
            firebase_credentials_path="/run/secrets/firebase.json",
            firebase_web_api_key="api-key",
            firebase_auth_domain="project.firebaseapp.com",
            firebase_web_app_id="app-id",
            trusted_hosts=["app.example.com"],
        )


def test_production_manual_admin_password_must_be_strong():
    with pytest.raises(ValidationError, match="at least 20 characters"):
        Settings(
            _env_file=None,
            app_env="production",
            admin_session_secret="s" * 40,
            admin_username="admin",
            admin_password="weak-password",
            mysql_password="database-password",
            firebase_project_id="project-id",
            firebase_credentials_path="/run/secrets/firebase.json",
            firebase_web_api_key="api-key",
            firebase_auth_domain="project.firebaseapp.com",
            firebase_web_app_id="app-id",
            trusted_hosts=["api.example.com"],
        )


@pytest.mark.parametrize("changes", [
    {"debug": True}, {"admin_session_secret": ""},
    {"trusted_hosts": ["*"]}, {"cors_origins": ["*"]},
])
def test_production_guards(changes):
    values = dict(app_env="production", admin_session_secret="s" * 40,
                  mysql_password="test", trusted_hosts=["api.example.com"])
    values.update(changes)
    with pytest.raises(ValidationError):
        Settings(_env_file=None, **values)


def test_reject_other_database():
    with pytest.raises(ValidationError):
        Settings(_env_file=None, database_url="postgresql://localhost/test")

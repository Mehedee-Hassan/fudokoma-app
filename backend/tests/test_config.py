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

from functools import lru_cache
from typing import Literal
from pydantic import Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL, make_url


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")
    app_env: Literal["development", "test", "production"] = "development"
    app_name: str = "Fudo Koma API"
    debug: bool = False
    api_v1_prefix: str = "/api/v1"
    mysql_host: str = "127.0.0.1"
    mysql_port: int = Field(default=3306, ge=1, le=65535)
    mysql_database: str = "fudo_koma"
    mysql_user: str = "fudo_user"
    mysql_password: str = ""
    database_url: str = ""
    db_pool_size: int = Field(default=10, ge=1, le=100)
    db_max_overflow: int = Field(default=10, ge=0, le=100)
    redis_url: str = "redis://127.0.0.1:6379/0"
    firebase_project_id: str = ""
    firebase_credentials_path: str = ""
    firebase_web_api_key: str = ""
    firebase_auth_domain: str = ""
    firebase_web_app_id: str = ""
    admin_session_secret: str = ""
    admin_username: str = ""
    admin_password: SecretStr | None = None
    cors_origins: list[str] = []
    trusted_hosts: list[str] = ["localhost", "127.0.0.1", "10.0.2.2", "testserver"]
    docs_enabled: bool = True

    @field_validator("admin_password", mode="before")
    @classmethod
    def empty_admin_password_is_unset(cls, value):
        return None if value == "" else value

    @model_validator(mode="after")
    def validate_configuration(self):
        if not self.api_v1_prefix.startswith("/") or self.api_v1_prefix.endswith("/"):
            raise ValueError("API_V1_PREFIX must start with / and have no trailing slash")
        if bool(self.admin_username) != (self.admin_password is not None):
            raise ValueError("ADMIN_USERNAME and ADMIN_PASSWORD must both be configured")
        if self.admin_password is not None and len(self.admin_session_secret) < 32:
            raise ValueError(
                "ADMIN_SESSION_SECRET must contain at least 32 characters when admin login is enabled"
            )
        if bool(self.firebase_project_id) != bool(self.firebase_credentials_path):
            raise ValueError(
                "FIREBASE_PROJECT_ID and FIREBASE_CREDENTIALS_PATH must both be configured"
            )
        web_firebase_settings = (
            self.firebase_web_api_key,
            self.firebase_auth_domain,
            self.firebase_web_app_id,
        )
        if any(web_firebase_settings) and not all(web_firebase_settings):
            raise ValueError(
                "FIREBASE_WEB_API_KEY, FIREBASE_AUTH_DOMAIN, and FIREBASE_WEB_APP_ID "
                "must be configured together"
            )
        if self.database_url and make_url(self.database_url).drivername != "mysql+asyncmy":
            raise ValueError("DATABASE_URL must use mysql+asyncmy")
        if self.app_env == "production":
            if self.debug:
                raise ValueError("DEBUG must be false in production")
            if len(self.admin_session_secret) < 32:
                raise ValueError("Production ADMIN_SESSION_SECRET must contain at least 32 characters")
            production_values = (
                self.admin_session_secret,
                self.mysql_password,
                self.firebase_project_id,
                self.firebase_web_api_key,
                self.firebase_auth_domain,
                self.firebase_web_app_id,
            )
            if any(
                value.lower().startswith(("replace_", "replace-", "change-this"))
                for value in production_values
            ):
                raise ValueError("Production configuration still contains placeholder values")
            if "*" in self.trusted_hosts or not self.trusted_hosts:
                raise ValueError("Production TRUSTED_HOSTS must explicitly list domain names")
            if any(host == "example.com" or host.endswith(".example.com") for host in self.trusted_hosts):
                raise ValueError("Production TRUSTED_HOSTS must not contain example domains")
            if "*" in self.cors_origins:
                raise ValueError("Production CORS_ORIGINS must explicitly list origins")
            if not self.database_url and not self.mysql_password:
                raise ValueError("Production requires a database password")
            if not self.firebase_project_id:
                raise ValueError(
                    "Production requires FIREBASE_PROJECT_ID and FIREBASE_CREDENTIALS_PATH"
                )
            if not all(web_firebase_settings):
                raise ValueError(
                    "Production requires Firebase web app settings for admin login"
                )
        return self

    @property
    def sqlalchemy_url(self):
        return make_url(self.database_url) if self.database_url else URL.create(
            "mysql+asyncmy", username=self.mysql_user, password=self.mysql_password,
            host=self.mysql_host, port=self.mysql_port, database=self.mysql_database,
            query={"charset": "utf8mb4"},
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()

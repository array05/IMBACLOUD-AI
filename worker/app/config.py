from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    worker_token: str = "change-me-worker-token"
    worker_workspace: str = "/workspace"
    shell_timeout: int = 120
    worker_id: str = "default-worker"
    worker_public_url: str = "http://localhost:9090"
    gateway_url: str = ""
    registration_token: str = "change-me-registration-token"
    heartbeat_interval: int = 30


@lru_cache
def get_settings() -> Settings:
    return Settings()

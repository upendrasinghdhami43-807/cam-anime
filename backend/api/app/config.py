from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="API_")

    database_url: str = "postgresql+asyncpg://camanime:camanime@db:5432/camanime"
    log_level: str = "INFO"
    db_connect_retries: int = 20
    db_connect_delay_seconds: float = 1.0

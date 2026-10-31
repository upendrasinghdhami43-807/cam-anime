from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="GATEWAY_")

    upstream_url: str = "http://api:8000"
    upstream_timeout_seconds: float = 5.0
    rate_limit_per_minute: int = 120
    # Optional shared key for /v1/*. Empty means open (fine for a local test stack).
    api_key: str = ""
    max_body_bytes: int = 16_384
    log_level: str = "INFO"

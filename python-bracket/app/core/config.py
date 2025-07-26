from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # Application
    app_name: str = "Python Bracket API"
    debug: bool = False
    version: str = "1.0.0"
    
    # Server
    host: str = "0.0.0.0"
    port: int = 8000
    
    # Database
    database_url: str = "sqlite:///./bracket.db"
    
    # Security
    secret_key: str = "your-secret-key-change-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440  # 24 hours
    
    # CORS
    allowed_origins: list[str] = ["*"]
    allowed_methods: list[str] = ["*"]
    allowed_headers: list[str] = ["*"]
    
    # Pagination
    default_page_size: int = 20
    max_page_size: int = 100

    class Config:
        env_file = ".env"
        case_sensitive = False


settings = Settings()


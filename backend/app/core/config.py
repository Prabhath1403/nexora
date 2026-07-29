from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Nucleus Personal Hub"
    API_V1_STR: str = "/api/v1"
    
    DATABASE_URL: str = "postgresql+asyncpg://nucleus_user:nucleus_password@localhost:5432/nucleus_db"
    REDIS_URL: str = "redis://localhost:6379/0"
    SECRET_KEY: str = "super-secret-key-change-in-production-12345"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 30  # 30 days
    ENVIRONMENT: str = "development"

    # Backend base URL (for OAuth callbacks)
    BACKEND_URL: str = "http://localhost:8000"
    # Frontend deep-link URL (for redirect after OAuth)
    FRONTEND_REDIRECT_URL: str = "nucleus://auth/callback"

    # GitHub OAuth App credentials
    GITHUB_CLIENT_ID: str = ""
    GITHUB_CLIENT_SECRET: str = ""

    # Google OAuth2 credentials
    GOOGLE_CLIENT_ID: str = ""
    GOOGLE_CLIENT_SECRET: str = ""

    class Config:
        env_file = ".env"
        extra = "ignore"

settings = Settings()

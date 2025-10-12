import os, json
from pydantic import BaseModel

class Settings(BaseModel):
    USER_POOL_ID: str = os.getenv("USER_POOL_ID","")
    OIDC_CLIENT_ID: str = os.getenv("OIDC_CLIENT_ID","")
    COGNITO_DOMAIN: str = os.getenv("COGNITO_DOMAIN","")
    BACKEND_CORS_ORIGINS: list[str] = json.loads(os.getenv("BACKEND_CORS_ORIGINS",'["http://localhost:3000"]'))

settings = Settings()

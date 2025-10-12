import requests
from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPBearer
from jose import jwt
from app.core.config import settings

reusable_oauth2 = HTTPBearer(auto_error=False)

_jwks = None
def _get_jwks():
    global _jwks
    if _jwks is None:
        jwks_url = f"https://cognito-idp.ap-south-1.amazonaws.com/{settings.USER_POOL_ID}/.well-known/jwks.json"
        _jwks = requests.get(jwks_url, timeout=10).json()["keys"]
    return _jwks

def verify_token(token: str):
    try:
        header = jwt.get_unverified_header(token)
        key = next(k for k in _get_jwks() if k["kid"] == header["kid"])
        return jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=settings.OIDC_CLIENT_ID,
            options={"verify_exp": True}
        )
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")

def get_current_user(request: Request, credentials=Depends(reusable_oauth2)):
    token = None
    if credentials:
        token = credentials.credentials
    if not token:
        token = request.cookies.get("access_token") or request.cookies.get("id_token")
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return verify_token(token)

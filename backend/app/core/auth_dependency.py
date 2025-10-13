from fastapi import Request, HTTPException
from jose import jwt, JWTError
import requests, os

AWS_REGION = os.getenv("AWS_REGION", "ap-south-1")
COGNITO_USER_POOL_ID = os.getenv("COGNITO_USER_POOL_ID")
COGNITO_CLIENT_ID = os.getenv("COGNITO_CLIENT_ID")
JWKS_URL = f"https://cognito-idp.{AWS_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}/.well-known/jwks.json"

def get_jwks():
    if not hasattr(get_jwks, "_cache"):
        r = requests.get(JWKS_URL, timeout=5)
        r.raise_for_status()
        get_jwks._cache = r.json()["keys"]
    return get_jwks._cache

def decode_cognito_token(token: str):
    jwks = get_jwks()
    header = jwt.get_unverified_header(token)
    key = next((k for k in jwks if k["kid"] == header["kid"]), None)
    if not key:
        raise HTTPException(status_code=401, detail="Public key not found in JWKS")
    public_key = jwt.construct_rsa_public_key(key)
    try:
        return jwt.decode(token, public_key, algorithms=["RS256"], audience=COGNITO_CLIENT_ID)
    except JWTError as e:
        raise HTTPException(status_code=401, detail=f"Invalid or expired token: {e}")

def current_user(request: Request):
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")
    token = auth_header.split(" ")[1]
    return decode_cognito_token(token)

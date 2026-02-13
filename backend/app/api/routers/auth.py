from fastapi import APIRouter, Request, Depends, HTTPException
from fastapi.responses import RedirectResponse, JSONResponse
from urllib.parse import urlencode
from app.core.auth_dependency import current_user
import os, requests

router = APIRouter(prefix="/api/auth", tags=["auth"])

COGNITO_DOMAIN = os.getenv("COGNITO_DOMAIN")
COGNITO_CLIENT_ID = os.getenv("COGNITO_CLIENT_ID")

@router.get("/callback")
def cognito_callback(code: str):
    token_url = f"https://{COGNITO_DOMAIN}/oauth2/token"
    redirect_uri = "http://localhost:3000/dashboard"
    data = {
        "grant_type": "authorization_code",
        "client_id": COGNITO_CLIENT_ID,
        "code": code,
        "redirect_uri": redirect_uri
    }
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    try:
        r = requests.post(token_url, data=urlencode(data), headers=headers)
        r.raise_for_status()
        tokens = r.json()
        redirect = f"{redirect_uri}?id_token={tokens['id_token']}"
        return RedirectResponse(redirect)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Token exchange failed: {e}")

@router.get("/profile")
def profile(request: Request):
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Authorization header")
    token = auth_header.split(" ")[1]
    from app.core.auth_dependency import decode_cognito_token
    user = decode_cognito_token(token)
    return JSONResponse(user)

@router.get("/secure")
def secure_route(user: dict = Depends(current_user)):
    return {"message": "🔒 Access granted", "user": user}

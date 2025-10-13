#!/usr/bin/env bash
# =============================================================
#  AlgoDatta Full Local Auth Setup Script (v2.1)
#  ✅ Cognito (UserPool + Client + Domain + Demo Users)
#  ✅ Backend (FastAPI Auth + Middleware)
#  ✅ Frontend (Auto callback handler)
#  ✅ Fully Idempotent + Error Safe
# =============================================================
set -Eeuo pipefail
REGION="ap-south-1"
POOL_NAME="AlgoDatta-FreePool"
APP_CLIENT_NAME="AlgoDatta-local-client"
BACKEND_DIR="./backend"
FRONTEND_DIR="./frontend"
LOG_FILE="./setup_algodatta_local_auth.log"

echo "[$(date '+%F %T')] 🚀 Starting AlgoDatta Local Auth setup..." | tee "$LOG_FILE"

# --- 1️⃣ Ensure dependencies -------------------------------------------------
sudo apt update -y
sudo apt install -y awscli jq unzip curl python3-pip python3-dev libexpat1-dev zlib1g-dev

# --- 2️⃣ Cognito: Create or reuse User Pool ---------------------------------
POOL_ID=$(aws cognito-idp list-user-pools --max-results 50 \
  --region "$REGION" \
  --query "UserPools[?Name=='$POOL_NAME'].Id" \
  --output text 2>/dev/null || true)

if [[ -z "$POOL_ID" || "$POOL_ID" == "None" ]]; then
  echo "🧩 Creating new Cognito UserPool..."
  cat > cognito_free_setup.json <<'JSON'
{
  "PoolName": "AlgoDatta-FreePool",
  "MfaConfiguration": "OFF",
  "Policies": {
    "PasswordPolicy": {
      "MinimumLength": 8,
      "RequireLowercase": true,
      "RequireUppercase": false,
      "RequireNumbers": true,
      "RequireSymbols": false
    }
  },
  "UsernameAttributes": ["email"],
  "AutoVerifiedAttributes": ["email"],
  "AdminCreateUserConfig": { "AllowAdminCreateUserOnly": true },
  "EmailConfiguration": { "EmailSendingAccount": "COGNITO_DEFAULT" },
  "Schema": [
    { "Name": "email", "Required": true, "Mutable": true },
    { "Name": "name", "Required": false, "Mutable": true }
  ]
}
JSON
  POOL_ID=$(aws cognito-idp create-user-pool \
    --cli-input-json file://cognito_free_setup.json \
    --region "$REGION" \
    --query 'UserPool.Id' --output text)
  echo "✅ Created pool: $POOL_ID"
else
  echo "ℹ️ Found existing pool: $POOL_ID"
fi

# --- 3️⃣ Cognito App Client --------------------------------------------------
CLIENT_ID=$(aws cognito-idp list-user-pool-clients \
  --user-pool-id "$POOL_ID" \
  --query "UserPoolClients[?ClientName=='$APP_CLIENT_NAME'].ClientId" \
  --output text 2>/dev/null || true)

if [[ -z "$CLIENT_ID" || "$CLIENT_ID" == "None" ]]; then
  echo "🧱 Creating App Client..."
  CLIENT_ID=$(aws cognito-idp create-user-pool-client \
    --user-pool-id "$POOL_ID" \
    --client-name "$APP_CLIENT_NAME" \
    --no-generate-secret \
    --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
    --supported-identity-providers COGNITO \
    --callback-urls http://localhost:3000/dashboard \
    --logout-urls http://localhost:3000/login \
    --query 'UserPoolClient.ClientId' --output text)
  echo "✅ Created App Client: $CLIENT_ID"
else
  echo "ℹ️ Found existing App Client: $CLIENT_ID"
fi

# --- 4️⃣ Hosted Domain (idempotent) -----------------------------------------
EXISTING_DOMAIN=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$POOL_ID" \
  --query 'Domain' --output text 2>/dev/null || true)

if [[ "$EXISTING_DOMAIN" != "None" && -n "$EXISTING_DOMAIN" ]]; then
  DOMAIN="${EXISTING_DOMAIN}.auth.${REGION}.amazoncognito.com"
  echo "ℹ️ Using existing domain: $DOMAIN"
else
  DOMAIN_PREFIX="algodattalocal-$(date +%s)"
  echo "🌐 Creating new hosted domain: $DOMAIN_PREFIX"
  aws cognito-idp create-user-pool-domain \
    --domain "$DOMAIN_PREFIX" \
    --user-pool-id "$POOL_ID" >/dev/null
  DOMAIN="${DOMAIN_PREFIX}.auth.${REGION}.amazoncognito.com"
  echo "✅ Created new domain: $DOMAIN"
fi

# --- 5️⃣ Seed Demo Users -----------------------------------------------------
declare -A USERS=( ["admin"]="Admin@123" ["analyst"]="Analyst@123" ["trader"]="Trader@123" )
for user in "${!USERS[@]}"; do
  EMAIL="${user}@localhost.dev"
  PASS="${USERS[$user]}"
  if ! aws cognito-idp admin-get-user --user-pool-id "$POOL_ID" --username "$EMAIL" >/dev/null 2>&1; then
    aws cognito-idp admin-create-user \
      --user-pool-id "$POOL_ID" \
      --username "$EMAIL" \
      --user-attributes Name=email,Value="$EMAIL" Name=name,Value="$user" \
      --temporary-password "$PASS" >/dev/null
    aws cognito-idp admin-set-user-password \
      --user-pool-id "$POOL_ID" \
      --username "$EMAIL" \
      --password "$PASS" \
      --permanent >/dev/null
    echo "✅ Created demo user: $EMAIL"
  else
    echo "ℹ️ User exists: $EMAIL"
  fi
done

# --- 6️⃣ Generate .env files -------------------------------------------------
mkdir -p "$BACKEND_DIR" "$FRONTEND_DIR"

cat > "$FRONTEND_DIR/.env" <<ENV
NEXT_PUBLIC_API_BASE=http://localhost:8000
NEXT_PUBLIC_COGNITO_REGION=${REGION}
NEXT_PUBLIC_COGNITO_USER_POOL_ID=${POOL_ID}
NEXT_PUBLIC_COGNITO_CLIENT_ID=${CLIENT_ID}
NEXT_PUBLIC_COGNITO_DOMAIN=${DOMAIN}
NEXT_PUBLIC_ENV=local
ENV

cat > "$BACKEND_DIR/.env" <<ENV
APP_ENV=local
AWS_REGION=${REGION}
COGNITO_USER_POOL_ID=${POOL_ID}
COGNITO_CLIENT_ID=${CLIENT_ID}
COGNITO_DOMAIN=${DOMAIN}
ENV

echo "✅ Updated .env files for frontend and backend"

# --- 7️⃣ Patch FastAPI backend ----------------------------------------------
mkdir -p "$BACKEND_DIR/app/api/routers" "$BACKEND_DIR/app/core"

# auth_dependency.py
cat > "$BACKEND_DIR/app/core/auth_dependency.py" <<'PYCODE'
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
PYCODE

# auth.py
cat > "$BACKEND_DIR/app/api/routers/auth.py" <<'PYCODE'
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
PYCODE

# main.py
mkdir -p "$BACKEND_DIR/app"
cat > "$BACKEND_DIR/app/main.py" <<'PYCODE'
from fastapi import FastAPI
from app.api.routers import auth

app = FastAPI(title="AlgoDatta API (Local)")
app.include_router(auth.router)

@app.get("/api/healthz")
def healthz():
    return {"status": "ok"}
PYCODE

# --- 8️⃣ Patch frontend auto-callback ---------------------------------------
mkdir -p "$FRONTEND_DIR/app/(auth)/callback"
cat > "$FRONTEND_DIR/app/(auth)/callback/page.tsx" <<'TSX'
"use client";
import { useEffect } from "react";

export default function CallbackPage() {
  useEffect(() => {
    const url = new URL(window.location.href);
    const code = url.searchParams.get("code");
    if (code) {
      fetch(`/api/auth/callback?code=${code}`)
        .then((r) => {
          if (r.redirected) window.location.href = r.url;
        })
        .catch(() => alert("Login failed"));
    }
  }, []);
  return <p className="p-4 text-gray-700">Processing Cognito login...</p>;
}
TSX

# --- 9️⃣ Install backend deps ----------------------------------------------
pip install fastapi uvicorn requests "python-jose[cryptography]" -q

# --- 🔟 Display Summary ----------------------------------------------------
echo ""
echo "============================================================="
echo "🎯 AlgoDatta Local Auth Summary (v2.1)"
echo "-------------------------------------------------------------"
echo "User Pool ID : $POOL_ID"
echo "App Client ID: $CLIENT_ID"
echo "Domain       : $DOMAIN"
echo "Login URL    : https://${DOMAIN}/login?client_id=${CLIENT_ID}&response_type=code&scope=email+openid+profile&redirect_uri=http://localhost:3000/dashboard"
echo "-------------------------------------------------------------"
echo "Demo Users:"
echo "  admin@localhost.dev   / Admin@123"
echo "  analyst@localhost.dev / Analyst@123"
echo "  trader@localhost.dev  / Trader@123"
echo "============================================================="
echo ""
echo "✅ Setup complete! Next steps:"
echo "  1️⃣  cd backend && uvicorn app.main:app --reload --port 8000"
echo "  2️⃣  cd frontend && npm install && npm run dev"
echo "  3️⃣  Open the Login URL above and sign in → redirected to dashboard"

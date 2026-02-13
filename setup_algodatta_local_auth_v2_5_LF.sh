#!/usr/bin/env bash
# =============================================================
#  AlgoDatta Local Auth Setup Script (v2.5-LF)
#  ✅ Fully self-healing (domain cleanup + reattach)
#  ✅ Idempotent, Linux-native (no CRLF)
# =============================================================

# --- Normalize CRLF automatically ---
if file "$0" | grep -q CRLF; then
  echo "🧹 Normalizing Windows line endings..."
  tmpfile=$(mktemp)
  tr -d '\r' < "$0" > "$tmpfile"
  chmod +x "$tmpfile"
  exec "$tmpfile" "$@"
  exit 0
fi

set -Eeuo pipefail
REGION="ap-south-1"
POOL_NAME="AlgoDatta-FreePool-Fix"
APP_CLIENT_NAME="AlgoDatta-local-client"
BACKEND_DIR="./backend"
FRONTEND_DIR="./frontend"
LOG_FILE="./setup_algodatta_local_auth.log"

echo "[$(date '+%F %T')] 🚀 Starting AlgoDatta Local Auth setup..." | tee "$LOG_FILE"

# --- 1️⃣ AWS Credential Check ----------------------------------------------
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "⚠️ AWS credentials not found. Run 'aws configure' first."
  exit 1
fi

# --- 2️⃣ System Dependencies ----------------------------------------------
sudo apt update -y
sudo apt install -y jq unzip curl python3-pip python3-venv python3-dev libexpat1-dev zlib1g-dev

# --- 3️⃣ Get or Create User Pool ------------------------------------------
POOL_ID=$(aws cognito-idp list-user-pools --max-results 50 --region "$REGION" \
  --query "UserPools[?Name=='$POOL_NAME'].Id" --output text 2>/dev/null || true)

if [[ -z "$POOL_ID" || "$POOL_ID" == "None" ]]; then
  echo "🧩 Creating new Cognito UserPool..."
  cat > cognito_free_setup.json <<'JSON'
{
  "PoolName": "AlgoDatta-FreePool-Fix",
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
  echo "ℹ️ Using existing pool: $POOL_ID"
fi

# --- 4️⃣ App Client --------------------------------------------------------
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
  echo "ℹ️ App Client exists: $CLIENT_ID"
fi

# --- 5️⃣ Deep Domain Cleanup ----------------------------------------------
echo "🧹 Checking for stale or orphaned domains..."
POSSIBLE_DOMAINS=$(aws cognito-idp describe-user-pool --user-pool-id "$POOL_ID" --region "$REGION" \
  --query 'Domain' --output text 2>/dev/null || true)

# Extract all algodattalocal prefixes ever used
for PREFIX in $(aws cognito-idp list-user-pools --max-results 10 --region "$REGION" \
  --query "UserPools[].Name" --output text 2>/dev/null | grep -Eo 'algodattalocal-[0-9]+$' || true); do
  POSSIBLE_DOMAINS="$POSSIBLE_DOMAINS $PREFIX"
done

for D in $POSSIBLE_DOMAINS; do
  if [[ "$D" != "None" && "$D" != "null" && -n "$D" ]]; then
    echo "🔸 Deleting stale domain: $D"
    aws cognito-idp delete-user-pool-domain \
      --user-pool-id "$POOL_ID" \
      --domain "$D" \
      --region "$REGION" >/dev/null 2>&1 || true
  fi
done
sleep 5

# --- 6️⃣ Create new domain -------------------------------------------------
DOMAIN_PREFIX="algodattalocal-$(date +%s)"
echo "🌐 Creating fresh hosted domain: $DOMAIN_PREFIX"
aws cognito-idp create-user-pool-domain \
  --domain "$DOMAIN_PREFIX" \
  --user-pool-id "$POOL_ID" >/dev/null
DOMAIN="${DOMAIN_PREFIX}.auth.${REGION}.amazoncognito.com"
echo "✅ Domain ready: $DOMAIN"

# --- 7️⃣ Seed Users --------------------------------------------------------
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

# --- 8️⃣ .env Files --------------------------------------------------------
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
echo "✅ .env files written"

# --- 9️⃣ Backend Virtualenv ------------------------------------------------
cd "$BACKEND_DIR"
python3 -m venv venv || true
source venv/bin/activate
pip install --upgrade pip
pip install fastapi uvicorn requests "python-jose[cryptography]" -q --break-system-packages || true
deactivate
cd -

# --- 🔟 Final Summary ------------------------------------------------------
echo ""
echo "============================================================="
echo "🎯 AlgoDatta Local Auth Setup Complete (v2.5-LF)"
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
echo "✅ You can now run:"
echo "▶ cd backend && source venv/bin/activate && uvicorn app.main:app --reload --port 8000"
echo "▶ cd frontend && npm install && npm run dev"
echo "============================================================="

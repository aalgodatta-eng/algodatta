#!/usr/bin/env bash
# =============================================================
#  AlgoDatta Local Cognito Setup Script
#  Creates: User Pool (if missing), App Client, Hosted Domain,
#           Demo Users (admin / analyst / trader)
#           and generates .env for frontend & backend
#  Environment: local  |  Region: ap-south-1
# =============================================================
set -Eeuo pipefail

REGION="ap-south-1"
POOL_NAME="AlgoDatta-FreePool"
APP_CLIENT_NAME="AlgoDatta-local-client"
DOMAIN_PREFIX="algodattalocal-$(date +%s)"
LOG_FILE="./cognito_setup.log"

echo "[$(date '+%F %T')] 🚀 Starting Cognito setup..." | tee "$LOG_FILE"

# --- Step 1️⃣ : Find or Create User Pool -------------------------------------
POOL_ID=$(aws cognito-idp list-user-pools \
  --max-results 50 \
  --region "$REGION" \
  --query "UserPools[?Name=='$POOL_NAME'].Id" \
  --output text 2>/dev/null || true)

if [[ -z "$POOL_ID" || "$POOL_ID" == "None" ]]; then
  echo "🧩 Creating new Cognito User Pool: $POOL_NAME"
  POOL_ID=$(aws cognito-idp create-user-pool \
    --cli-input-json file://cognito_free_setup.json \
    --region "$REGION" \
    --query 'UserPool.Id' --output text)
  echo "✅ Created User Pool: $POOL_ID"
else
  echo "ℹ️ Found existing pool: $POOL_ID"
fi

# --- Step 2️⃣ : Create or Fetch App Client -----------------------------------
CLIENT_ID=$(aws cognito-idp list-user-pool-clients \
  --user-pool-id "$POOL_ID" \
  --query "UserPoolClients[?ClientName=='$APP_CLIENT_NAME'].ClientId" \
  --output text 2>/dev/null || true)

if [[ -z "$CLIENT_ID" || "$CLIENT_ID" == "None" ]]; then
  echo "🧱 Creating new App Client..."
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

# --- Step 3️⃣ : Create Hosted Domain -----------------------------------------
EXISTING_DOMAIN=$(aws cognito-idp describe-user-pool \
  --user-pool-id "$POOL_ID" \
  --query 'Domain' --output text 2>/dev/null || true)

if [[ "$EXISTING_DOMAIN" == "None" || -z "$EXISTING_DOMAIN" ]]; then
  echo "🌐 Creating Hosted Domain..."
  aws cognito-idp create-user-pool-domain \
    --domain "$DOMAIN_PREFIX" \
    --user-pool-id "$POOL_ID" \
    --region "$REGION" >/dev/null
  DOMAIN_NAME="$DOMAIN_PREFIX.auth.${REGION}.amazoncognito.com"
  echo "✅ Created domain: $DOMAIN_NAME"
else
  DOMAIN_NAME="${EXISTING_DOMAIN}.auth.${REGION}.amazoncognito.com"
  echo "ℹ️ Existing domain found: $DOMAIN_NAME"
fi

# --- Step 4️⃣ : Create Demo Users --------------------------------------------
declare -A USERS=(
  ["admin"]="Admin@123"
  ["analyst"]="Analyst@123"
  ["trader"]="Trader@123"
)

echo "👥 Creating demo users..."
for USER in "${!USERS[@]}"; do
  EMAIL="${USER}@localhost.dev"
  PASS="${USERS[$USER]}"
  echo "→ $EMAIL"
  if ! aws cognito-idp admin-get-user \
    --user-pool-id "$POOL_ID" \
    --username "$EMAIL" >/dev/null 2>&1; then
      aws cognito-idp admin-create-user \
        --user-pool-id "$POOL_ID" \
        --username "$EMAIL" \
        --user-attributes Name=email,Value="$EMAIL" Name=name,Value="$USER" \
        --temporary-password "$PASS" >/dev/null
      aws cognito-idp admin-set-user-password \
        --user-pool-id "$POOL_ID" \
        --username "$EMAIL" \
        --password "$PASS" \
        --permanent >/dev/null
      echo "✅ Created user: $EMAIL / $PASS"
  else
      echo "ℹ️ User already exists: $EMAIL"
  fi
done

# --- Step 5️⃣ : Generate .env for frontend/backend ---------------------------
echo "🧾 Generating local .env files..."

cat > ./frontend.env <<ENV
NEXT_PUBLIC_API_BASE=http://localhost:8000
NEXT_PUBLIC_COGNITO_REGION=${REGION}
NEXT_PUBLIC_COGNITO_USER_POOL_ID=${POOL_ID}
NEXT_PUBLIC_COGNITO_CLIENT_ID=${CLIENT_ID}
NEXT_PUBLIC_COGNITO_DOMAIN=${DOMAIN_NAME}
NEXT_PUBLIC_ENV=local
ENV

cat > ./backend.env <<ENV
APP_ENV=local
AWS_REGION=${REGION}
COGNITO_USER_POOL_ID=${POOL_ID}
COGNITO_CLIENT_ID=${CLIENT_ID}
COGNITO_DOMAIN=${DOMAIN_NAME}
ENV

echo "✅ .env files generated:"
echo "  → ./frontend.env"
echo "  → ./backend.env"

# --- Step 6️⃣ : Display Summary ----------------------------------------------
echo ""
echo "============================================================="
echo "🎯 Cognito Local Setup Summary"
echo "-------------------------------------------------------------"
echo "User Pool ID : $POOL_ID"
echo "App Client ID: $CLIENT_ID"
echo "Domain       : $DOMAIN_NAME"
echo "Login URL    : https://${DOMAIN_NAME}/login?client_id=${CLIENT_ID}&response_type=code&scope=email+openid+profile&redirect_uri=http://localhost:3000/dashboard"
echo "-------------------------------------------------------------"
echo "Demo Users:"
echo "  admin@localhost.dev   / Admin@123"
echo "  analyst@localhost.dev / Analyst@123"
echo "  trader@localhost.dev  / Trader@123"
echo "============================================================="
echo ""
echo "✅ Setup complete! Use the above login URL to test local authentication."

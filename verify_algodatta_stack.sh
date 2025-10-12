#!/usr/bin/env bash
# =============================================================
#  AlgoDatta Cognito Verification Script
#  Checks Cognito Pool, Users, and Domain
#  Idempotent & safe for re-runs
# =============================================================
set -Eeuo pipefail
BASE_DIR="$HOME/AlgoDatta"
ENV_FILE="$BASE_DIR/.env"
LOG_DIR="/var/log/algodatta"
MANIFEST_FILE="$LOG_DIR/env_manifest.json"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Missing .env file in $BASE_DIR"
  exit 1
fi

export $(grep -v '^#' "$ENV_FILE" | xargs)

POOL_ID="${USER_POOL_ID:-}"
CLIENT_ID="${OIDC_CLIENT_ID:-}"
COGNITO_DOMAIN="${COGNITO_DOMAIN:-}"
AWS_REGION="ap-south-1"

if [[ -z "$POOL_ID" || -z "$CLIENT_ID" || -z "$COGNITO_DOMAIN" ]]; then
  echo "❌ Missing required Cognito details in .env file."
  exit 1
fi

echo "[$(date '+%F %T')] 🔍 Verifying Cognito setup..."
echo "Pool ID: $POOL_ID"
echo "Client ID: $CLIENT_ID"
echo "Domain: $COGNITO_DOMAIN"

# --- 1️⃣ Pool check --------------------------------------------------------
if aws cognito-idp describe-user-pool --user-pool-id "$POOL_ID" >/dev/null 2>&1; then
  echo "✅ Cognito Pool reachable."
else
  echo "❌ Cannot reach Cognito Pool $POOL_ID."
fi

# --- 2️⃣ Domain check -----------------------------------------------------
DOMAIN_URL="${COGNITO_DOMAIN}/.well-known/openid-configuration"
if curl -fsI "$DOMAIN_URL" | grep -q "200 OK"; then
  echo "✅ Cognito domain reachable: $DOMAIN_URL"
else
  echo "⚠️ Cognito domain not reachable ($DOMAIN_URL)"
fi

# --- 3️⃣ User existence check ---------------------------------------------
for U in admin analyst trader; do
  EMAIL="${U}.aalgodatta@gmail.com"
  if aws cognito-idp admin-get-user --user-pool-id "$POOL_ID" --username "$EMAIL" >/dev/null 2>&1; then
    echo "✅ User exists: $EMAIL"
  else
    echo "⚠️ User missing: $EMAIL"
  fi
done

# --- 4️⃣ Client check ------------------------------------------------------
CLIENT_DESC=$(aws cognito-idp describe-user-pool-client --user-pool-id "$POOL_ID" --client-id "$CLIENT_ID" 2>/dev/null || true)
if [[ -n "$CLIENT_DESC" ]]; then
  echo "✅ Client configuration found."
else
  echo "⚠️ Client not found for Pool $POOL_ID."
fi

# --- 5️⃣ Summary -----------------------------------------------------------
echo "============================================================="
echo "🧠 Cognito Verification complete!"
echo "Login URL: ${COGNITO_DOMAIN}/login?client_id=${CLIENT_ID}"
echo "Pool ID: $POOL_ID"
echo "============================================================="

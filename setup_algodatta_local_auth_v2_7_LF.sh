#!/usr/bin/env bash
# =============================================================
# AlgoDatta Local Cognito Auth Setup (v2.7-LF)
# Idempotent | Sudo-safe | Auto AWS Cred Copy | Redirect Ready
# =============================================================
set -Eeuo pipefail

LOG_TAG="[AlgoDatta]"
AWS_REGION="ap-south-1"
POOL_NAME="AlgoDatta-FreePool"
FRONTEND_URL="http://localhost:3000"
BACKEND_URL="http://localhost:8000"
DASHBOARD_URL="${FRONTEND_URL}/dashboard"
LOGIN_URL="${FRONTEND_URL}/login"
LOG_DIR="/var/log/algodatta"
mkdir -p "$LOG_DIR"

log() { echo "[$(date '+%F %T')] ${LOG_TAG} $*"; }

# --- 1️⃣ Ensure AWS credentials for root -------------------------------
if [[ ! -f /root/.aws/credentials ]]; then
  if [[ -d /home/$SUDO_USER/.aws ]]; then
    log "🪄 Copying AWS credentials from /home/$SUDO_USER/.aws → /root/.aws"
    sudo mkdir -p /root/.aws
    sudo cp -r /home/$SUDO_USER/.aws/* /root/.aws/
    sudo chmod 600 /root/.aws/credentials
  else
    log "⚠️ No AWS credentials found for root or $SUDO_USER. Run aws configure first."
  fi
fi

# --- 2️⃣ Dependencies ---------------------------------------------------
log "🚀 Starting AlgoDatta Local Auth setup..."
sudo apt-get update -y -qq
sudo apt-get install -y jq unzip curl python3-pip python3-venv python3-dev libexpat1-dev zlib1g-dev >/dev/null
log "✅ Dependencies ready."

# --- 3️⃣ AWS CLI --------------------------------------------------------
if ! command -v aws >/dev/null 2>&1; then
  log "📦 Installing AWS CLI..."
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -q -o /tmp/awscliv2.zip -d /tmp
  sudo /tmp/aws/install
fi
log "ℹ️ AWS CLI version: $(aws --version 2>&1)"

# --- 4️⃣ Verify AWS -----------------------------------------------------
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  log "❌ AWS credentials missing or invalid. Run: aws configure"
  exit 1
fi

# --- 5️⃣ Cognito Pool ---------------------------------------------------
POOL_ID=$(aws cognito-idp list-user-pools --max-results 10 --region "$AWS_REGION" \
  --query "UserPools[?Name=='${POOL_NAME}'].Id" --output text)

if [[ -z "$POOL_ID" || "$POOL_ID" == "None" ]]; then
  log "🧩 Creating new Cognito UserPool..."
  POOL_ID=$(aws cognito-idp create-user-pool \
    --pool-name "$POOL_NAME" \
    --policies '{"PasswordPolicy":{"MinimumLength":8,"RequireLowercase":true,"RequireUppercase":false,"RequireNumbers":true,"RequireSymbols":false}}' \
    --region "$AWS_REGION" --query 'UserPool.Id' --output text)
  log "✅ Created pool: $POOL_ID"
else
  log "ℹ️ Using existing pool: $POOL_ID"
fi

# --- 6️⃣ Cognito App Client ---------------------------------------------
CLIENT_NAME="algodatta-local-client"
CLIENT_ID=$(aws cognito-idp list-user-pool-clients \
  --user-pool-id "$POOL_ID" \
  --query "UserPoolClients[?ClientName=='${CLIENT_NAME}'].ClientId" \
  --output text --region "$AWS_REGION")

if [[ -z "$CLIENT_ID" || "$CLIENT_ID" == "None" ]]; then
  log "🧱 Creating App Client..."
  CLIENT_ID=$(aws cognito-idp create-user-pool-client \
    --user-pool-id "$POOL_ID" \
    --client-name "$CLIENT_NAME" \
    --generate-secret \
    --allowed-o-auth-flows code \
    --allowed-o-auth-scopes "email" "openid" "profile" \
    --supported-identity-providers "COGNITO" \
    --callback-urls "$DASHBOARD_URL" \
    --logout-urls "$LOGIN_URL" \
    --region "$AWS_REGION" \
    --query 'UserPoolClient.ClientId' --output text)
  log "✅ Created App Client: $CLIENT_ID"
else
  log "ℹ️ App Client exists: $CLIENT_ID"
  aws cognito-idp update-user-pool-client \
    --user-pool-id "$POOL_ID" \
    --client-id "$CLIENT_ID" \
    --allowed-o-auth-flows code \
    --allowed-o-auth-scopes "email" "openid" "profile" \
    --supported-identity-providers "COGNITO" \
    --callback-urls "$DASHBOARD_URL" \
    --logout-urls "$LOGIN_URL" \
    --region "$AWS_REGION" >/dev/null
fi

# --- 7️⃣ Domain Self-Healing -------------------------------------------
EXISTING_DOMAIN=$(aws cognito-idp describe-user-pool --user-pool-id "$POOL_ID" \
  --region "$AWS_REGION" --query "UserPool.Domain" --output text || true)

if [[ "$EXISTING_DOMAIN" == "None" || -z "$EXISTING_DOMAIN" || "$EXISTING_DOMAIN" == "null" ]]; then
  DOMAIN_ALIAS="algodattalocal-$(date +%s)"
  log "🌐 Creating new hosted domain: $DOMAIN_ALIAS"
  aws cognito-idp create-user-pool-domain \
    --domain "$DOMAIN_ALIAS" \
    --user-pool-id "$POOL_ID" \
    --region "$AWS_REGION" >/dev/null
  COGNITO_DOMAIN="${DOMAIN_ALIAS}.auth.${AWS_REGION}.amazoncognito.com"
else
  COGNITO_DOMAIN="${EXISTING_DOMAIN}.auth.${AWS_REGION}.amazoncognito.com"
  log "ℹ️ Existing domain detected: $COGNITO_DOMAIN"
fi

# --- 8️⃣ Demo Users -----------------------------------------------------
declare -A USERS=(["admin"]="Admin@123" ["analyst"]="Analyst@123" ["trader"]="Trader@123")
for user in "${!USERS[@]}"; do
  EMAIL="${user}@localhost.dev"
  PASS="${USERS[$user]}"
  if ! aws cognito-idp admin-get-user --user-pool-id "$POOL_ID" --username "$EMAIL" --region "$AWS_REGION" >/dev/null 2>&1; then
    aws cognito-idp admin-create-user \
      --user-pool-id "$POOL_ID" \
      --username "$EMAIL" \
      --user-attributes Name=email,Value="$EMAIL" Name=name,Value="$user" \
      --temporary-password "$PASS" --region "$AWS_REGION" >/dev/null
    aws cognito-idp admin-set-user-password \
      --user-pool-id "$POOL_ID" --username "$EMAIL" \
      --password "$PASS" --permanent --region "$AWS_REGION" >/dev/null
    log "✅ Created demo user: $EMAIL"
  else
    log "ℹ️ User exists: $EMAIL"
  fi
done

# --- 9️⃣ Env Files ------------------------------------------------------
mkdir -p frontend backend
cat > frontend/.env <<ENV
NEXT_PUBLIC_COGNITO_CLIENT_ID=${CLIENT_ID}
NEXT_PUBLIC_COGNITO_DOMAIN=${COGNITO_DOMAIN}
NEXT_PUBLIC_COGNITO_REGION=${AWS_REGION}
NEXT_PUBLIC_REDIRECT_URI=${DASHBOARD_URL}
NEXT_PUBLIC_LOGOUT_URI=${LOGIN_URL}
NEXT_PUBLIC_API_BASE=${BACKEND_URL}
ENV

cat > backend/.env <<ENV
COGNITO_USER_POOL_ID=${POOL_ID}
COGNITO_CLIENT_ID=${CLIENT_ID}
COGNITO_DOMAIN=${COGNITO_DOMAIN}
AWS_REGION=${AWS_REGION}
APP_ENV=local
ENV
log "✅ .env files written"

# --- 🔟 Middleware Redirect ---------------------------------------------
mkdir -p frontend
cat > frontend/middleware.ts <<TS
import { NextResponse } from "next/server";
const COGNITO_LOGIN_URL = "https://${COGNITO_DOMAIN}/login?client_id=${CLIENT_ID}&response_type=code&scope=email+openid+profile&redirect_uri=${DASHBOARD_URL}";
export function middleware(req: Request) {
  const url = new URL(req.url);
  if (url.pathname === "/" || url.pathname === "/login") {
    return NextResponse.redirect(COGNITO_LOGIN_URL);
  }
  return NextResponse.next();
}
TS
log "✅ Frontend redirect middleware added."

# --- 11️⃣ Manifest ------------------------------------------------------
jq -n \
  --arg pool "$POOL_ID" \
  --arg client "$CLIENT_ID" \
  --arg domain "$COGNITO_DOMAIN" \
  --arg front "$FRONTEND_URL" \
  --arg back "$BACKEND_URL" \
  --arg region "$AWS_REGION" \
  '{
    environment: "local",
    cognito: { user_pool_id: $pool, client_id: $client, domain: $domain },
    endpoints: { frontend: $front, backend: $back },
    region: $region,
    timestamp: now | todate
  }' > "$LOG_DIR/env_manifest.json"
log "📦 Manifest saved → $LOG_DIR/env_manifest.json"

# --- ✅ Summary --------------------------------------------------------
LOGIN_REDIRECT="https://${COGNITO_DOMAIN}/login?client_id=${CLIENT_ID}&response_type=code&scope=email+openid+profile&redirect_uri=${DASHBOARD_URL}"
cat <<EOF
=============================================================
🎯 AlgoDatta Local Auth Setup Complete (v2.7-LF)
-------------------------------------------------------------
User Pool ID : ${POOL_ID}
App Client ID: ${CLIENT_ID}
Domain       : ${COGNITO_DOMAIN}
Login URL    : ${LOGIN_REDIRECT}
-------------------------------------------------------------
Demo Users:
  admin@localhost.dev   / Admin@123
  analyst@localhost.dev / Analyst@123
  trader@localhost.dev  / Trader@123
=============================================================
✅ You can now run:
▶ cd backend && source venv/bin/activate && uvicorn app.main:app --reload --port 8000
▶ cd frontend && npm install && npm run dev
=============================================================
EOF

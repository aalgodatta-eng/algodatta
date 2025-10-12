#!/usr/bin/env bash
# =============================================================
#  AlgoDatta Lightsail Build Script (local | prod)
#  v8.0 — Auto-detect .env + Docker CE + AWS CLI v2 + Idempotent
# =============================================================
set -Eeuo pipefail

ENVIRONMENT="${1:-prod}"
APP_NAME="AlgoDatta"
AWS_REGION="ap-south-1"
AWS_PROFILE="default"

BASE_DIR="$HOME/$APP_NAME"
LOG_DIR="/var/log/algodatta"
COGNITO_FILE="$BASE_DIR/cognito_free_setup.json"
AWS_INFO_FILE="$BASE_DIR/awsInfo.json"
TF_FILE="$BASE_DIR/main.tf"
OUTPUT_FILE="$BASE_DIR/outputs.tf"
MANIFEST_FILE="$LOG_DIR/env_manifest.json"

mkdir -p "$BASE_DIR" "$LOG_DIR"
cd "$BASE_DIR" 2>/dev/null || mkdir -p "$BASE_DIR" && cd "$BASE_DIR"

echo "[$(date '+%F %T')] 🚀 Starting $APP_NAME setup (ENV=$ENVIRONMENT)"

# --- 1️⃣ Locate .env automatically ----------------------------------------
ENV_PATHS=(
  "$BASE_DIR/.env"
  "/home/ubuntu/AlgoDatta/.env"
  "/root/AlgoDatta/.env"
)
ENV_FILE=""
for p in "${ENV_PATHS[@]}"; do
  if [ -f "$p" ]; then ENV_FILE="$p"; break; fi
done
if [ -z "$ENV_FILE" ]; then
  echo "❌ .env file not found in any known location:"; printf ' - %s\n' "${ENV_PATHS[@]}"; exit 1
fi
echo "✅ Found .env file at: $ENV_FILE"

# --- 2️⃣ Load environment variables ---------------------------------------
export $(grep -v '^#' "$ENV_FILE" | xargs)
echo "📦 Loaded Cognito + AWS variables"

# --- 3️⃣ Configure AWS CLI -------------------------------------------------
aws configure set aws_access_key_id "$ACCESS_KEY" --profile "$AWS_PROFILE"
aws configure set aws_secret_access_key "$SECRET_KEY" --profile "$AWS_PROFILE"
aws configure set region "$AWS_REGION" --profile "$AWS_PROFILE"
aws configure set output json --profile "$AWS_PROFILE"

# --- 4️⃣ Install dependencies ---------------------------------------------
echo "📦 Installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y unzip jq curl terraform nginx

# --- Docker CE (fixes containerd conflict) --------------------------------
if ! command -v docker &>/dev/null; then
  echo "🐳 Installing Docker CE from official repository..."
  sudo apt-get remove -y docker docker.io containerd runc || true
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" |
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "✅ Docker already installed"
fi

if ! command -v docker-compose &>/dev/null; then
  echo "🐙 Installing Docker Compose v2..."
  sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi

# --- AWS CLI v2 (official ZIP install) ------------------------------------
if ! command -v aws &>/dev/null; then
  echo "☁️ Installing AWS CLI v2..."
  cd /tmp
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -o awscliv2.zip >/dev/null
  sudo ./aws/install
  aws --version || echo "⚠️ AWS CLI install check failed"
else
  echo "✅ AWS CLI already installed"
fi
sudo systemctl enable docker && sudo systemctl start docker

# --- 5️⃣ Extract files -----------------------------------------------------
if ls *.zip >/dev/null 2>&1; then unzip -o *.zip -d "$BASE_DIR" >/dev/null; fi
cp -f *.json *.tf *.png "$BASE_DIR" 2>/dev/null || true

# --- 6️⃣ Use existing Cognito config --------------------------------------
POOL_ID="${USER_POOL_ID:-}"
CLIENT_ID="${OIDC_CLIENT_ID:-}"
COGNITO_DOMAIN="${COGNITO_DOMAIN:-}"
OIDC_REDIRECT_URI="${OIDC_REDIRECT_URI:-https://www.algodatta.com/api/oidc/callback}"
FRONTEND_URL="https://www.algodatta.com"
BACKEND_URL="https://api.algodatta.com"

if [[ -z "$POOL_ID" || -z "$CLIENT_ID" || -z "$COGNITO_DOMAIN" ]]; then
  echo "❌ Missing Cognito details in .env — verify USER_POOL_ID, OIDC_CLIENT_ID, and COGNITO_DOMAIN"; exit 1
fi

LOGIN_URL="${COGNITO_DOMAIN}/login?client_id=${CLIENT_ID}&response_type=code&scope=email+openid+profile&redirect_uri=${OIDC_REDIRECT_URI}"
echo "✅ Using Cognito Pool: $POOL_ID"
echo "✅ Cognito Client: $CLIENT_ID"
echo "✅ Domain: $COGNITO_DOMAIN"
echo "🌐 Hosted UI: $LOGIN_URL"

# --- 7️⃣ Create demo users (safe re-run) -----------------------------------
echo "[$(date '+%F %T')] 👥 Creating demo users..."
declare -A USERS=( ["admin"]="Admin@123" ["analyst"]="Analyst@123" ["trader"]="Trader@123" )
for USERNAME in "${!USERS[@]}"; do
  EMAIL="${USERNAME}.aalgodatta@gmail.com"
  PASSWORD="${USERS[$USERNAME]}"
  if aws cognito-idp admin-get-user --user-pool-id "$POOL_ID" --username "$EMAIL" >/dev/null 2>&1; then
    echo "ℹ️ User already exists: $EMAIL"
  else
    aws cognito-idp admin-create-user --user-pool-id "$POOL_ID" \
      --username "$EMAIL" \
      --user-attributes Name=email,Value="$EMAIL" Name=name,Value="$USERNAME" \
      --temporary-password "$PASSWORD" >/dev/null
    aws cognito-idp admin-set-user-password --user-pool-id "$POOL_ID" \
      --username "$EMAIL" --password "$PASSWORD" --permanent >/dev/null
    echo "✅ Created demo user: $EMAIL"
  fi
done

# --- 8️⃣ Terraform --------------------------------------------------------
echo "[$(date '+%F %T')] 🧱 Running Terraform..."
sed -i 's/{ minimum_length=8, require_lowercase=true, require_uppercase=false, require_numbers=true, require_symbols=false }/{\n    minimum_length = 8\n    require_lowercase = true\n    require_uppercase = false\n    require_numbers = true\n    require_symbols = false\n}/' "$TF_FILE" || true
terraform init -input=false >/dev/null
terraform apply -auto-approve | tee "$LOG_DIR/terraform.log"

# --- 9️⃣ Environment files ------------------------------------------------
mkdir -p "$BASE_DIR/frontend" "$BASE_DIR/backend"
cat > "$BASE_DIR/frontend/.env" <<ENV
NEXT_PUBLIC_API_BASE=${BACKEND_URL}
NEXT_PUBLIC_COGNITO_CLIENT_ID=${CLIENT_ID}
NEXT_PUBLIC_COGNITO_DOMAIN=${COGNITO_DOMAIN#https://}
NEXT_PUBLIC_COGNITO_REGION=${AWS_REGION}
NEXT_PUBLIC_ENV=${ENVIRONMENT}
ENV

cat > "$BASE_DIR/backend/.env" <<ENV
COGNITO_USER_POOL_ID=${POOL_ID}
COGNITO_CLIENT_ID=${CLIENT_ID}
COGNITO_DOMAIN=${COGNITO_DOMAIN#https://}
AWS_REGION=${AWS_REGION}
APP_ENV=${ENVIRONMENT}
ENV

# --- 🔟 Docker ------------------------------------------------------------
echo "[$(date '+%F %T')] 🐳 Building Docker containers..."
docker compose -f docker-compose.yml -f docker-compose.override.yml build
docker compose up -d

# --- 11️⃣ Nginx ------------------------------------------------------------
sudo tee /etc/nginx/sites-available/algodatta >/dev/null <<NGINX_CONF
server {
  listen 80;
  server_name www.algodatta.com algodatta.com;
  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
  location /api/ {
    proxy_pass http://127.0.0.1:8000/;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
}
NGINX_CONF
sudo ln -sf /etc/nginx/sites-available/algodatta /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# --- 12️⃣ Health Checks ----------------------------------------------------
sleep 5
curl -fsSL ${BACKEND_URL}/api/healthz || echo "⚠️ Backend health check failed"
curl -fsSL ${FRONTEND_URL} || echo "⚠️ Frontend check failed"

# --- 13️⃣ Manifest --------------------------------------------------------
jq -n \
  --arg env "$ENVIRONMENT" \
  --arg pool "$POOL_ID" \
  --arg client "$CLIENT_ID" \
  --arg domain "$COGNITO_DOMAIN" \
  --arg login "$LOGIN_URL" \
  --arg front "$FRONTEND_URL" \
  --arg back "$BACKEND_URL" \
  --arg region "$AWS_REGION" \
  '{
    environment: $env,
    cognito: {
      user_pool_id: $pool,
      client_id: $client,
      domain: $domain,
      login_url: $login
    },
    endpoints: {
      frontend: $front,
      backend: $back
    },
    region: $region,
    timestamp: now | todate
  }' > "$MANIFEST_FILE"

chmod 644 "$MANIFEST_FILE"
echo "============================================================="
echo "✅ Deployment complete!"
echo "Frontend → ${FRONTEND_URL}"
echo "Backend  → ${BACKEND_URL}"
echo "Login UI → ${LOGIN_URL}"
echo "Demo users:"
echo "  admin.aalgodatta@gmail.com / Admin@123"
echo "  analyst.aalgodatta@gmail.com / Analyst@123"
echo "  trader.aalgodatta@gmail.com / Trader@123"
echo "📦 Manifest → $MANIFEST_FILE"
echo "============================================================="

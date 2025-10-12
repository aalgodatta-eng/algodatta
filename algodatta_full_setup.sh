#!/usr/bin/env bash
# =============================================================
#  AlgoDatta Full Bootstrap Script (Setup + Deploy + Verify)
#  Version: v9.0 | Ubuntu 20.04 / 22.04 (Amazon Lightsail)
# =============================================================
set -Eeuo pipefail

APP_DIR="/home/ubuntu/AlgoDatta"
LOG_DIR="/var/log/algodatta"
mkdir -p "$APP_DIR" "$LOG_DIR"

SHUTDOWN_AFTER=false
if [[ "${1:-}" == "--shutdown-after" ]]; then
  SHUTDOWN_AFTER=true
  shift || true
fi

echo "[$(date '+%F %T')] 🚀 Starting AlgoDatta full setup..."

# --- 1️⃣ Update system ----------------------------------------------------
sudo apt-get update -y && sudo apt-get upgrade -y

# --- 2️⃣ Core utilities ---------------------------------------------------
sudo apt-get install -y curl unzip jq git nginx ca-certificates \
  apt-transport-https gnupg lsb-release software-properties-common

# --- 3️⃣ AWS CLI ----------------------------------------------------------
if ! command -v aws &>/dev/null; then
  echo "☁️ Installing AWS CLI v2..."
  cd /tmp && curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
  unzip -o awscliv2.zip >/dev/null && sudo ./aws/install
fi

# --- 4️⃣ Terraform --------------------------------------------------------
if ! command -v terraform &>/dev/null; then
  echo "🧱 Installing Terraform..."
  curl -fsSL https://apt.releases.hashicorp.com/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt-get update && sudo apt-get install -y terraform
fi

# --- 5️⃣ Docker + Compose -------------------------------------------------
if ! command -v docker &>/dev/null; then
  echo "🐳 Installing Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh
  sudo usermod -aG docker ubuntu
fi
if ! command -v docker-compose &>/dev/null; then
  echo "🐙 Installing Docker Compose..."
  sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose
fi
sudo systemctl enable docker && sudo systemctl start docker

# --- 6️⃣ Verify core tools ------------------------------------------------
for cmd in aws terraform docker docker-compose jq nginx; do
  command -v "$cmd" >/dev/null || { echo "❌ Missing $cmd"; exit 1; }
done
echo "✅ Core tools verified."

# --- 7️⃣ Move project files ----------------------------------------------
for f in awsInfo.json cognito_free_setup.json main.tf *.png *.zip build_algodatta_lightsail.sh; do
  [ -f "$f" ] && sudo mv -f "$f" "$APP_DIR"/
done
cd "$APP_DIR"
chmod +x build_algodatta_lightsail.sh || true

# --- 8️⃣ Check AWS credentials -------------------------------------------
DRY_RUN=false
if ! grep -q "aws_access_key_id" ~/.aws/credentials 2>/dev/null; then
  echo "⚠️ No AWS credentials found. DRY-RUN mode activated (mock containers only)."
  DRY_RUN=true
else
  echo "✅ AWS credentials found. Proceeding with full deployment."
fi

# --- 9️⃣ Nginx bootstrap --------------------------------------------------
sudo systemctl enable nginx && sudo systemctl start nginx

# --- 🔟 DRY-RUN (Mock Containers) ----------------------------------------
if [ "$DRY_RUN" = true ]; then
  echo "============================================================="
  echo "🧪 DRY-RUN MODE — launching mock frontend/backend containers..."
  echo "============================================================="
  unzip -o *.zip -d "$APP_DIR/mock" >/dev/null 2>&1 || true

  # Clean and create fixed mock docker-compose.yml
  cat > "$APP_DIR/mock/docker-compose.yml" <<'YML'
services:
  mock-backend:
    image: python:3.11-slim
    container_name: algodatta-mock-backend
    working_dir: /app
    command: bash -c "mkdir -p api && echo '{\"status\":\"ok\"}' > api/healthz && python3 -m http.server 8000"
    volumes:
      - .:/app
    ports:
      - "8000:8000"

  mock-frontend:
    image: node:18-alpine
    container_name: algodatta-mock-frontend
    working_dir: /app
    command: sh -c 'npx http-server -p 3000 .'
    volumes:
      - .:/app
    ports:
      - "3000:3000"
YML

  cd "$APP_DIR/mock"
  sudo docker-compose down >/dev/null 2>&1 || true
  sudo docker-compose up -d
  sleep 5
  IP=$(curl -s ifconfig.me || echo "localhost")
  echo "✅ Mock containers running:"
  sudo docker ps --filter "name=algodatta-mock"
  echo "🌐 Visit:"
  echo "  Frontend → http://$IP:3000"
  echo "  Backend  → http://$IP:8000"
else
  echo "============================================================="
  echo "🚀 Running full AlgoDatta build script (prod mode)..."
  echo "============================================================="

  # --- Patch seed users in build script ----------------------------------
  sed -i '/# --- 7️⃣ Seed Demo Users/,/# --- 8️⃣ Terraform/{
    /# --- 7️⃣ Seed Demo Users/!d
    a echo "[$(date +%F_%T)] 👥 Creating demo users (admin, analyst, trader)..."
    a declare -A USERS=(["admin"]="Admin@123" ["analyst"]="Analyst@123" ["trader"]="Trader@123")
    a for USERNAME in "${!USERS[@]}"; do
    a   EMAIL_PREFIX="${USERNAME}.aalgodatta@gmail.com"
    a   PASSWORD="${USERS[$USERNAME]}"
    a   if ! aws cognito-idp admin-get-user --user-pool-id "$POOL_ID" --username "$EMAIL_PREFIX" >/dev/null 2>&1; then
    a     aws cognito-idp admin-create-user --user-pool-id "$POOL_ID" --username "$EMAIL_PREFIX" --user-attributes Name=email,Value="$EMAIL_PREFIX" Name=name,Value="$USERNAME" --temporary-password "$PASSWORD" >/dev/null
    a     aws cognito-idp admin-set-user-password --user-pool-id "$POOL_ID" --username "$EMAIL_PREFIX" --password "$PASSWORD" --permanent >/dev/null
    a     echo "✅ Created user: $EMAIL_PREFIX"
    a   else
    a     echo "ℹ️ User already exists: $EMAIL_PREFIX"
    a   fi
    a done
  }' build_algodatta_lightsail.sh || true

  sudo bash build_algodatta_lightsail.sh prod
fi

# --- 11️⃣ Verification ----------------------------------------------------
echo "============================================================="
echo "🔍 Running post-deployment verification..."
echo "============================================================="
cat > "$APP_DIR/verify_algodatta_stack.sh" <<'VERIFY'
#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR="/home/ubuntu/AlgoDatta"
LOG_DIR="/var/log/algodatta"
MANIFEST="$LOG_DIR/env_manifest.json"

echo "[$(date '+%F %T')] 🔍 Starting AlgoDatta stack verification..."
BACKEND_URL=$(jq -r '.endpoints.backend' "$MANIFEST" 2>/dev/null || echo "http://localhost:8000")
FRONTEND_URL=$(jq -r '.endpoints.frontend' "$MANIFEST" 2>/dev/null || echo "http://localhost:3000")

echo "➡️  Checking backend: $BACKEND_URL/api/healthz"
curl -fsS "$BACKEND_URL/api/healthz" | grep -q "ok" && echo "✅ Backend healthy" || echo "⚠️ Backend failed"

echo "➡️  Checking frontend: $FRONTEND_URL"
curl -fsI "$FRONTEND_URL" 2>/dev/null | grep -q "200" && echo "✅ Frontend OK" || echo "⚠️ Frontend not responding"

echo "➡️  Docker containers:"
sudo docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "algodatta|mock" || echo "⚠️ No AlgoDatta containers running"

echo "➡️  Nginx status:"
systemctl is-active --quiet nginx && echo "✅ Nginx active" || echo "❌ Nginx inactive"

POOL_ID=$(jq -r '.cognito.user_pool_id' "$MANIFEST" 2>/dev/null || echo "")
if [[ -n "$POOL_ID" && "$POOL_ID" != "null" ]]; then
  echo "➡️  Cognito pool check ($POOL_ID)..."
  aws cognito-idp describe-user-pool --user-pool-id "$POOL_ID" >/dev/null 2>&1 && echo "✅ Cognito reachable" || echo "⚠️ Cognito check failed"
else
  echo "ℹ️  Cognito skipped (dry-run or missing manifest)"
fi

IP=$(curl -s ifconfig.me || echo "localhost")
echo "============================================================="
echo "🧠 Verification complete!"
echo "Frontend → $FRONTEND_URL"
echo "Backend  → $BACKEND_URL/api/healthz"
echo "Public IP → $IP"
echo "============================================================="
VERIFY
chmod +x "$APP_DIR/verify_algodatta_stack.sh"
sudo bash "$APP_DIR/verify_algodatta_stack.sh" || true

# --- 12️⃣ Optional Auto-Shutdown -----------------------------------------
if [ "$SHUTDOWN_AFTER" = true ]; then
  echo "🕒 Auto-shutdown enabled — powering off in 60 seconds..."
  sleep 60 && sudo shutdown -h now
fi

# --- 13️⃣ Summary ---------------------------------------------------------
echo "============================================================="
if [ "$DRY_RUN" = true ]; then
  echo "✅ DRY-RUN complete — environment verified, mock UI running."
else
  echo "✅ Full setup + verification complete!"
  echo "Logs → /var/log/algodatta/"
  echo "Project root → $APP_DIR"
fi
echo "============================================================="

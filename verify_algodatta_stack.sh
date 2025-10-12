#!/usr/bin/env bash
# =============================================================
#  AlgoDatta Stack Verification Script
#  Checks backend, frontend, Cognito, Docker, Nginx, and manifest
# =============================================================
set -Eeuo pipefail
APP_DIR="/home/ubuntu/AlgoDatta"
LOG_DIR="/var/log/algodatta"
MANIFEST="$LOG_DIR/env_manifest.json"

echo "[$(date '+%F %T')] 🔍 Starting AlgoDatta stack verification..."

# --- 1️⃣ Health: Backend ---------------------------------------------------
BACKEND_URL=$(jq -r '.endpoints.backend' "$MANIFEST" 2>/dev/null || echo "http://localhost:8000")
echo "➡️  Checking backend health: $BACKEND_URL/api/healthz"
if curl -fsS "$BACKEND_URL/api/healthz" | grep -q "ok"; then
  echo "✅ Backend healthy"
else
  echo "❌ Backend failed or unreachable"
fi

# --- 2️⃣ Health: Frontend --------------------------------------------------
FRONTEND_URL=$(jq -r '.endpoints.frontend' "$MANIFEST" 2>/dev/null || echo "http://localhost:3000")
echo "➡️  Checking frontend: $FRONTEND_URL"
if curl -fsI "$FRONTEND_URL" | grep -q "200 OK"; then
  echo "✅ Frontend responding (200 OK)"
else
  echo "⚠️  Frontend not responding"
fi

# --- 3️⃣ Health: Docker ----------------------------------------------------
echo "➡️  Checking Docker containers..."
sudo docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "algodatta|mock" || echo "⚠️  No AlgoDatta containers running"

# --- 4️⃣ Health: Nginx -----------------------------------------------------
echo "➡️  Checking Nginx service..."
if systemctl is-active --quiet nginx; then
  echo "✅ Nginx active"
else
  echo "❌ Nginx inactive"
fi

# --- 5️⃣ Health: Cognito ---------------------------------------------------
POOL_ID=$(jq -r '.cognito.user_pool_id' "$MANIFEST" 2>/dev/null || echo "")
if [[ -n "$POOL_ID" && "$POOL_ID" != "null" ]]; then
  echo "➡️  Checking Cognito pool ($POOL_ID)..."
  aws cognito-idp describe-user-pool --user-pool-id "$POOL_ID" >/dev/null 2>&1 && echo "✅ Cognito Pool reachable" || echo "⚠️ Cognito unreachable"
else
  echo "ℹ️  Cognito details missing or DRY-RUN mode"
fi

# --- 6️⃣ Manifest Summary --------------------------------------------------
echo "➡️  Manifest summary:"
if [ -f "$MANIFEST" ]; then
  jq '{environment, cognito, endpoints}' "$MANIFEST"
else
  echo "⚠️ No manifest found ($MANIFEST)"
fi

# --- 7️⃣ Health: URLs ------------------------------------------------------
IP=$(curl -s ifconfig.me || echo "localhost")
echo "============================================================="
echo "🧠 Verification complete!"
echo "Frontend → $FRONTEND_URL"
echo "Backend  → $BACKEND_URL/api/healthz"
echo "Cognito Pool → $POOL_ID"
echo "Public IP → $IP"
echo "============================================================="

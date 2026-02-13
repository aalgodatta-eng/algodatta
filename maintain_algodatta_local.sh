#!/usr/bin/env bash
# =============================================================
# AlgoDatta Local Maintenance Script (v1.0-LF)
# Cleans duplicates + Rebuilds frontend + Starts backend/frontend
# =============================================================
set -Eeuo pipefail

LOG_DIR="/var/log/algodatta"
LOG_FILE="$LOG_DIR/maintain.log"

# --- 1️⃣ Ensure permissions ---------------------------------------------
if [[ ! -d "$LOG_DIR" ]]; then
  sudo mkdir -p "$LOG_DIR"
fi
if [[ ! -w "$LOG_DIR" ]]; then
  echo "🪄 Fixing log directory permissions..."
  sudo chown -R "$USER":"$USER" "$LOG_DIR"
  sudo chmod 755 "$LOG_DIR"
fi

echo "[$(date '+%F %T')] 🚀 Starting AlgoDatta local maintenance..." | tee -a "$LOG_FILE"

# --- 2️⃣ Fix duplicate Next.js pages ------------------------------------
if [[ ! -d "frontend" ]]; then
  echo "❌ Frontend directory not found!" | tee -a "$LOG_FILE"
  exit 1
fi

cd frontend || exit 1
echo "🧹 Cleaning duplicate JS/JSX files..." | tee -a "$LOG_FILE"

DUP_FILES=$(find app -type f \( -name "*.js" -o -name "*.jsx" \) \
  | while read -r js_file; do
      ts_file="${js_file%.js}.ts"
      tsx_file="${js_file%.jsx}.tsx"
      if [[ -f "$ts_file" || -f "$tsx_file" ]]; then
        echo "$js_file"
      fi
    done)

if [[ -z "$DUP_FILES" ]]; then
  echo "✅ No duplicate JS/TS files found." | tee -a "$LOG_FILE"
else
  echo "$DUP_FILES" | tee -a "$LOG_FILE"
  echo "$DUP_FILES" | xargs rm -fv | tee -a "$LOG_FILE"
  echo "✅ Cleanup complete." | tee -a "$LOG_FILE"
fi

# --- 3️⃣ Rebuild frontend -----------------------------------------------
echo "🧱 Rebuilding frontend..." | tee -a "$LOG_FILE"
npm install --silent
npm run build >/dev/null 2>&1 && echo "✅ Frontend build successful." | tee -a "$LOG_FILE"
cd ..

# --- 4️⃣ Start backend + frontend ---------------------------------------
BACKEND_PORT=8000
FRONTEND_PORT=3000

echo "🚀 Launching backend and frontend..." | tee -a "$LOG_FILE"

# stop any old ones
kill $(cat "$LOG_DIR"/backend.pid "$LOG_DIR"/frontend.pid 2>/dev/null || true) >/dev/null 2>&1 || true

# backend
if [[ -d backend ]]; then
  (
    cd backend
    if [[ -d venv ]]; then
      source venv/bin/activate
    fi
    nohup uvicorn app.main:app --reload --port ${BACKEND_PORT} >"$LOG_DIR/backend.log" 2>&1 &
    echo $! >"$LOG_DIR/backend.pid"
  )
  echo "✅ Backend started on port ${BACKEND_PORT}" | tee -a "$LOG_FILE"
else
  echo "⚠️ Backend directory missing." | tee -a "$LOG_FILE"
fi

# frontend
if [[ -d frontend ]]; then
  (
    cd frontend
    nohup npm run dev -- --port ${FRONTEND_PORT} >"$LOG_DIR/frontend.log" 2>&1 &
    echo $! >"$LOG_DIR/frontend.pid"
  )
  echo "✅ Frontend started on port ${FRONTEND_PORT}" | tee -a "$LOG_FILE"
else
  echo "⚠️ Frontend directory missing." | tee -a "$LOG_FILE"
fi

sleep 5

# --- 5️⃣ Health check ---------------------------------------------------
if curl -fsS "http://localhost:${BACKEND_PORT}/api/healthz" >/dev/null 2>&1; then
  echo "✅ Backend is up → http://localhost:${BACKEND_PORT}/api/docs" | tee -a "$LOG_FILE"
else
  echo "❌ Backend health check failed (see $LOG_DIR/backend.log)" | tee -a "$LOG_FILE"
fi

if curl -fsS "http://localhost:${FRONTEND_PORT}" >/dev/null 2>&1; then
  echo "✅ Frontend is up → http://localhost:${FRONTEND_PORT}" | tee -a "$LOG_FILE"
else
  echo "❌ Frontend health check failed (see $LOG_DIR/frontend.log)" | tee -a "$LOG_FILE"
fi

# --- 6️⃣ Done -----------------------------------------------------------
echo "-------------------------------------------------------------" | tee -a "$LOG_FILE"
echo "🎯 AlgoDatta local stack running" | tee -a "$LOG_FILE"
echo "🧠 Stop it anytime with: kill \$(cat $LOG_DIR/*.pid 2>/dev/null)" | tee -a "$LOG_FILE"
echo "📜 Log file: $LOG_FILE" | tee -a "$LOG_FILE"

#!/usr/bin/env bash
# =============================================================
# AlgoDatta Local Stack Starter
# Starts FastAPI backend + Next.js frontend with live logs
# =============================================================
set -Eeuo pipefail
LOG_DIR="/var/log/algodatta"
mkdir -p "$LOG_DIR"

BACKEND_PORT=8000
FRONTEND_PORT=3000

echo "[$(date '+%F %T')] 🚀 Starting AlgoDatta local environment..."
echo "-------------------------------------------------------------"
echo "Backend → http://localhost:${BACKEND_PORT}"
echo "Frontend → http://localhost:${FRONTEND_PORT}"
echo "Cognito Login Redirect → https://algodattalocal-1760333394.auth.ap-south-1.amazoncognito.com/login?client_id=uk8cvho0e5h6ke8jjig0vnrv5&response_type=code&scope=email+openid+profile&redirect_uri=http://localhost:3000/dashboard"
echo "-------------------------------------------------------------"

# --- Start Backend (FastAPI) ---------------------------------
if [[ -d backend ]]; then
  echo "🧱 Launching FastAPI backend..."
  (
    cd backend
    if [[ -d venv ]]; then
      source venv/bin/activate
    fi
    nohup uvicorn app.main:app --reload --port ${BACKEND_PORT} >"$LOG_DIR/backend.log" 2>&1 &
    echo $! >"$LOG_DIR/backend.pid"
  )
else
  echo "⚠️ Backend directory not found!"
fi

# --- Start Frontend (Next.js) --------------------------------
if [[ -d frontend ]]; then
  echo "🧩 Launching Next.js frontend..."
  (
    cd frontend
    if [[ ! -d node_modules ]]; then
      echo "📦 Installing frontend dependencies..."
      npm install --silent
    fi
    nohup npm run dev -- --port ${FRONTEND_PORT} >"$LOG_DIR/frontend.log" 2>&1 &
    echo $! >"$LOG_DIR/frontend.pid"
  )
else
  echo "⚠️ Frontend directory not found!"
fi

sleep 5

# --- Check health --------------------------------------------
echo "-------------------------------------------------------------"
if curl -fsS "http://localhost:${BACKEND_PORT}/api/healthz" >/dev/null 2>&1; then
  echo "✅ Backend is up at http://localhost:${BACKEND_PORT}/api/docs"
else
  echo "❌ Backend not responding (check $LOG_DIR/backend.log)"
fi

if curl -fsS "http://localhost:${FRONTEND_PORT}" >/dev/null 2>&1; then
  echo "✅ Frontend is up at http://localhost:${FRONTEND_PORT}"
else
  echo "❌ Frontend not responding (check $LOG_DIR/frontend.log)"
fi
echo "-------------------------------------------------------------"
echo "🧠 Use these commands to stop the stack:"
echo "   kill \$(cat $LOG_DIR/backend.pid $LOG_DIR/frontend.pid 2>/dev/null || true)"
echo "-------------------------------------------------------------"

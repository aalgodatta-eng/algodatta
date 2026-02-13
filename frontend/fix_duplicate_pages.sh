#!/usr/bin/env bash
# =============================================================
# AlgoDatta Fix Duplicate Pages (Next.js)
# v1.0 — Clean redundant .js/.jsx files & rebuild frontend
# =============================================================
set -Eeuo pipefail

LOG_DIR="/var/log/algodatta"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/fix_pages.log"

echo "[$(date '+%F %T')] 🚀 Starting duplicate page cleanup..." | tee -a "$LOG_FILE"

if [[ ! -d "frontend" ]]; then
  echo "❌ Frontend directory not found!" | tee -a "$LOG_FILE"
  exit 1
fi

cd frontend || exit 1

# --- Detect duplicates ---------------------------------------------------
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
  echo "⚙️ Removing duplicate JS/JSX files..." | tee -a "$LOG_FILE"
  echo "$DUP_FILES" | tee -a "$LOG_FILE"
  echo "$DUP_FILES" | xargs rm -fv | tee -a "$LOG_FILE"
  echo "✅ Cleanup complete." | tee -a "$LOG_FILE"
fi

# --- Rebuild the frontend ------------------------------------------------
echo "🧱 Rebuilding Next.js app..." | tee -a "$LOG_FILE"
npm install --silent
npm run build >/dev/null 2>&1 && echo "✅ Build successful." | tee -a "$LOG_FILE"

echo "[$(date '+%F %T')] 🧹 Duplicate cleanup done." | tee -a "$LOG_FILE"
echo "Logs saved at $LOG_FILE"

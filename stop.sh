#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(realpath "$0")")"

echo "🛑 Stopping AlgoDatta stack..."
docker compose down -v || true


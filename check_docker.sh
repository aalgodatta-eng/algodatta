#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(realpath "$0")")"

echo "🔍 Checking Docker & Compose setup..."
docker --version
docker compose version
docker ps >/dev/null && echo "✅ Docker daemon accessible"


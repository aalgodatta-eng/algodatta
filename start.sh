#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(realpath "$0")")"

echo "🚀 Starting AlgoDatta stack..."
docker compose up -d --build


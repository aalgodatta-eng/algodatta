#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(realpath "$0")")"

echo "ℹ️ Checking AlgoDatta stack status..."
docker compose ps


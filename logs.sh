#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(realpath "$0")")"

service="\${1:-all}"
if [ "$service" = "all" ]; then
  docker compose logs -f
else
  docker compose logs -f "$service"
fi


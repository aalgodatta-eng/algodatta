#!/usr/bin/env bash
set -euo pipefail

echo "🔍 Running Cognito sanity tests..."

echo "⏳ Backend health..."
if curl -s http://localhost:8000/api/healthz | grep -q '"status":"ok"'; then
  echo "✅ Backend health check passed"
else
  echo "❌ Backend not responding at http://localhost:8000/api/healthz"
  exit 1
fi

echo "⏳ Frontend root..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200"; then
  echo "✅ Frontend reachable at http://localhost:3000"
else
  echo "❌ Frontend not reachable"
  exit 1
fi

echo "⏳ Homepage content..."
if curl -s http://localhost:3000 | grep -q "AlgoDatta"; then
  echo "✅ Homepage rendered correctly"
else
  echo "❌ Homepage missing content"
  exit 1
fi

echo "⏳ Dashboard route exists..."
code="$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/dashboard)"
if [ "$code" = "200" ] || [ "$code" = "307" ] || [ "$code" = "308" ]; then
  echo "✅ Dashboard route returned HTTP $code (might require login cookie)"
else
  echo "❌ Dashboard route returned HTTP $code"
  exit 1
fi

echo "🎉 Cognito test script completed successfully"

#!/usr/bin/env bash
set -euo pipefail
echo "🔍 Running post-build tests..."

# wait a bit for containers
sleep 2

# backend health
if curl -s http://localhost:8000/api/healthz | grep -q '"status":"ok"'; then
  echo "✅ Backend ok"
else
  echo "❌ Backend health failed"
  exit 1
fi

# frontend up
if curl -s -o /dev/null -w "%{http_code}" http://localhost:3000 | grep -q "200"; then
  echo "✅ Frontend ok"
else
  echo "❌ Frontend not reachable"
  exit 1
fi

# root redirects to /login
code="$(curl -s -o /dev/null -w "%{http_code}" -I http://localhost:3000/)"
loc="$(curl -s -I http://localhost:3000/ | awk -F': ' '/^location:/I {print $2}' | tr -d '\r')"
if [[ "$code" =~ ^30[127]$ ]] && echo "$loc" | grep -qi "/login"; then
  echo "✅ / redirects to /login"
else
  echo "❌ / does not redirect to /login"
  exit 1
fi

# login page renders
if curl -s http://localhost:3000/login | grep -q "Login with Amazon Cognito"; then
  echo "✅ Login page ok"
else
  echo "❌ Login page check failed"
  exit 1
fi

# dashboard protected (should redirect when no cookie)
code2="$(curl -s -o /dev/null -w "%{http_code}" -I http://localhost:3000/dashboard)"
loc2="$(curl -s -I http://localhost:3000/dashboard | awk -F': ' '/^location:/I {print $2}' | tr -d '\r')"
if [[ "$code2" =~ ^30[127]$ ]] && echo "$loc2" | grep -qi "/login"; then
  echo "✅ /dashboard protected by middleware"
else
  echo "❌ /dashboard protection failed"
  exit 1
fi

echo "🎉 Tests complete (login flow then handled by Cognito Hosted UI)"

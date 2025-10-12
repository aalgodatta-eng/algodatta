#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/backend/.env"

if ! command -v aws &>/dev/null; then
  echo "⚠️ AWS CLI not installed, skipping Cognito seeding"
  exit 0
fi

# Ensure region configured
if ! aws configure get region >/dev/null 2>&1; then
  echo "⚠️ AWS region not configured; run: aws configure"
  exit 0
fi

echo "🌱 Seeding Cognito demo users..."

# Not all pools allow SignUp; use admin-create-user + set password
ensure_user () {
  local username="$1"
  local password="$2"

  if aws cognito-idp admin-get-user --user-pool-id "$USER_POOL_ID" --username "$username" >/dev/null 2>&1; then
    echo "ℹ️ User $username already exists, skipping create"
  else
    if ! aws cognito-idp admin-create-user \
        --user-pool-id "$USER_POOL_ID" \
        --username "$username" \
        --temporary-password "$password" \
        --message-action SUPPRESS >/dev/null 2>&1; then
      echo "⚠️ admin-create-user failed for $username, continuing"
    fi
  fi

  # Set/ensure permanent password
  if ! aws cognito-idp admin-set-user-password \
      --user-pool-id "$USER_POOL_ID" \
      --username "$username" \
      --password "$password" \
      --permanent >/dev/null 2>&1; then
    echo "⚠️ admin-set-user-password failed for $username, continuing"
  fi
  echo "✅ User $username ready"
}

ensure_user "admin2" "Admin234!"

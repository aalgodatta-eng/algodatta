#!/usr/bin/env bash
set -euo pipefail

# Check CLI
if ! command -v aws &>/dev/null; then
  echo "⚠️ AWS CLI not installed, skipping Cognito seeding"
  exit 0
fi

# Check configuration (region + creds)
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "⚠️ AWS credentials not configured. Run: aws configure"
  exit 0
fi

REGION="$(aws configure get region || echo "")"
if [ -z "$REGION" ]; then
  echo "⚠️ No default AWS region. Run: aws configure"
  exit 0
fi

# Load app envs
ENV_FILE="$(dirname "$0")/../backend/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "⚠️ Backend .env missing; cannot seed"
  exit 0
fi
# shellcheck disable=SC1090
source "$ENV_FILE"

USER_POOL_ID="${USER_POOL_ID:-}"
CLIENT_ID="${OIDC_CLIENT_ID:-}"
if [ -z "$USER_POOL_ID" ] || [ -z "$CLIENT_ID" ]; then
  echo "⚠️ USER_POOL_ID / OIDC_CLIENT_ID missing; cannot seed"
  exit 0
fi

USERNAME="admin1"
PASSWORD="Admin123!"
EMAIL="admin1@example.com"

echo "🌱 Seeding Cognito user: $USERNAME in $USER_POOL_ID ($REGION)"

# 1) Ensure user exists (admin-get-user returns nonzero if missing)
if aws cognito-idp admin-get-user --region "$REGION" --user-pool-id "$USER_POOL_ID" --username "$USERNAME" >/dev/null 2>&1; then
  echo "ℹ️ User $USERNAME already exists"
else
  echo "👉 Creating user $USERNAME (status: CONFIRMED)"
  # Create as admin to bypass signup-disabled pools
  aws cognito-idp admin-create-user \
    --region "$REGION" \
    --user-pool-id "$USER_POOL_ID" \
    --username "$USERNAME" \
    --user-attributes Name=email,Value="$EMAIL" Name=email_verified,Value=true \
    --message-action SUPPRESS >/dev/null

  # Set a permanent password that meets common policies (incl. symbol)
  if ! aws cognito-idp admin-set-user-password \
      --region "$REGION" \
      --user-pool-id "$USER_POOL_ID" \
      --username "$USERNAME" \
      --password "$PASSWORD" \
      --permanent >/dev/null 2>&1; then
    echo "⚠️ admin-set-user-password failed (policy mismatch?). Trying a stronger fallback..."
    PASSWORD="Admin123!@#"
    aws cognito-idp admin-set-user-password \
      --region "$REGION" \
      --user-pool-id "$USER_POOL_ID" \
      --username "$USERNAME" \
      --password "$PASSWORD" \
      --permanent >/dev/null
  fi
fi

# 2) Attempt to add to Admins group (ignore if group missing)
aws cognito-idp admin-add-user-to-group \
  --region "$REGION" \
  --user-pool-id "$USER_POOL_ID" \
  --username "$USERNAME" \
  --group-name "Admins" >/dev/null 2>&1 || true

echo "✅ Cognito seeding done (user: $USERNAME / password: $PASSWORD)"

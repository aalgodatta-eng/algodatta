#!/usr/bin/env bash
# =============================================================
#  AlgoDatta Full Bootstrap Script (Setup + Build)
#  Version: v4.0 - Lightsail Ubuntu 22.04
#  Author: AlgoDatta Automation
# =============================================================
set -Eeuo pipefail

echo "[$(date '+%F %T')] 🚀 Starting AlgoDatta full setup..."

# --- [STEP 1: Update System] ---------------------------------------------
echo "📦 Updating system packages..."
sudo apt-get update -y && sudo apt-get upgrade -y

# --- [STEP 2: Install Core Tools] ----------------------------------------
echo "🔧 Installing core tools (curl, unzip, jq, git, nginx)..."
sudo apt-get install -y curl unzip jq git nginx ca-certificates \
  apt-transport-https gnupg lsb-release software-properties-common

# --- [STEP 3: Install AWS CLI v2] ----------------------------------------
if ! command -v aws &>/dev/null; then
  echo "☁️ Installing AWS CLI v2..."
  cd /tmp
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -o awscliv2.zip >/dev/null
  sudo ./aws/install
  aws --version
else
  echo "✅ AWS CLI already installed"
fi

# --- [STEP 4: Install Terraform] -----------------------------------------
if ! command -v terraform &>/dev/null; then
  echo "🧱 Installing Terraform..."
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/hashicorp.list
  sudo apt-get update && sudo apt-get install -y terraform
  terraform -version
else
  echo "✅ Terraform already installed"
fi

# --- [STEP 5: Install Docker + Compose] ----------------------------------
if ! command -v docker &>/dev/null; then
  echo "🐳 Installing Docker Engine..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  sudo usermod -aG docker ubuntu
fi
if ! command -v docker-compose &>/dev/null; then
  echo "🐙 Installing Docker Compose..."
  sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi
sudo systemctl enable docker
sudo systemctl start docker
docker --version && docker-compose --version

# --- [STEP 6: Setup Directories] -----------------------------------------
APP_DIR="/home/ubuntu/AlgoDatta"
LOG_DIR="/var/log/algodatta"
mkdir -p "$APP_DIR" "$LOG_DIR"
chmod 755 "$APP_DIR" "$LOG_DIR"

# --- [STEP 7: Move Project Files] ----------------------------------------
echo "📁 Moving project files into $APP_DIR ..."
for f in awsInfo.json cognito_free_setup.json main.tf *.png *.zip build_algodatta_lightsail.sh; do
  [ -f "$f" ] && sudo mv -f "$f" "$APP_DIR"/
done

cd "$APP_DIR"
chmod +x build_algodatta_lightsail.sh || true

# --- [STEP 8: AWS CLI Configuration] -------------------------------------
if [ ! -f ~/.aws/credentials ]; then
  echo "🪣 AWS credentials not found — configuring now..."
  read -rp "Enter AWS Access Key ID: " AWS_ACCESS_KEY_ID
  read -rsp "Enter AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
  echo
  read -rp "Enter default region (e.g. ap-south-1): " AWS_REGION
  mkdir -p ~/.aws
  cat > ~/.aws/credentials <<CRED
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
CRED
  cat > ~/.aws/config <<CONF
[default]
region = ${AWS_REGION:-ap-south-1}
output = json
CONF
else
  echo "✅ AWS credentials already exist"
fi

# --- [STEP 9: Verify Installations] --------------------------------------
echo "🔍 Verifying core components..."
for cmd in aws terraform docker docker-compose jq nginx; do
  command -v $cmd >/dev/null 2>&1 || { echo "❌ Missing $cmd"; exit 1; }
done
echo "✅ All core components verified!"

# --- [STEP 🔟 Nginx Bootstrap] -------------------------------------------
sudo systemctl enable nginx
sudo systemctl start nginx
echo "🌐 Nginx service ready"

# --- [STEP 11: Auto-Run Build Script] ------------------------------------
echo "============================================================="
echo "🧠 Running AlgoDatta build script automatically..."
echo "============================================================="
cd "$APP_DIR"
sudo bash build_algodatta_lightsail.sh prod

# --- [STEP 12: Completion Summary] ---------------------------------------
echo "============================================================="
echo "✅ AlgoDatta setup + deployment complete!"
echo "🔍 Check logs: /var/log/algodatta/"
echo "📦 Project root: $APP_DIR"
echo "============================================================="

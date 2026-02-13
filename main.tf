terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1" # Mumbai region (you can change this)
}

# -------------------------
# Cognito User Pool
# -------------------------
resource "aws_cognito_user_pool" "algodatta_pool" {
  name = "AlgoDatta-FreePool"

  alias_attributes      = ["email"]
  username_attributes   = ["email"]
  auto_verified_attributes = ["email"]

  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }

  user_pool_add_ons {
    advanced_security_mode = "OFF"  # Keep this off to stay free
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    mutable             = true
    required            = true
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    mutable             = true
    required            = false
  }

  tags = {
    Project = "AlgoDatta"
    Tier    = "Free"
  }
}

# -------------------------
# App Client (Web App)
# -------------------------
resource "aws_cognito_user_pool_client" "algodatta_web_client" {
  name                                 = "AlgoDattaWebClient"
  user_pool_id                         = aws_cognito_user_pool.algodatta_pool.id
  generate_secret                      = false

  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  supported_identity_providers = ["COGNITO"]

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  callback_urls = [
    "https://www.algodatta.com/callback"
  ]

  logout_urls = [
    "https://www.algodatta.com/logout"
  ]
}

# -------------------------
# Hosted UI Domain
# -------------------------
resource "aws_cognito_user_pool_domain" "algodatta_domain" {
  domain       = "algodatta-free" # will become algodatta-free.auth.ap-south-1.amazoncognito.com
  user_pool_id = aws_cognito_user_pool.algodatta_pool.id
}

output "user_pool_id" {
  value = aws_cognito_user_pool.algodatta_pool.id
}

output "client_id" {
  value = aws_cognito_user_pool_client.algodatta_web_client.id
}

output "hosted_ui_url" {
  value = "https://${aws_cognito_user_pool_domain.algodatta_domain.domain}.auth.ap-south-1.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.algodatta_web_client.id}&response_type=code&scope=email+openid+profile&redirect_uri=https://www.algodatta.com/callback"
}
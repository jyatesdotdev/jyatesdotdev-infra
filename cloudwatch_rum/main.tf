resource "aws_cognito_identity_pool" "rum" {
  identity_pool_name               = "jyatesdotdev-rum"
  allow_unauthenticated_identities = true
  allow_classic_flow                = true
}

resource "aws_iam_role" "rum_unauth" {
  name = "jyatesdotdev-rum-unauth"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Federated = "cognito-identity.amazonaws.com" }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "cognito-identity.amazonaws.com:aud" = aws_cognito_identity_pool.rum.id
        }
        "ForAnyValue:StringLike" = {
          "cognito-identity.amazonaws.com:amr" = "unauthenticated"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "rum_put_events" {
  name = "rum-put-events"
  role = aws_iam_role.rum_unauth.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "rum:PutRumEvents"
      Resource = aws_rum_app_monitor.monitor.arn
    }]
  })
}

resource "aws_cognito_identity_pool_roles_attachment" "rum" {
  identity_pool_id = aws_cognito_identity_pool.rum.id

  roles = {
    unauthenticated = aws_iam_role.rum_unauth.arn
  }
}

resource "aws_rum_app_monitor" "monitor" {
  name   = "jyatesdotdev"
  domain = var.domain_name

  cw_log_enabled = true

  app_monitor_configuration {
    allow_cookies       = true
    enable_xray         = true
    session_sample_rate = 0.1
    telemetries         = ["errors", "performance", "http"]
    identity_pool_id    = aws_cognito_identity_pool.rum.id
    guest_role_arn      = aws_iam_role.rum_unauth.arn
  }
}

variable "domain_name" { type = string }

output "rum_id" { value = aws_rum_app_monitor.monitor.id }
output "rum_identity_pool_id" { value = aws_cognito_identity_pool.rum.id }

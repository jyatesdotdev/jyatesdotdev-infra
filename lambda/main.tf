resource "aws_iam_role" "lambda_exec" {
  name = "jyatesdotdev-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDB Access
resource "aws_iam_policy" "dynamodb_access" {
  name        = "jyatesdotdev-dynamodb-access"
  description = "IAM policy for DynamoDB access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ]
      Effect   = "Allow"
      Resource = [var.dynamodb_table_arn, "${var.dynamodb_table_arn}/index/GSI1"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

# SES Access
resource "aws_iam_policy" "ses_access" {
  name        = "jyatesdotdev-ses-access"
  description = "IAM policy for SES access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ]
      Effect   = "Allow"
      Resource = [
        "arn:aws:ses:${var.aws_region}:${var.account_id}:identity/${var.domain_name}",
        "arn:aws:ses:${var.aws_region}:${var.account_id}:identity/${var.ses_from_email}"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ses_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.ses_access.arn
}

# SSM Access for Authorizer Secrets
resource "aws_iam_policy" "ssm_access" {
  name        = "jyatesdotdev-ssm-access"
  description = "IAM policy for SSM access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "ssm:GetParameter"
      ]
      Effect   = "Allow"
      Resource = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/jyatesdotdev/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.ssm_access.arn
}

# SSM Parameters for Admin Credentials
resource "aws_ssm_parameter" "admin_username" {
  name  = "/jyatesdotdev/admin/username"
  type  = "String"
  value = var.admin_username
}

resource "aws_ssm_parameter" "admin_password" {
  name  = "/jyatesdotdev/admin/password"
  type  = "SecureString"
  value = var.admin_password
}

# Lambda Packaging removed (handled by API repository and uploaded to S3)

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "interactions" {
  name              = "/aws/lambda/jyatesdotdev-interactions"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

resource "aws_cloudwatch_log_group" "contact" {
  name              = "/aws/lambda/jyatesdotdev-contact"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

resource "aws_cloudwatch_log_group" "admin" {
  name              = "/aws/lambda/jyatesdotdev-admin"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

resource "aws_cloudwatch_log_group" "authorizer" {
  name              = "/aws/lambda/jyatesdotdev-authorizer"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

# Interactions Lambda
resource "aws_lambda_function" "interactions" {
  function_name = "jyatesdotdev-interactions"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  s3_bucket     = var.artifact_bucket
  s3_key        = var.interactions_lambda_key
  reserved_concurrent_executions = 5

  depends_on = [aws_cloudwatch_log_group.interactions]

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      DYNAMODB_TABLE_NAME  = var.dynamodb_table_name
      RECAPTCHA_SECRET_KEY = var.recaptcha_secret
    }
  }
}

# Contact Lambda
resource "aws_lambda_function" "contact" {
  function_name = "jyatesdotdev-contact"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  s3_bucket     = var.artifact_bucket
  s3_key        = var.contact_lambda_key
  reserved_concurrent_executions = 3

  depends_on = [aws_cloudwatch_log_group.contact]

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      SES_FROM_EMAIL       = var.ses_from_email
      SES_ADMIN_EMAIL      = var.ses_admin_email
      RECAPTCHA_SECRET_KEY = var.recaptcha_secret
    }
  }
}

# Admin Lambda
resource "aws_lambda_function" "admin" {
  function_name = "jyatesdotdev-admin"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  s3_bucket     = var.artifact_bucket
  s3_key        = var.admin_lambda_key
  reserved_concurrent_executions = 3

  depends_on = [aws_cloudwatch_log_group.admin]

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
    }
  }
}

# Authorizer Lambda
resource "aws_lambda_function" "authorizer" {
  function_name = "jyatesdotdev-authorizer"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  s3_bucket     = var.artifact_bucket
  s3_key        = var.authorizer_lambda_key
  reserved_concurrent_executions = 5

  depends_on = [aws_cloudwatch_log_group.authorizer]

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      ADMIN_USERNAME       = var.admin_username
      ADMIN_PASSWORD       = var.admin_password
      ADMIN_USERNAME_PARAM = aws_ssm_parameter.admin_username.name
      ADMIN_PASSWORD_PARAM = aws_ssm_parameter.admin_password.name
    }
  }
}

variable "aws_region" { type = string }
variable "account_id" { type = string }
variable "domain_name" { type = string }
variable "kms_key_arn" { type = string }
variable "dynamodb_table_name" { type = string }
variable "dynamodb_table_arn" { type = string }
variable "recaptcha_secret" { type = string }
variable "ses_from_email" { type = string }
variable "ses_admin_email" { type = string }
variable "admin_username" { type = string }
variable "admin_password" { type = string }


output "interactions_lambda_arn" { value = aws_lambda_function.interactions.arn }
output "interactions_lambda_name" { value = aws_lambda_function.interactions.function_name }
output "contact_lambda_arn" { value = aws_lambda_function.contact.arn }
output "admin_lambda_arn" { value = aws_lambda_function.admin.arn }
output "authorizer_lambda_arn" { value = aws_lambda_function.authorizer.arn }

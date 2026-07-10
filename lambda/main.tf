locals {
  lambda_functions   = toset(["interactions", "contact", "notifications", "admin", "authorizer"])
  dynamodb_functions = toset(["interactions", "contact", "notifications", "admin"])
  ses_functions      = toset(["interactions", "contact", "notifications"])
}

resource "aws_iam_role" "lambda_exec" {
  for_each = local.lambda_functions

  name = "jyatesdotdev-${each.key}-exec"

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
  for_each = local.lambda_functions

  role       = aws_iam_role.lambda_exec[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  for_each = local.lambda_functions

  role       = aws_iam_role.lambda_exec[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_policy" "authorizer_env_kms" {
  name        = "jyatesdotdev-authorizer-env-kms"
  description = "Decrypt the customer-managed Lambda environment for the authorizer"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = "kms:Decrypt"
      Effect   = "Allow"
      Resource = var.kms_key_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "authorizer_env_kms" {
  role       = aws_iam_role.lambda_exec["authorizer"].name
  policy_arn = aws_iam_policy.authorizer_env_kms.arn
}

# DynamoDB Access
resource "aws_iam_policy" "dynamodb_access" {
  name        = "jyatesdotdev-dynamodb-access"
  description = "IAM policy for DynamoDB access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:TransactWriteItems"
        ]
        Effect   = "Allow"
        Resource = [var.dynamodb_table_arn, "${var.dynamodb_table_arn}/index/GSI1"]
      },
      {
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = [var.kms_key_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb_access" {
  for_each = local.dynamodb_functions

  role       = aws_iam_role.lambda_exec[each.key].name
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
      Effect = "Allow"
      Resource = [
        "arn:aws:ses:${var.aws_region}:${var.account_id}:identity/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ses_access" {
  for_each = local.ses_functions

  role       = aws_iam_role.lambda_exec[each.key].name
  policy_arn = aws_iam_policy.ses_access.arn
}

resource "aws_iam_policy" "ses_contact_write_access" {
  name        = "jyatesdotdev-ses-contact-write-access"
  description = "Create and update confirmed subscriber preferences"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "ses:CreateContact",
        "ses:GetContact",
        "ses:UpdateContact",
      ]
      Effect   = "Allow"
      Resource = var.ses_contact_list_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ses_contact_write_access" {
  role       = aws_iam_role.lambda_exec["contact"].name
  policy_arn = aws_iam_policy.ses_contact_write_access.arn
}

resource "aws_iam_policy" "ses_contact_read_access" {
  name        = "jyatesdotdev-ses-contact-read-access"
  description = "List explicit topic subscribers for content delivery"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["ses:ListContacts"]
      Effect   = "Allow"
      Resource = var.ses_contact_list_arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ses_contact_read_access" {
  role       = aws_iam_role.lambda_exec["notifications"].name
  policy_arn = aws_iam_policy.ses_contact_read_access.arn
}

resource "aws_iam_policy" "notification_manifest_read" {
  name        = "jyatesdotdev-notification-manifest-read"
  description = "Read deploy-created notification manifests from the site bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:GetObject"]
      Effect   = "Allow"
      Resource = "arn:aws:s3:::${var.site_bucket_name}/notification-events/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "notification_manifest_read" {
  role       = aws_iam_role.lambda_exec["notifications"].name
  policy_arn = aws_iam_policy.notification_manifest_read.arn
}

resource "aws_sqs_queue" "notification_failures" {
  name                      = "jyatesdotdev-notification-failures"
  message_retention_seconds = 1209600
  kms_master_key_id         = var.kms_key_arn
}

resource "aws_iam_policy" "notification_failure_queue" {
  name        = "jyatesdotdev-notification-failure-queue"
  description = "Send exhausted asynchronous notification invocations to the failure queue"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["sqs:SendMessage"]
      Effect   = "Allow"
      Resource = aws_sqs_queue.notification_failures.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "notification_failure_queue" {
  role       = aws_iam_role.lambda_exec["notifications"].name
  policy_arn = aws_iam_policy.notification_failure_queue.arn
}

# SSM Parameters retain an operator-visible credential record. The authorizer
# receives the same values directly and does not need runtime SSM permissions.
resource "aws_ssm_parameter" "admin_username" {
  # checkov:skip=CKV2_AWS_34:The username is an identifier, not a secret.
  name  = "/jyatesdotdev/admin/username"
  type  = "String"
  value = var.admin_username
}

resource "aws_ssm_parameter" "admin_password" {
  name   = "/jyatesdotdev/admin/password"
  type   = "SecureString"
  value  = var.admin_password
  key_id = var.kms_key_arn
}

# Lambda Packaging removed (handled by API repository and uploaded to S3)

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "interactions" {
  # checkov:skip=CKV_AWS_338:Fourteen-day retention limits stored visitor data and cost.
  name              = "/aws/lambda/jyatesdotdev-interactions"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

resource "aws_cloudwatch_log_group" "contact" {
  # checkov:skip=CKV_AWS_338:Fourteen-day retention limits stored visitor data and cost.
  name              = "/aws/lambda/jyatesdotdev-contact"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

resource "aws_cloudwatch_log_group" "notifications" {
  # checkov:skip=CKV_AWS_338:Fourteen-day retention limits subscriber metadata exposure and cost.
  name              = "/aws/lambda/jyatesdotdev-notifications"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

resource "aws_cloudwatch_log_group" "admin" {
  # checkov:skip=CKV_AWS_338:Fourteen-day retention limits stored visitor data and cost.
  name              = "/aws/lambda/jyatesdotdev-admin"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

resource "aws_cloudwatch_log_group" "authorizer" {
  # checkov:skip=CKV_AWS_338:Fourteen-day retention limits stored visitor data and cost.
  name              = "/aws/lambda/jyatesdotdev-authorizer"
  retention_in_days = 14
  kms_key_id        = var.kms_key_arn
}

# Interactions Lambda
resource "aws_lambda_function" "interactions" {
  # checkov:skip=CKV_AWS_115:Regional quota cannot support per-function reservations.
  # checkov:skip=CKV_AWS_116:API Gateway invokes this function synchronously.
  # checkov:skip=CKV_AWS_117:The function has no private VPC dependencies.
  # checkov:skip=CKV_AWS_173:Environment values are non-secret and encrypted by Lambda at rest.
  # checkov:skip=CKV_AWS_272:OIDC CI publishes versioned artifacts to a private S3 bucket.
  function_name = "jyatesdotdev-interactions"
  role          = aws_iam_role.lambda_exec["interactions"].arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  s3_bucket     = var.artifact_bucket
  s3_key        = var.interactions_lambda_key
  timeout       = 10

  depends_on = [
    aws_cloudwatch_log_group.interactions,
    aws_iam_role_policy_attachment.lambda_logs["interactions"],
    aws_iam_role_policy_attachment.lambda_xray["interactions"],
    aws_iam_role_policy_attachment.dynamodb_access["interactions"],
    aws_iam_role_policy_attachment.ses_access["interactions"],
  ]

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = var.dynamodb_table_name
      SES_FROM_EMAIL      = var.ses_from_email
      SES_ADMIN_EMAIL     = var.ses_admin_email
      AUTO_APPROVE        = "true"
    }
  }
}

# Contact Lambda
resource "aws_lambda_function" "contact" {
  # checkov:skip=CKV_AWS_115:Regional quota cannot support per-function reservations.
  # checkov:skip=CKV_AWS_116:API Gateway invokes this function synchronously.
  # checkov:skip=CKV_AWS_117:The function has no private VPC dependencies.
  # checkov:skip=CKV_AWS_173:Environment values are non-secret and encrypted by Lambda at rest.
  # checkov:skip=CKV_AWS_272:OIDC CI publishes versioned artifacts to a private S3 bucket.
  function_name = "jyatesdotdev-contact"
  role          = aws_iam_role.lambda_exec["contact"].arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  s3_bucket     = var.artifact_bucket
  s3_key        = var.contact_lambda_key
  timeout       = 10

  depends_on = [
    aws_cloudwatch_log_group.contact,
    aws_iam_role_policy_attachment.lambda_logs["contact"],
    aws_iam_role_policy_attachment.lambda_xray["contact"],
    aws_iam_role_policy_attachment.dynamodb_access["contact"],
    aws_iam_role_policy_attachment.ses_access["contact"],
    aws_iam_role_policy_attachment.ses_contact_write_access,
  ]

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      DYNAMODB_TABLE_NAME   = var.dynamodb_table_name
      SES_FROM_EMAIL        = var.ses_from_email
      SES_ADMIN_EMAIL       = var.ses_admin_email
      SES_CONTACT_LIST_NAME = var.ses_contact_list_name
      SITE_URL              = var.site_url
    }
  }
}

# Content Notification Lambda
resource "aws_lambda_function" "notifications" {
  # checkov:skip=CKV_AWS_115:Regional quota cannot support per-function reservations.
  # checkov:skip=CKV_AWS_117:The function has no private VPC dependencies.
  # checkov:skip=CKV_AWS_173:Environment values are non-secret and encrypted by Lambda at rest.
  # checkov:skip=CKV_AWS_272:OIDC CI publishes versioned artifacts to a private S3 bucket.
  function_name = "jyatesdotdev-notifications"
  role          = aws_iam_role.lambda_exec["notifications"].arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  s3_bucket     = var.artifact_bucket
  s3_key        = var.notifications_lambda_key
  timeout       = 60

  depends_on = [
    aws_cloudwatch_log_group.notifications,
    aws_iam_role_policy_attachment.lambda_logs["notifications"],
    aws_iam_role_policy_attachment.lambda_xray["notifications"],
    aws_iam_role_policy_attachment.dynamodb_access["notifications"],
    aws_iam_role_policy_attachment.ses_access["notifications"],
    aws_iam_role_policy_attachment.ses_contact_read_access,
    aws_iam_role_policy_attachment.notification_manifest_read,
    aws_iam_role_policy_attachment.notification_failure_queue,
  ]

  tracing_config {
    mode = "Active"
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.notification_failures.arn
  }

  environment {
    variables = {
      DYNAMODB_TABLE_NAME   = var.dynamodb_table_name
      SES_FROM_EMAIL        = var.ses_from_email
      SES_ADMIN_EMAIL       = var.ses_admin_email
      SES_CONTACT_LIST_NAME = var.ses_contact_list_name
    }
  }
}

# Admin Lambda
resource "aws_lambda_function" "admin" {
  # checkov:skip=CKV_AWS_115:Regional quota cannot support per-function reservations.
  # checkov:skip=CKV_AWS_116:API Gateway invokes this function synchronously.
  # checkov:skip=CKV_AWS_117:The function has no private VPC dependencies.
  # checkov:skip=CKV_AWS_173:Environment values are non-secret and encrypted by Lambda at rest.
  # checkov:skip=CKV_AWS_272:OIDC CI publishes versioned artifacts to a private S3 bucket.
  function_name = "jyatesdotdev-admin"
  role          = aws_iam_role.lambda_exec["admin"].arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  s3_bucket     = var.artifact_bucket
  s3_key        = var.admin_lambda_key
  timeout       = 5

  depends_on = [
    aws_cloudwatch_log_group.admin,
    aws_iam_role_policy_attachment.lambda_logs["admin"],
    aws_iam_role_policy_attachment.lambda_xray["admin"],
    aws_iam_role_policy_attachment.dynamodb_access["admin"],
  ]

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
  # checkov:skip=CKV_AWS_115:Regional quota cannot support per-function reservations.
  # checkov:skip=CKV_AWS_116:API Gateway invokes this function synchronously.
  # checkov:skip=CKV_AWS_117:The function has no private VPC dependencies.
  # checkov:skip=CKV_AWS_272:OIDC CI publishes versioned artifacts to a private S3 bucket.
  function_name = "jyatesdotdev-authorizer"
  role          = aws_iam_role.lambda_exec["authorizer"].arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = ["arm64"]
  s3_bucket     = var.artifact_bucket
  s3_key        = var.authorizer_lambda_key
  timeout       = 3
  kms_key_arn   = var.kms_key_arn

  depends_on = [
    aws_cloudwatch_log_group.authorizer,
    aws_iam_role_policy_attachment.lambda_logs["authorizer"],
    aws_iam_role_policy_attachment.lambda_xray["authorizer"],
    aws_iam_role_policy_attachment.authorizer_env_kms,
  ]

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      ADMIN_USERNAME = var.admin_username
      ADMIN_PASSWORD = var.admin_password
    }
  }
}

variable "aws_region" { type = string }
variable "account_id" { type = string }
variable "kms_key_arn" { type = string }
variable "dynamodb_table_name" { type = string }
variable "dynamodb_table_arn" { type = string }
variable "ses_from_email" { type = string }
variable "ses_admin_email" { type = string }
variable "ses_contact_list_name" { type = string }
variable "ses_contact_list_arn" { type = string }
variable "site_url" { type = string }
variable "site_bucket_name" { type = string }
variable "admin_username" {
  type      = string
  sensitive = true
}
variable "admin_password" {
  type      = string
  sensitive = true
}
variable "artifact_bucket" { type = string }
variable "interactions_lambda_key" { type = string }
variable "contact_lambda_key" { type = string }
variable "notifications_lambda_key" { type = string }
variable "admin_lambda_key" { type = string }
variable "authorizer_lambda_key" { type = string }


output "interactions_lambda_arn" { value = aws_lambda_function.interactions.arn }
output "interactions_lambda_name" { value = aws_lambda_function.interactions.function_name }
output "contact_lambda_arn" { value = aws_lambda_function.contact.arn }
output "notifications_lambda_arn" { value = aws_lambda_function.notifications.arn }
output "notifications_lambda_name" { value = aws_lambda_function.notifications.function_name }
output "admin_lambda_arn" { value = aws_lambda_function.admin.arn }
output "authorizer_lambda_arn" { value = aws_lambda_function.authorizer.arn }

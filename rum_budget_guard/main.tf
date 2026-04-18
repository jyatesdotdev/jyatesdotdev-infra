data "aws_caller_identity" "current" {}

# Deny policy — attached by budget action, detached by monthly reset
resource "aws_iam_policy" "rum_deny" {
  name = "jyatesdotdev-rum-deny"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Deny"
      Action   = "rum:PutRumEvents"
      Resource = "*"
    }]
  })
}

# Budget scoped to CloudWatch RUM
resource "aws_budgets_budget" "rum" {
  name              = "jyatesdotdev-rum-guard"
  budget_type       = "COST"
  limit_amount      = var.monthly_limit
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-04-01_00:00"

  cost_filter {
    name   = "Service"
    values = ["Amazon CloudWatch RUM"]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.admin_email]
  }
}

# IAM role for Budgets to attach/detach policies
resource "aws_iam_role" "budget_action" {
  name = "jyatesdotdev-budget-action"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "budgets.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "budget_action" {
  name = "attach-rum-deny"
  role = aws_iam_role.budget_action.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
      Resource = var.rum_role_arn
      Condition = {
        ArnEquals = { "iam:PolicyArn" = aws_iam_policy.rum_deny.arn }
      }
    }]
  })
}

# Budget action — auto-attaches deny policy when limit exceeded
resource "aws_budgets_budget_action" "rum_kill" {
  budget_name        = aws_budgets_budget.rum.name
  action_type        = "APPLY_IAM_POLICY"
  approval_model     = "AUTOMATIC"
  notification_type  = "ACTUAL"
  execution_role_arn = aws_iam_role.budget_action.arn

  action_threshold {
    action_threshold_type  = "PERCENTAGE"
    action_threshold_value = 100
  }

  definition {
    iam_action_definition {
      policy_arn = aws_iam_policy.rum_deny.arn
      roles      = [var.rum_role_name]
    }
  }

  subscriber {
    subscription_type = "EMAIL"
    address           = var.admin_email
  }
}

# Lambda to detach deny policy on monthly reset
data "archive_file" "reset" {
  type        = "zip"
  output_path = "${path.module}/reset.zip"

  source {
    content  = <<-PY
      import boto3
      def handler(event, context):
          iam = boto3.client('iam')
          try:
              iam.detach_role_policy(
                  RoleName='${var.rum_role_name}',
                  PolicyArn='${aws_iam_policy.rum_deny.arn}'
              )
              print('Detached RUM deny policy')
          except iam.exceptions.NoSuchEntityException:
              print('Policy not attached, nothing to do')
    PY
    filename = "index.py"
  }
}

resource "aws_lambda_function" "reset" {
  function_name    = "jyatesdotdev-rum-budget-reset"
  filename         = data.archive_file.reset.output_path
  source_code_hash = data.archive_file.reset.output_base64sha256
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 10

  role = aws_iam_role.reset_lambda.arn
}

resource "aws_iam_role" "reset_lambda" {
  name = "jyatesdotdev-rum-reset-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "reset_lambda" {
  name = "detach-rum-deny"
  role = aws_iam_role.reset_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "iam:DetachRolePolicy"
        Resource = var.rum_role_arn
        Condition = {
          ArnEquals = { "iam:PolicyArn" = aws_iam_policy.rum_deny.arn }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# EventBridge: 1st of each month at midnight UTC
resource "aws_cloudwatch_event_rule" "monthly_reset" {
  name                = "jyatesdotdev-rum-monthly-reset"
  schedule_expression = "cron(0 0 1 * ? *)"
}

resource "aws_cloudwatch_event_target" "reset" {
  rule = aws_cloudwatch_event_rule.monthly_reset.name
  arn  = aws_lambda_function.reset.arn
}

resource "aws_lambda_permission" "eventbridge" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reset.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monthly_reset.arn
}

variable "rum_role_arn" { type = string }
variable "rum_role_name" { type = string }
variable "admin_email" { type = string }
variable "monthly_limit" { type = string }
variable "aws_region" { type = string }

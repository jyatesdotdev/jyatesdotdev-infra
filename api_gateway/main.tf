resource "aws_api_gateway_rest_api" "api" {
  name        = "jyatesdotdev-api"
  description = "API for jyates.dev"
}

resource "aws_api_gateway_resource" "api_root" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "v1" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.api_root.id
  path_part   = "v1"
}

# Authorizer
resource "aws_api_gateway_authorizer" "admin" {
  name                   = "admin-authorizer"
  rest_api_id            = aws_api_gateway_rest_api.api.id
  authorizer_uri         = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.authorizer_lambda_arn}/invocations"
  authorizer_result_ttl_in_seconds = 0
  type                   = "TOKEN"
}

# --- Comments ---
resource "aws_api_gateway_resource" "comments" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "comments"
}

# GET /comments
resource "aws_api_gateway_method" "get_comments" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.comments.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "get_comments" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.comments.id
  http_method = aws_api_gateway_method.get_comments.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.interactions_lambda_arn}/invocations"
}

# POST /comments
resource "aws_api_gateway_method" "post_comments" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.comments.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "post_comments" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.comments.id
  http_method = aws_api_gateway_method.post_comments.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.interactions_lambda_arn}/invocations"
}

# --- Comment Like ---
resource "aws_api_gateway_resource" "comment_id" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.comments.id
  path_part   = "{commentId}"
}

resource "aws_api_gateway_resource" "comment_like" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.comment_id.id
  path_part   = "like"
}

resource "aws_api_gateway_method" "post_comment_like" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.comment_like.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "post_comment_like" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.comment_like.id
  http_method = aws_api_gateway_method.post_comment_like.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.interactions_lambda_arn}/invocations"
}

# --- Likes ---
resource "aws_api_gateway_resource" "likes" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "likes"
}

resource "aws_api_gateway_method" "get_likes" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.likes.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "get_likes" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.likes.id
  http_method = aws_api_gateway_method.get_likes.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.interactions_lambda_arn}/invocations"
}

resource "aws_api_gateway_method" "post_likes" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.likes.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "post_likes" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.likes.id
  http_method = aws_api_gateway_method.post_likes.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.interactions_lambda_arn}/invocations"
}

# --- Contact ---
resource "aws_api_gateway_resource" "contact" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "contact"
}

resource "aws_api_gateway_method" "post_contact" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.contact.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "post_contact" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.contact.id
  http_method = aws_api_gateway_method.post_contact.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.contact_lambda_arn}/invocations"
}

# --- Admin ---
resource "aws_api_gateway_resource" "admin" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "admin"
}

resource "aws_api_gateway_resource" "admin_comments" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.admin.id
  path_part   = "comments"
}

# GET /admin/comments
resource "aws_api_gateway_method" "get_admin_comments" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.admin_comments.id
  http_method      = "GET"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.admin.id
  api_key_required = true
}

resource "aws_api_gateway_integration" "get_admin_comments" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.admin_comments.id
  http_method = aws_api_gateway_method.get_admin_comments.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.admin_lambda_arn}/invocations"
}

# PUT /admin/comments/{commentId}
resource "aws_api_gateway_resource" "admin_comment_id" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.admin_comments.id
  path_part   = "{commentId}"
}

resource "aws_api_gateway_method" "put_admin_comment" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.admin_comment_id.id
  http_method      = "PUT"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.admin.id
  api_key_required = true
}

resource "aws_api_gateway_integration" "put_admin_comment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.admin_comment_id.id
  http_method = aws_api_gateway_method.put_admin_comment.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.admin_lambda_arn}/invocations"
}

# DELETE /admin/comments/{commentId}
resource "aws_api_gateway_method" "delete_admin_comment" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.admin_comment_id.id
  http_method      = "DELETE"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.admin.id
  api_key_required = true
}

resource "aws_api_gateway_integration" "delete_admin_comment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.admin_comment_id.id
  http_method = aws_api_gateway_method.delete_admin_comment.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${var.admin_lambda_arn}/invocations"
}

# API Gateway Logging Role
resource "aws_iam_role" "apigw_cloudwatch" {
  name = "jyatesdotdev-apigw-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "apigateway.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apigw_cloudwatch" {
  role       = aws_iam_role.apigw_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "api" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch.arn
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/api-gateway/jyatesdotdev-api"
  retention_in_days = 7
  kms_key_id        = var.kms_key_arn
}

# Deployment
resource "aws_api_gateway_deployment" "api" {
  depends_on = [
    aws_api_gateway_integration.get_comments,
    aws_api_gateway_integration.post_comments,
    aws_api_gateway_integration.post_comment_like,
    aws_api_gateway_integration.get_likes,
    aws_api_gateway_integration.post_likes,
    aws_api_gateway_integration.post_contact,
    aws_api_gateway_integration.get_admin_comments,
    aws_api_gateway_integration.put_admin_comment,
    aws_api_gateway_integration.delete_admin_comment,
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "v1" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "v1"

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format          = "$context.identity.sourceIp $context.identity.caller $context.identity.user [$context.requestTime] \"$context.httpMethod $context.resourcePath $context.protocol\" $context.status $context.responseLength $context.requestId"
  }
}

# Apply global rate limit to entire API
resource "aws_api_gateway_method_settings" "global" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.v1.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = 20
    throttling_burst_limit = 40
  }
}

# Permissions for API Gateway to invoke Lambdas
resource "aws_lambda_permission" "apigw_interactions" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.interactions_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_contact" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.contact_lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_admin" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.admin_lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_authorizer" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.authorizer_lambda_arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

variable "aws_region" { type = string }
variable "interactions_lambda_arn" { type = string }
variable "interactions_lambda_name" { type = string }
variable "contact_lambda_arn" { type = string }
variable "admin_lambda_arn" { type = string }
variable "authorizer_lambda_arn" { type = string }
variable "kms_key_arn" { type = string }
variable "api_key" { type = string }

resource "aws_api_gateway_api_key" "cloudfront" {
  name  = "cloudfront-origin-key"
  value = var.api_key
}

resource "aws_api_gateway_usage_plan" "cloudfront" {
  name = "cloudfront-origin-plan"
  
  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_stage.v1.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "cloudfront" {
  key_id        = aws_api_gateway_api_key.cloudfront.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.cloudfront.id
}

output "api_endpoint" {
  value = aws_api_gateway_stage.v1.invoke_url
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "main" {
  description             = "KMS key for jyatesdotdev"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "main" {
  name          = "alias/jyatesdotdev"
  target_key_id = aws_kms_key.main.key_id
}

module "s3" {
  source                      = "./s3"
  bucket_name                 = "jyatesdotdev-static-site"
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
  kms_key_arn                 = aws_kms_key.main.arn
}

module "dynamodb" {
  source      = "./dynamodb"
  kms_key_arn = aws_kms_key.main.arn
}

module "lambda" {
  source              = "./lambda"
  aws_region          = var.aws_region
  account_id          = data.aws_caller_identity.current.account_id
  domain_name         = var.domain_name
  kms_key_arn         = aws_kms_key.main.arn
  dynamodb_table_name = module.dynamodb.table_name
  dynamodb_table_arn  = module.dynamodb.table_arn
  recaptcha_secret    = var.recaptcha_secret
  ses_from_email      = var.ses_from_email
  ses_admin_email     = var.ses_admin_email
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  artifact_bucket     = var.artifact_bucket
  interactions_lambda_key = var.interactions_lambda_key
  contact_lambda_key  = var.contact_lambda_key
  admin_lambda_key    = var.admin_lambda_key
  authorizer_lambda_key = var.authorizer_lambda_key
}

module "api_gateway" {
  source                   = "./api_gateway"
  aws_region               = var.aws_region
  interactions_lambda_arn  = module.lambda.interactions_lambda_arn
  interactions_lambda_name = module.lambda.interactions_lambda_name
  contact_lambda_arn       = module.lambda.contact_lambda_arn
  admin_lambda_arn         = module.lambda.admin_lambda_arn
  authorizer_lambda_arn    = module.lambda.authorizer_lambda_arn
  kms_key_arn              = aws_kms_key.main.arn
}

module "cloudfront" {
  source                  = "./cloudfront"
  domain_name             = var.domain_name
  alternative_domain_names = var.alternative_domain_names
  s3_bucket_domain_name   = module.s3.bucket_regional_domain_name
  s3_logging_bucket_domain_name = module.s3.logs_bucket_domain_name
  api_gateway_domain_name = replace(module.api_gateway.api_endpoint, "/^https?://([^/]+).*/", "$1")
  acm_certificate_arn     = aws_acm_certificate.cert.arn
  basic_auth_user         = var.admin_username
  basic_auth_password     = var.admin_password
}

module "ses" {
  source      = "./ses"
  domain_name = var.domain_name
  admin_email = var.ses_admin_email
}

module "cloudwatch_rum" {
  source      = "./cloudwatch_rum"
  domain_name = var.domain_name
}

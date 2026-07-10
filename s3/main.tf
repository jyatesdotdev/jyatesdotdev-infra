resource "aws_s3_bucket" "logs" {
  # checkov:skip=CKV2_AWS_62:Log delivery has no event-driven consumer.
  # checkov:skip=CKV_AWS_144:Cross-region replication is not justified for disposable logs.
  # checkov:skip=CKV_AWS_145:SSE-S3 is required for the combined S3 and legacy CloudFront log target.
  bucket = "${var.bucket_name}-logs"
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  # checkov:skip=CKV2_AWS_65:Legacy CloudFront standard logging requires bucket ACLs.
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs" {
  depends_on = [aws_s3_bucket_ownership_controls.logs]
  bucket     = aws_s3_bucket.logs.id
  acl        = "log-delivery-write"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      # S3 server access logging supports destination buckets encrypted with
      # SSE-S3, but not customer-managed KMS keys.
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "static_site" {
  # checkov:skip=CKV_AWS_144:Versioning and reproducible deployment provide recovery without replication.
  # checkov:skip=CKV_AWS_145:Public site assets use SSE-S3 to avoid unnecessary KMS cost.
  bucket = var.bucket_name
}

resource "aws_s3_bucket_website_configuration" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "static_site" {
  bucket = aws_s3_bucket.static_site.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "expire-notification-manifests"
    status = "Enabled"

    filter {
      prefix = "notification-events/"
    }

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_logging" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access-logs/"
}

resource "aws_s3_bucket_public_access_block" "static_site" {
  bucket = aws_s3_bucket.static_site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "static_site" {
  bucket = aws_s3_bucket.static_site.id
  policy = data.aws_iam_policy_document.static_site.json
}

data "aws_iam_policy_document" "static_site" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static_site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [var.cloudfront_distribution_arn]
    }
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.static_site.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [var.cloudfront_distribution_arn]
    }
  }
}

resource "aws_lambda_permission" "notifications_from_s3" {
  statement_id   = "AllowNotificationManifestsFromSiteBucket"
  action         = "lambda:InvokeFunction"
  function_name  = var.notifications_lambda_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.static_site.arn
  source_account = var.account_id
}

resource "aws_s3_bucket_notification" "notification_manifests" {
  bucket = aws_s3_bucket.static_site.id

  lambda_function {
    lambda_function_arn = var.notifications_lambda_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "notification-events/"
    filter_suffix       = ".json"
  }

  depends_on = [aws_lambda_permission.notifications_from_s3]
}

variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "The ARN of the CloudFront distribution"
  type        = string
}

variable "notifications_lambda_arn" {
  description = "ARN of the Lambda that delivers content update notifications"
  type        = string
}

variable "notifications_lambda_name" {
  description = "Name of the Lambda that delivers content update notifications"
  type        = string
}

variable "account_id" {
  description = "AWS account that owns both the site bucket and notification Lambda"
  type        = string
}

output "bucket_id" {
  value = aws_s3_bucket.static_site.id
}

output "bucket_arn" {
  value = aws_s3_bucket.static_site.arn
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.static_site.bucket_regional_domain_name
}

output "logs_bucket_domain_name" {
  value = aws_s3_bucket.logs.bucket_domain_name
}

output "bucket_website_endpoint" {
  value = aws_s3_bucket_website_configuration.static_site.website_endpoint
}

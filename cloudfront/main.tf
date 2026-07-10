terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "s3-oac"
  description                       = "OAC for S3 static site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Function for Basic Auth on /admin
resource "aws_cloudfront_function" "basic_auth" {
  name    = "basic-auth"
  runtime = "cloudfront-js-1.0"
  comment = "Basic Auth for /admin"
  publish = true
  code    = <<EOF
function handler(event) {
    var request = event.request;
    var headers = request.headers;

    // The authString is: Basic base64(user:password)
    var authString = 'Basic ${base64encode("${var.basic_auth_user}:${var.basic_auth_password}")}';

    if (request.uri.startsWith('/admin')) {
        if (typeof headers.authorization === 'undefined' || headers.authorization.value !== authString) {
            return {
                statusCode: 401,
                statusDescription: 'Unauthorized',
                headers: {
                    'www-authenticate': { value: 'Basic realm="Admin Area"' }
                }
            };
        }
    }

    return request;
}
EOF
}

# CloudFront Function for Subdomain Rewrite
resource "aws_cloudfront_function" "subdomain_rewrite" {
  name    = "subdomain-rewrite"
  runtime = "cloudfront-js-1.0"
  comment = "Rewrite blog.jyates.dev to /blog"
  publish = true
  code    = <<EOF
function handler(event) {
    var request = event.request;
    var host = request.headers.host.value;
    var uri = request.uri;

    if (host === 'blog.jyates.dev' && !uri.startsWith('/blog')) {
        uri = '/blog' + uri;
    }

    if (!uri.startsWith('/api/')) {
        if (uri.endsWith('/')) {
            uri += 'index.html';
        } else if (!uri.includes('.')) {
            uri += '/index.html';
        }
    }

    request.uri = uri;
    return request;
}
EOF
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name = "security-headers-policy"

  security_headers_config {
    content_security_policy {
      content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' https://*.amazonaws.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: https://*.amazonaws.com; connect-src 'self' https://*.amazonaws.com; frame-src 'self'; frame-ancestors 'none';"
      override                = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
      preload                    = true
    }
    xss_protection {
      mode_block = true
      override   = true
      protection = true
    }
  }
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

# Whitelists the CloudFront-Viewer-* geo headers so CloudFront generates them
# and forwards them to the API origin. CloudFront only generates these headers
# when a cache policy or origin request policy asks for them; putting them in
# the cache policy keeps the managed AllViewerExceptHostHeader origin request
# policy (forwarding the viewer Host header would break the API Gateway origin).
#
# CloudFront rejects header whitelisting when a cache policy has caching fully
# disabled (all TTLs 0), so max_ttl is 1. Caching stays effectively off:
# default_ttl is 0 and the API sends no Cache-Control, so nothing is cached.
resource "aws_cloudfront_cache_policy" "api_with_geo_headers" {
  name        = "api-geo-headers-no-cache"
  comment     = "Forwards CloudFront geo headers to the API origin; no effective caching"
  min_ttl     = 0
  default_ttl = 0
  max_ttl     = 1

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = false
    enable_accept_encoding_brotli = false

    headers_config {
      header_behavior = "whitelist"
      headers {
        items = [
          "CloudFront-Viewer-Country",
          "CloudFront-Viewer-Country-Name",
          "CloudFront-Viewer-City",
          "CloudFront-Viewer-Time-Zone",
          "CloudFront-Viewer-Latitude",
          "CloudFront-Viewer-Longitude",
          "CloudFront-Viewer-Address",
        ]
      }
    }

    cookies_config {
      cookie_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

resource "aws_cloudfront_distribution" "dist" {
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_100" # Only use North America and Europe edge locations (cheapest)
  default_root_object = "index.html"
  aliases             = concat([var.domain_name], var.alternative_domain_names)

  logging_config {
    include_cookies = false
    bucket          = var.s3_logging_bucket_domain_name
    prefix          = "cloudfront-logs/"
  }

  origin {
    domain_name              = var.s3_bucket_domain_name
    origin_id                = "S3-StaticSite"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  origin {
    domain_name = var.api_gateway_domain_name
    origin_id   = "APIGateway"
    origin_path = "/v1"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "x-api-key"
      value = var.api_key
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-StaticSite"

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.subdomain_rewrite.arn
    }

    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    viewer_protocol_policy     = "redirect-to-https"
  }

  # Cache behavior for /admin with Basic Auth
  ordered_cache_behavior {
    path_pattern     = "/admin*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-StaticSite"

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_disabled.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.basic_auth.arn
    }

    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    viewer_protocol_policy     = "redirect-to-https"
  }

  # Cache behavior for /api
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "APIGateway"

    cache_policy_id          = aws_cloudfront_cache_policy.api_with_geo_headers.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id

    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    viewer_protocol_policy     = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }
}

variable "domain_name" { type = string }
variable "alternative_domain_names" { type = list(string) }
variable "s3_bucket_domain_name" { type = string }
variable "s3_logging_bucket_domain_name" { type = string }
variable "api_gateway_domain_name" { type = string }
variable "acm_certificate_arn" { type = string }
variable "basic_auth_user" {
  type      = string
  sensitive = true
}
variable "basic_auth_password" {
  type      = string
  sensitive = true
}
variable "api_key" {
  type      = string
  sensitive = true
}

output "distribution_id" { value = aws_cloudfront_distribution.dist.id }
output "distribution_arn" { value = aws_cloudfront_distribution.dist.arn }
output "distribution_domain_name" { value = aws_cloudfront_distribution.dist.domain_name }

# Create the hosted zone (Terraform-managed, not imported)
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# Automatically update Name.com nameservers to point at this hosted zone
resource "namedotcom_domain_nameservers" "delegation" {
  domain_name = var.domain_name
  nameservers = aws_route53_zone.main.name_servers
}

# ACM Validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# CloudFront Alias
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.cloudfront.distribution_domain_name
    zone_id                = "Z2FDTNDATAQYW2" # Static CloudFront Zone ID
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "blog" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "blog.${var.domain_name}"
  type    = "A"

  alias {
    name                   = module.cloudfront.distribution_domain_name
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

# SES DKIM
resource "aws_route53_record" "ses_dkim" {
  count   = 3
  zone_id = aws_route53_zone.main.zone_id
  name    = "${module.ses.dkim_tokens[count.index]}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = "600"
  records = ["${module.ses.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# SES SPF (simplified)
resource "aws_route53_record" "ses_spf" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "TXT"
  ttl     = "600"
  records = ["v=spf1 include:amazonses.com ~all"]
}

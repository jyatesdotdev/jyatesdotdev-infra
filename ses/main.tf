resource "aws_ses_domain_identity" "domain" {
  domain = var.domain_name
}

resource "aws_ses_domain_dkim" "dkim" {
  domain = aws_ses_domain_identity.domain.domain
}

resource "aws_ses_email_identity" "admin" {
  email = var.admin_email
}

variable "domain_name" { type = string }
variable "admin_email" { type = string }

output "ses_domain_identity_arn" {
  value = aws_ses_domain_identity.domain.arn
}

output "dkim_tokens" {
  value = aws_ses_domain_dkim.dkim.dkim_tokens
}

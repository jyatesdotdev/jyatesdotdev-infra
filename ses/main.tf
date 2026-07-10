resource "aws_ses_domain_identity" "domain" {
  domain = var.domain_name
}

resource "aws_ses_domain_dkim" "dkim" {
  domain = aws_ses_domain_identity.domain.domain
}

resource "aws_ses_email_identity" "admin" {
  email = var.admin_email
}

resource "aws_sesv2_contact_list" "updates" {
  contact_list_name = "jyatesdotdev-updates"
  description       = "Confirmed subscribers to jyates.dev content updates"

  topic {
    topic_name                  = "blog"
    display_name                = "New blog posts"
    description                 = "Email when a new jyates.dev blog post is published."
    default_subscription_status = "OPT_OUT"
  }

  topic {
    topic_name                  = "projects"
    display_name                = "New projects"
    description                 = "Email when a new project is added to jyates.dev."
    default_subscription_status = "OPT_OUT"
  }
}

variable "domain_name" { type = string }
variable "admin_email" { type = string }
variable "aws_region" { type = string }

output "ses_domain_identity_arn" {
  value = aws_ses_domain_identity.domain.arn
}

output "dkim_tokens" {
  value = aws_ses_domain_dkim.dkim.dkim_tokens
}

output "contact_list_name" {
  value = aws_sesv2_contact_list.updates.contact_list_name
}

output "contact_list_arn" {
  value = "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:contact-list/${aws_sesv2_contact_list.updates.contact_list_name}"
}

data "aws_caller_identity" "current" {}

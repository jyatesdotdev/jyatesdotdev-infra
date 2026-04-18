variable "namedotcom_username" {
  description = "Name.com API username"
  type        = string
}

variable "namedotcom_token" {
  description = "Name.com API token"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "The AWS region to deploy resources into"
  type        = string
  default     = "us-west-2"
}

variable "domain_name" {
  description = "The primary domain name for the website"
  type        = string
  default     = "jyates.dev"
}

variable "alternative_domain_names" {
  description = "Alternative domain names for the website"
  type        = list(string)
  default     = ["blog.jyates.dev"]
}

variable "admin_username" {
  description = "Username for the admin area"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Password for the admin area"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ses_from_email" {
  description = "The email address to send emails from"
  type        = string
  default     = "blog@jyates.dev"
}

variable "ses_admin_email" {
  description = "The admin email address to receive notifications"
  type        = string
  default     = "me@jyates.dev"
}

variable "recaptcha_secret" {
  description = "The secret key for ReCAPTCHA v3"
  type        = string
  sensitive   = true
}

variable "artifact_bucket" {
  description = "The name of the S3 bucket containing Lambda artifacts"
  type        = string
  default     = ""
}

variable "interactions_lambda_key" {
  description = "S3 key for the interactions lambda zip"
  type        = string
  default     = ""
}

variable "contact_lambda_key" {
  description = "S3 key for the contact lambda zip"
  type        = string
  default     = ""
}

variable "admin_lambda_key" {
  description = "S3 key for the admin lambda zip"
  type        = string
  default     = ""
}

variable "authorizer_lambda_key" {
  description = "S3 key for the authorizer lambda zip"
  type        = string
  default     = ""
}

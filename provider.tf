terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    namedotcom = {
      source  = "lexfrei/namedotcom"
      version = "~> 2.2"
    }
  }
}

provider "namedotcom" {
  username = var.namedotcom_username
  token    = var.namedotcom_token
}

provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = var.terraform_role_arn
  }

  default_tags {
    tags = {
      Project   = "jyatesdotdev"
      ManagedBy = "Terraform"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  assume_role {
    role_arn = var.terraform_role_arn
  }

  default_tags {
    tags = {
      Project   = "jyatesdotdev"
      ManagedBy = "Terraform"
    }
  }
}

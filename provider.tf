terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
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

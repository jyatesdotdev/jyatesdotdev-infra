terraform {
  backend "s3" {
    bucket         = "jyatesdotdev-terraform-state"
    key            = "state/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}

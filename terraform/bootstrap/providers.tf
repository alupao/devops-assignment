provider "aws" {
  region              = var.aws_region
  profile             = var.aws_profile
  allowed_account_ids = [var.account_id]
}

data "aws_caller_identity" "current" {}

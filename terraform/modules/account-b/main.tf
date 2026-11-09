locals {
  tags = {
    Environment = "assignment"
    Owner       = var.owner
  }
  account_b_bucket_arn = aws_s3_bucket.role_c.arn
}

resource "aws_iam_role" "role_c" {
  provider = aws

  name        = "roleC"
  description = "Full access to one Account B bucket; trusted only to Account A roleB."
  tags        = local.tags
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = var.role_b_arn }
    }]
  })
}

resource "aws_iam_role_policy" "role_c_permissions" {
  provider = aws

  name = "roleC-single-bucket-access"
  role = aws_iam_role.role_c.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:*"
      Resource = [local.account_b_bucket_arn, "${local.account_b_bucket_arn}/*"]
    }]
  })
}

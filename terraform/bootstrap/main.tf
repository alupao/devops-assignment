locals {
  bucket_name = coalesce(var.bucket_name, "devops-assignment-state-${data.aws_caller_identity.current.account_id}-${var.aws_region}")
  state_keys = [
    "assignment/bootstrap/terraform.tfstate",
    "assignment/deployment/terraform.tfstate",
  ]
  tags = {
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_s3_bucket" "state" {
  bucket        = local.bucket_name
  force_destroy = false
  tags          = merge(local.tags, { Name = local.bucket_name })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_dynamodb_table" "lock" {
  name                        = var.lock_table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "LockID"
  deletion_protection_enabled = true
  tags                        = merge(local.tags, { Name = var.lock_table_name })

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}

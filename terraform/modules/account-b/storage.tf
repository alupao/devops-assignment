resource "aws_s3_bucket" "role_c" {
  bucket        = "${var.name_prefix}-${var.account_b_id}-${var.aws_region}-rolec"
  force_destroy = false
  tags          = local.tags
}

resource "aws_s3_bucket_versioning" "role_c" {
  bucket = aws_s3_bucket.role_c.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "role_c" {
  bucket = aws_s3_bucket.role_c.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "role_c" {
  bucket                  = aws_s3_bucket.role_c.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "role_c" {
  bucket = aws_s3_bucket.role_c.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.role_c.arn, "${aws_s3_bucket.role_c.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

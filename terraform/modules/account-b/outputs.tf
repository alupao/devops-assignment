output "role_c_arn" {
  description = "Account B roleC ARN used by Account A's caller-side permission policy."
  value       = aws_iam_role.role_c.arn
}

output "bucket_name" {
  description = "Dedicated Account B bucket, separate from any pre-existing bucket."
  value       = aws_s3_bucket.role_c.bucket
}

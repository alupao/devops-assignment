output "backend_access_policy_json" {
  description = "Backend-only identity policy for bootstrap and deployment state; attach separately to an authorized operator role."
  value = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListStatePaths"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.state.arn
      },
      {
        Sid      = "ReadWriteState"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = [for key in local.state_keys : "${aws_s3_bucket.state.arn}/${key}"]
      },
      {
        Sid      = "ManageStateLocks"
        Effect   = "Allow"
        Action   = ["dynamodb:DescribeTable", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = aws_dynamodb_table.lock.arn
      },
    ]
  })
}

output "bootstrap_backend_config" {
  description = "Backend settings for migrating bootstrap state after creating the backend resources."
  value = {
    bucket         = aws_s3_bucket.state.bucket
    key            = "assignment/bootstrap/terraform.tfstate"
    profile        = var.aws_profile
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.lock.name
    encrypt        = true
  }
}

output "deployment_backend_config" {
  description = "Backend settings for the single two-account deployment root."
  value = {
    bucket         = aws_s3_bucket.state.bucket
    key            = "assignment/deployment/terraform.tfstate"
    profile        = var.aws_profile
    region         = var.aws_region
    dynamodb_table = aws_dynamodb_table.lock.name
    encrypt        = true
  }
}

output "bootstrap_backend_hcl" {
  description = "Ready-to-write backend.hcl for the bootstrap root; contains a profile name, not credentials."
  value       = <<-EOT
    bucket = "${aws_s3_bucket.state.bucket}"
    key = "assignment/bootstrap/terraform.tfstate"
    region = "${var.aws_region}"
    dynamodb_table = "${aws_dynamodb_table.lock.name}"
    profile = "${var.aws_profile}"
  EOT
}

output "deployment_backend_hcl" {
  description = "Ready-to-write backend.hcl for the deployment root; contains a profile name, not credentials."
  value       = <<-EOT
    bucket = "${aws_s3_bucket.state.bucket}"
    key = "assignment/deployment/terraform.tfstate"
    region = "${var.aws_region}"
    dynamodb_table = "${aws_dynamodb_table.lock.name}"
    profile = "${var.aws_profile}"
  EOT
}

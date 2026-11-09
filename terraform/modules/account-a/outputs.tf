output "console_sign_in_url" {
  description = "Account A sign-in URL for alice and bob; group1 users have no login profiles."
  value       = "https://${var.account_a_id}.signin.aws.amazon.com/console/"
}

output "encrypted_credentials" {
  description = "PGP-encrypted assignment credentials plus public access-key IDs. Decrypt offline with the corresponding recipient's private key; never commit decrypted values."
  sensitive   = true
  value = {
    for name, key in aws_iam_access_key.programmatic : name => {
      access_key_id              = key.id
      encrypted_secret           = key.encrypted_secret
      encrypted_console_password = try(aws_iam_user_login_profile.human[name].encrypted_password, null)
    }
  }
}

output "role_a_arn" {
  description = "Account A administrative role ARN."
  value       = aws_iam_role.role_a.arn
}

output "role_b_arn" {
  description = "Account A roleB ARN used as Account B's exact trusted principal."
  value       = aws_iam_role.role_b.arn
}

output "instance_ids" {
  description = "Instance name to EC2 ID."
  value       = module.ec2.instance_ids
}

output "private_ips" {
  description = "Instance name to private IP address."
  value       = module.ec2.private_ips
}

output "selected_ami_id" {
  description = "Resolved Amazon Linux AMI; pin ami_id after review to avoid unexpected AMI drift."
  value       = data.aws_ami.selected.id
}
output "keypair_files" {
  description = "Private key filenames only; no private key content is output."
  value       = { for name in keys(var.instances) : name => local_sensitive_file.private_key[name].filename }
}
output "ci_targets" {
  description = "Native resource identifiers for the CI pipeline."
  value = {
    repository_arn   = aws_ecr_repository.ci.arn
    repository_url   = aws_ecr_repository.ci.repository_url
    cluster_arn      = aws_ecs_cluster.ci.arn
    service_arn      = aws_ecs_service.ci.arn
    service_name     = aws_ecs_service.ci.name
    task_family_arn  = aws_ecs_task_definition.ci.arn_without_revision
    artifacts_bucket = aws_s3_bucket.artifacts.bucket
  }
}
output "task_definition_template" {
  description = "Untagged task-definition input for the narrowly scoped CI registration permission."
  value = {
    family                  = aws_ecs_task_definition.ci.family
    requiresCompatibilities = aws_ecs_task_definition.ci.requires_compatibilities
    networkMode             = aws_ecs_task_definition.ci.network_mode
    cpu                     = aws_ecs_task_definition.ci.cpu
    memory                  = aws_ecs_task_definition.ci.memory
    executionRoleArn        = aws_iam_role.ecs_execution.arn
    taskRoleArn             = aws_iam_role.ecs_task.arn
    containerDefinitions    = jsondecode(aws_ecs_task_definition.ci.container_definitions)
  }
}

output "ci_policy_json" {
  description = "Rendered Task 4 JSON with native resource ARNs."
  value       = aws_iam_user_policy.ci_pipeline.policy
}

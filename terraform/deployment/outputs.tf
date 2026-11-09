output "instance_ids" {
  description = "Account A instance name to EC2 ID."
  value       = module.account_a.instance_ids
}

output "private_ips" {
  description = "Account A instance name to private IP address."
  value       = module.account_a.private_ips
}

output "console_sign_in_url" {
  description = "Account A sign-in URL for alice and bob."
  value       = module.account_a.console_sign_in_url
}

output "encrypted_credentials" {
  description = "PGP-encrypted Account A credentials; deliver and decrypt securely offline."
  sensitive   = true
  value       = module.account_a.encrypted_credentials
}

output "role_arns" {
  description = "Account A roleA/roleB and Account B roleC ARNs."
  value = {
    roleA = module.account_a.role_a_arn
    roleB = module.account_a.role_b_arn
    roleC = module.account_b.role_c_arn
  }
}

output "account_ids" {
  description = "Account IDs discovered from the two authenticated providers."
  value       = { account_a = data.aws_caller_identity.account_a.account_id, account_b = data.aws_caller_identity.account_b.account_id }
}
output "selected_ami_id" {
  description = "Resolved AMI; copy into ami_id to pin future deployments."
  value       = module.account_a.selected_ami_id
}
output "keypair_files" {
  description = "Local private-key paths only, never private key material."
  value       = module.account_a.keypair_files
}
output "ci_targets" {
  description = "Resolved CI deployment targets."
  value       = module.account_a.ci_targets
}
output "task_definition_template" {
  description = "CI registration input; update its container image before registering a release."
  value       = module.account_a.task_definition_template
}
output "account_b_bucket_name" {
  description = "Dedicated bucket to which roleC has full access."
  value       = module.account_b.bucket_name
}

output "ci_policy_json" {
  description = "Rendered custom CI identity policy JSON for inspection or export."
  value       = module.account_a.ci_policy_json
}

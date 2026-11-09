variable "account_a_id" {
  description = "Expected Account A ID, independently checked against the selected profile."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_a_id))
    error_message = "account_a_id must contain exactly 12 digits."
  }
}

variable "account_a_profile" {
  description = "Configured AWS CLI profile authorized to provision networking, EC2, IAM, S3, ECR, ECS and logs in Account A."
  type        = string
  nullable    = false

  validation {
    condition     = trimspace(var.account_a_profile) != ""
    error_message = "account_a_profile must not be empty."
  }
}

variable "account_b_id" {
  description = "Expected Account B ID; it must differ from Account A."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_b_id)) && var.account_b_id != var.account_a_id
    error_message = "account_b_id must contain 12 digits and identify a different account."
  }
}

variable "account_b_profile" {
  description = "Configured AWS CLI profile authorized to provision IAM and S3 resources in Account B."
  type        = string
  nullable    = false

  validation {
    condition     = trimspace(var.account_b_profile) != ""
    error_message = "account_b_profile must not be empty."
  }
}

variable "aws_region" {
  description = "AWS provider Region for these commercial-partition accounts."
  type        = string
  default     = "ap-south-1"
  nullable    = false

  validation {
    condition     = trimspace(var.aws_region) != ""
    error_message = "aws_region must not be empty."
  }
}

variable "owner" {
  description = "Owner tag for users and roles created by this assignment."
  type        = string
  nullable    = false

  validation {
    condition     = trimspace(var.owner) != ""
    error_message = "owner must not be empty."
  }
}

variable "user_pgp_keys" {
  description = "Base64-encoded binary PGP public keys for engine, ci, alice, and bob. Never supply private keys."
  type        = map(string)
  nullable    = false

  validation {
    condition     = toset(keys(var.user_pgp_keys)) == toset(["engine", "ci", "alice", "bob"])
    error_message = "Provide a PGP public key for exactly engine, ci, alice, and bob."
  }

  validation {
    condition     = alltrue([for key in values(var.user_pgp_keys) : can(regex("^[A-Za-z0-9+/]+={0,2}$", key))])
    error_message = "PGP values must be nonempty base64-encoded public keys, not file paths, private keys, or Keybase lookups."
  }
}

variable "name_prefix" {
  description = "Prefix for assignment-owned resources; account IDs and Region make bucket names unique."
  type        = string
  default     = "devops-assignment"
  nullable    = false
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3–24 lowercase letters, digits or hyphens."
  }
}

variable "ami_id" {
  description = "Optional pinned Amazon Linux x86_64 AMI; null resolves the public AL2023 SSM parameter."
  type        = string
  default     = null
}

variable "instances" {
  description = "Five-instance map; validated by the reusable module."
  type = map(object({
    instance_type    = string
    root_volume_type = string
    root_volume_size = number
    root_iops        = optional(number)
    environment      = string
    owner            = string
    protected        = optional(bool, false)
  }))
  validation {
    condition     = alltrue([for name in keys(var.instances) : can(regex("^[a-z][a-z0-9_-]{0,31}$", name))])
    error_message = "Instance names must be safe filenames: lowercase letters, digits, underscores or hyphens."
  }
}

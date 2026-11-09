variable "aws_region" {
  description = "AWS Region for both the state bucket and lock table."
  type        = string
  nullable    = false

  validation {
    condition     = trimspace(var.aws_region) != ""
    error_message = "aws_region must not be empty."
  }
}

variable "bucket_name" {
  default     = null
  description = "Optional state bucket name; null derives a unique name from account and Region."
  type        = string
  nullable    = true

  validation {
    condition     = var.bucket_name == null ? true : length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63 && can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name))
    error_message = "Use 3–63 lowercase letters, digits, or hyphens, starting and ending with a letter or digit."
  }
}

variable "environment" {
  description = "Environment tag for shared state infrastructure."
  type        = string
  default     = "assignment"
  nullable    = false

  validation {
    condition     = trimspace(var.environment) != ""
    error_message = "environment must not be empty."
  }
}

variable "lock_table_name" {
  description = "DynamoDB table name used by Terraform for state locking."
  type        = string
  default     = "devops-assignment-state-lock"
  nullable    = false

  validation {
    condition     = length(var.lock_table_name) >= 3 && length(var.lock_table_name) <= 255 && can(regex("^[A-Za-z0-9_.-]+$", var.lock_table_name))
    error_message = "Use 3–255 letters, digits, underscores, periods, or hyphens for lock_table_name."
  }
}

variable "owner" {
  description = "Owner tag for the state bucket and locking table."
  type        = string
  nullable    = false

  validation {
    condition     = trimspace(var.owner) != ""
    error_message = "owner must not be empty."
  }
}

variable "aws_profile" {
  description = "Configured AWS CLI profile authorized to create and manage the state bucket and lock table."
  type        = string
  nullable    = false
  validation {
    condition     = trimspace(var.aws_profile) != ""
    error_message = "aws_profile must not be empty."
  }
}
variable "account_id" {
  description = "Expected backend-owner account ID, checked independently of provider discovery."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must contain 12 digits."
  }
}

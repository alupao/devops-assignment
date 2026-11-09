variable "account_b_id" {
  description = "Actual Account B ID discovered by the deployment root."
  type        = string
}
variable "aws_region" {
  description = "Region for the dedicated Account B bucket."
  type        = string
}
variable "name_prefix" {
  description = "Prefix for assignment-owned resources."
  type        = string
}
variable "owner" {
  description = "Owner tag for Account B resources."
  type        = string
}
variable "role_b_arn" {
  description = "Actual Account A roleB ARN supplied by the deployment root."
  type        = string
}

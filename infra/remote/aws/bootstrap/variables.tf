variable "aws_region" {
  type        = string
  description = "AWS region for provider operations."
  default     = "us-east-1"
}

variable "trusted_principal_arns" {
  type        = list(string)
  description = "IAM principal ARNs allowed to assume the Terraform execution roles."
}

variable "dev_role_name" {
  type        = string
  description = "Role name for Terraform dev execution."
  default     = "TerraformExecutionRoleDev"
}

variable "prod_role_name" {
  type        = string
  description = "Role name for Terraform prod execution."
  default     = "TerraformExecutionRoleProd"
}

variable "managed_policy_arns" {
  type        = list(string)
  description = "Managed policy ARNs attached to both execution roles."
  default = [
    "arn:aws:iam::aws:policy/AdministratorAccess",
  ]
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to created IAM roles."
  default = {
    ManagedBy = "Terraform"
    Project   = "snowflake-costs-performance-ai-pipeline"
    Layer     = "bootstrap"
  }
}

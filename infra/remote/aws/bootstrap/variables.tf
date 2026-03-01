variable "aws_region" {
  type        = string
  description = "AWS region for provider operations."
  default     = "us-east-1"
}

variable "trusted_principal_arns" {
  type        = list(string)
  description = "IAM principal ARNs allowed to assume the Terraform execution roles."
}

variable "enable_github_oidc" {
  type        = bool
  description = "Enable GitHub OIDC trust for Terraform execution roles."
  default     = false
}

variable "github_oidc_provider_arn" {
  type        = string
  description = "Existing GitHub OIDC provider ARN. If empty and enable_github_oidc=true, provider is created."
  default     = ""
}

variable "github_repository" {
  type        = string
  description = "GitHub repository in owner/repo format."
  default     = ""
}

variable "github_ref_patterns" {
  type        = list(string)
  description = "Allowed git refs for GitHub OIDC trust."
  default     = ["refs/heads/main"]
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

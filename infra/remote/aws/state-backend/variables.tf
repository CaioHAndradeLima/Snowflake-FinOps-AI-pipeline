variable "aws_region" {
  type        = string
  description = "AWS region for Terraform backend resources."
  default     = "us-east-1"
}

variable "bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name for Terraform state."
}

variable "dynamodb_table_name" {
  type        = string
  description = "DynamoDB table name for state locking."
  default     = "terraform-state-locks"
}

variable "force_destroy" {
  type        = bool
  description = "Allow bucket destroy even if not empty."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to backend resources."
  default = {
    ManagedBy = "Terraform"
    Layer     = "state-backend"
  }
}

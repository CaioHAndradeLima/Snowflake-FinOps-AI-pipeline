variable "bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for bucket encryption."
}

variable "force_destroy" {
  type        = bool
  description = "Allow Terraform to delete non-empty bucket."
  default     = false
}

variable "versioning_status" {
  type        = string
  description = "Bucket versioning status."
  default     = "Enabled"
}

variable "transition_to_ia_days" {
  type        = number
  description = "Days before objects transition to STANDARD_IA."
  default     = 30
}

variable "expire_after_days" {
  type        = number
  description = "Days before objects expire."
  default     = 365
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the bucket."
  default     = {}
}

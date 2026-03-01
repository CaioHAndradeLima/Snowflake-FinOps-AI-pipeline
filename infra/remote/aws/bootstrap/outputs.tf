output "terraform_execution_role_dev_arn" {
  description = "ARN for the dev Terraform execution role."
  value       = aws_iam_role.terraform_execution_dev.arn
}

output "terraform_execution_role_prod_arn" {
  description = "ARN for the prod Terraform execution role."
  value       = aws_iam_role.terraform_execution_prod.arn
}

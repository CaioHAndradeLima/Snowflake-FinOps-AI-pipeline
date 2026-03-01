output "role_name" {
  description = "Snowflake integration role name."
  value       = aws_iam_role.this.name
}

output "role_arn" {
  description = "Snowflake integration role ARN."
  value       = aws_iam_role.this.arn
}

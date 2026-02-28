provider "snowflake" {
  account  = local.effective_snowflake_account
  user     = var.snowflake_user
  password = var.snowflake_password
  role     = var.snowflake_role
}

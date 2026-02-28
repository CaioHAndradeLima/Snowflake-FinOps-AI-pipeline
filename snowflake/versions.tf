terraform {
  required_version = ">= 1.5, < 1.6"

  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.90"
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "bronze_usage" {
  privileges        = ["USAGE"]
  account_role_name = var.snowflake_role

  on_schema {
    schema_name = "\"${snowflake_database.weather_analytics.name}\".\"${snowflake_schema.bronze.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "bronze_create_table" {
  privileges        = ["CREATE TABLE"]
  account_role_name = var.snowflake_role

  on_schema {
    schema_name = "\"${snowflake_database.weather_analytics.name}\".\"${snowflake_schema.bronze.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "weather_wh_usage" {
  privileges        = ["USAGE"]
  account_role_name = var.snowflake_role

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = "\"${snowflake_warehouse.weather_wh.name}\""
  }

  depends_on = [
    snowflake_warehouse.weather_wh
  ]
}

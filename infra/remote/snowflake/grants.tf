resource "snowflake_grant_privileges_to_account_role" "bronze_usage" {
  privileges        = ["USAGE"]
  account_role_name = local.role_name

  on_schema {
    schema_name = "\"${snowflake_database.sentinel.name}\".\"${snowflake_schema.bronze.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "bronze_create_table" {
  privileges        = ["CREATE TABLE"]
  account_role_name = local.role_name

  on_schema {
    schema_name = "\"${snowflake_database.sentinel.name}\".\"${snowflake_schema.bronze.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "silver_usage" {
  privileges        = ["USAGE"]
  account_role_name = local.role_name

  on_schema {
    schema_name = "\"${snowflake_database.sentinel.name}\".\"${snowflake_schema.silver.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "gold_usage" {
  privileges        = ["USAGE"]
  account_role_name = local.role_name

  on_schema {
    schema_name = "\"${snowflake_database.sentinel.name}\".\"${snowflake_schema.gold.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "warehouse_usage" {
  privileges        = ["USAGE"]
  account_role_name = local.role_name

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = "\"${snowflake_warehouse.sentinel_wh.name}\""
  }
}

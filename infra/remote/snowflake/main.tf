resource "snowflake_database" "sentinel" {
  name = local.database_name
}

resource "snowflake_schema" "bronze" {
  database = snowflake_database.sentinel.name
  name     = "BRONZE"
}

resource "snowflake_schema" "silver" {
  database = snowflake_database.sentinel.name
  name     = "SILVER"
}

resource "snowflake_schema" "gold" {
  database = snowflake_database.sentinel.name
  name     = "GOLD"
}

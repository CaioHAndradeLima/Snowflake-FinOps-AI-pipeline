resource "snowflake_database" "weather_analytics" {
  name = "WEATHER_ANALYTICS"
}

resource "snowflake_schema" "bronze" {
  database = snowflake_database.weather_analytics.name
  name     = "BRONZE"
}

resource "snowflake_schema" "silver" {
  database = snowflake_database.weather_analytics.name
  name     = "SILVER"
}

resource "snowflake_schema" "gold" {
  database = snowflake_database.weather_analytics.name
  name     = "GOLD"
}
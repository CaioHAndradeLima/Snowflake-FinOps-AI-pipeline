
resource "snowflake_warehouse" "weather_wh" {
  name           = "WEATHER_WH"
  warehouse_size = "XSMALL"

  auto_suspend = 60
  auto_resume  = true

  initially_suspended = true

  comment = "Warehouse for weather data pipeline (ingestion + analytics)"
}
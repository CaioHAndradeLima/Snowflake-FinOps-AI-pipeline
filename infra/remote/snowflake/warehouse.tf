resource "snowflake_warehouse" "sentinel_wh" {
  name           = local.warehouse_name
  warehouse_size = var.warehouse_size

  auto_suspend = 60
  auto_resume  = true

  initially_suspended = true

  comment = "Warehouse for Snowflake Sentinel ingestion and analytics."
}

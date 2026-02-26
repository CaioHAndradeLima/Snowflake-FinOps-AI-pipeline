locals {
  name_suffix = var.environment == "dev" ? "_DEV" : ""

  database_name  = "${var.base_database_name}${local.name_suffix}"
  warehouse_name = "${var.base_warehouse_name}${local.name_suffix}"
  role_name      = var.environment == "dev" ? var.dev_role_name : var.base_role_name
}

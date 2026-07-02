# Core resource group
resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = var.region
}

# Any global locals or data sources could go here
locals {
  name_prefix    = lower("${var.solution}-${var.env}")
  compact_prefix = lower(replace("${var.solution}${var.env}", "-", ""))

  resource_group_name = "rg-${local.name_prefix}"

  storage_account_name   = substr("${local.compact_prefix}stor01", 0, 24)
  postgres_server_name   = substr("${local.compact_prefix}psql01", 0, 63)
  redis_name             = "${local.name_prefix}-redis"
  aca_environment_name   = "${local.name_prefix}-aca-env"
  aca_log_analytics_name = "${local.name_prefix}-logs"

  keyvault_name          = substr("${local.compact_prefix}kv01", 0, 24)
  keyvault_identity_name = "${local.name_prefix}-kv-reader-id"

  foundry_account_name         = substr("${local.compact_prefix}foundry01", 0, 64)
  foundry_custom_subdomain     = substr("${local.compact_prefix}foundry01", 0, 64)
  foundry_project_name         = "${local.name_prefix}-project"
  foundry_project_display_name = "${upper(var.solution)} ${upper(var.env)} Project"

  common_tags = {
    Environment = upper(var.env)
    Project     = upper(var.solution)
    ManagedBy   = "Terraform"
  }
} 
data "azurerm_client_config" "current" {}

resource "azurerm_user_assigned_identity" "keyvault_secret_reader" {
  name                = local.keyvault_identity_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_key_vault" "dify" {
  name                = local.keyvault_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # User requested no private endpoint integration for Key Vault.
  public_network_access_enabled = true

  soft_delete_retention_days = 7

  tags = local.common_tags
}

resource "azurerm_key_vault_access_policy" "deployer" {
  key_vault_id = azurerm_key_vault.dify.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Restore",
  ]
}

resource "azurerm_key_vault_access_policy" "keyvault_secret_reader" {
  key_vault_id = azurerm_key_vault.dify.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.keyvault_secret_reader.principal_id

  secret_permissions = [
    "Get",
    "List",
  ]
}

resource "azurerm_key_vault_secret" "dify_secret_key" {
  name         = "dify-secret-key"
  key_vault_id = azurerm_key_vault.dify.id
  value        = local.dify_secret_key_value

  depends_on = [azurerm_key_vault_access_policy.deployer]
}

resource "azurerm_key_vault_secret" "dify_plugin_daemon_key" {
  name         = "dify-plugin-daemon-key"
  key_vault_id = azurerm_key_vault.dify.id
  value        = local.dify_plugin_daemon_key_value

  depends_on = [azurerm_key_vault_access_policy.deployer]
}

resource "azurerm_key_vault_secret" "dify_inner_api_key" {
  name         = "dify-inner-api-key"
  key_vault_id = azurerm_key_vault.dify.id
  value        = local.dify_inner_api_key_value

  depends_on = [azurerm_key_vault_access_policy.deployer]
}

resource "azurerm_key_vault_secret" "dify_sandbox_api_key" {
  name         = "dify-sandbox-api-key"
  key_vault_id = azurerm_key_vault.dify.id
  value        = local.dify_sandbox_api_key_value

  depends_on = [azurerm_key_vault_access_policy.deployer]
}

resource "azurerm_key_vault_secret" "dify_agent_api_token" {
  name         = "dify-agent-api-token"
  key_vault_id = azurerm_key_vault.dify.id
  value        = local.dify_agent_api_token_value

  depends_on = [azurerm_key_vault_access_policy.deployer]
}

resource "azurerm_key_vault_secret" "dify_agent_server_secret_key" {
  name         = "dify-agent-server-secret-key"
  key_vault_id = azurerm_key_vault.dify.id
  value        = local.dify_agent_server_secret_key_value

  depends_on = [azurerm_key_vault_access_policy.deployer]
}

resource "azurerm_key_vault_secret" "dify_agent_shellctl_auth_token" {
  name         = "dify-agent-shellctl-auth-token"
  key_vault_id = azurerm_key_vault.dify.id
  value        = local.dify_agent_shellctl_auth_token_value

  depends_on = [azurerm_key_vault_access_policy.deployer]
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-password"
  key_vault_id = azurerm_key_vault.dify.id
  value        = local.pgsql_admin_password_value

  depends_on = [azurerm_key_vault_access_policy.deployer]
}

resource "azurerm_key_vault_secret" "redis_primary_key" {
  name         = "redis-primary-key"
  key_vault_id = azurerm_key_vault.dify.id
  value        = azurerm_redis_cache.redis.primary_access_key

  depends_on = [azurerm_key_vault_access_policy.deployer]
}

resource "azurerm_key_vault_secret" "storage_account_key" {
  name         = "storage-account-key"
  key_vault_id = azurerm_key_vault.dify.id
  value        = azurerm_storage_account.acafileshare.primary_access_key

  depends_on = [azurerm_key_vault_access_policy.deployer]
}

output "keyvault_id" {
  description = "Azure Key Vault resource ID"
  value       = azurerm_key_vault.dify.id
}

output "keyvault_name" {
  description = "Azure Key Vault name"
  value       = azurerm_key_vault.dify.name
}

output "keyvault_secret_reader_identity_id" {
  description = "User-assigned identity ID for Key Vault secret reading"
  value       = azurerm_user_assigned_identity.keyvault_secret_reader.id
}

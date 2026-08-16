resource "azurerm_cognitive_account" "foundry" {
  name                = local.foundry_account_name
  location            = var.foundry-region
  resource_group_name = azurerm_resource_group.rg.name

  kind                          = "AIServices"
  sku_name                      = "S0"
  project_management_enabled    = true
  custom_subdomain_name         = local.foundry_custom_subdomain
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

resource "azurerm_cognitive_account_project" "foundry_project" {
  name                 = local.foundry_project_name
  cognitive_account_id = azurerm_cognitive_account.foundry.id
  location             = var.foundry-region
  description          = "Dify project in Azure AI Foundry"
  display_name         = local.foundry_project_display_name

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

resource "azurerm_role_assignment" "keyvault_secret_reader_cognitive_user" {
  count                = var.enable_foundry_role_assignment ? 1 : 0
  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_user_assigned_identity.keyvault_secret_reader.principal_id
}

output "foundry_account_id" {
  description = "Azure AI Foundry account resource ID"
  value       = azurerm_cognitive_account.foundry.id
}

output "foundry_account_endpoint" {
  description = "Azure AI Foundry account endpoint"
  value       = azurerm_cognitive_account.foundry.endpoint
}

output "foundry_project_id" {
  description = "Azure AI Foundry project resource ID"
  value       = azurerm_cognitive_account_project.foundry_project.id
}

output "foundry_project_endpoints" {
  description = "Azure AI Foundry project endpoints"
  value       = azurerm_cognitive_account_project.foundry_project.endpoints
}

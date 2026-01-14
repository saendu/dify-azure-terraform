# Core resource group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.group-name}"
  location = var.region
}

# Any global locals or data sources could go here
locals {
  common_tags = {
    Environment = "Development"
    Project     = "Dify"
    ManagedBy   = "Terraform"
  }
} 
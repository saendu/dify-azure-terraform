terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.79"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

}

# Configure the Microsoft Azure Provider
provider "azurerm" {

  subscription_id = var.subscription-id
  features {}
}


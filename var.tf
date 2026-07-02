################################################################################
# Azure Subscription & Resource Group
################################################################################

variable "subscription-id" {
  description = "Azure subscription ID"
  type        = string
  default     = "<SubscriptionID>"
}

variable "solution" {
  description = "Solution short name used in generated resource names"
  type        = string
  default     = "dify"
}

variable "env" {
  description = "Environment short name used in generated resource names"
  type        = string
  default     = "dev"
}

################################################################################
# Virtual Network Configuration
################################################################################

variable "region" {
  description = "Azure region for deployment"
  type        = string
  default     = "switzerlandnorth"
}

variable "ip-prefix" {
  description = "IP prefix for VNET (first two octets)"
  type        = string
  default     = "10.99"
}

################################################################################
# PostgreSQL Configuration
################################################################################

variable "pgsql-user" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "difyadmin"
}

################################################################################
# Dify Container Images (Dify 1.14.0)
################################################################################

variable "dify-api-image" {
  description = "Dify API container image"
  type        = string
  default     = "langgenius/dify-api:1.14.0"
}

variable "dify-sandbox-image" {
  description = "Dify sandbox container image"
  type        = string
  default     = "langgenius/dify-sandbox:0.2.15"
}

variable "dify-web-image" {
  description = "Dify web frontend container image"
  type        = string
  default     = "langgenius/dify-web:1.14.0"
}

variable "dify-plugin-daemon-image" {
  description = "Dify plugin daemon container image"
  type        = string
  default     = "langgenius/dify-plugin-daemon:0.6.0-local"
}



################################################################################
# Azure AI Foundry (Cognitive Account + Project)
################################################################################

variable "foundry-region" {
  description = "Azure region for Foundry resources (can differ from core region)"
  type        = string
  default     = "westeurope"
}

variable "enable_foundry_role_assignment" {
  description = "Whether Terraform should create the Foundry Cognitive Services User role assignment for the keyvault reader identity. Requires roleAssignments/write permission."
  type        = bool
  default     = false
}


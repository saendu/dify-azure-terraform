################################################################################
# Azure Subscription & Resource Group
################################################################################

variable "subscription-id" {
  description = "Azure subscription ID"
  type        = string
  default     = "b41f99a1-c79c-41eb-8bdf-8a27f63ceae6"
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
# Dify Container Images (Dify 1.16.1)
################################################################################

variable "dify-api-image" {
  description = "Dify API container image"
  type        = string
  default     = "langgenius/dify-api:1.16.1"
}

variable "dify-sandbox-image" {
  description = "Dify sandbox container image"
  type        = string
  default     = "langgenius/dify-sandbox:0.2.15"
}

variable "dify-web-image" {
  description = "Dify web frontend container image"
  type        = string
  default     = "langgenius/dify-web:1.16.1"
}

variable "dify-plugin-daemon-image" {
  description = "Dify plugin daemon container image"
  type        = string
  default     = "langgenius/dify-plugin-daemon:0.6.3-local"
}

variable "dify-agent-backend-image" {
  description = "Dify Agent v2 backend container image"
  type        = string
  default     = "langgenius/dify-agent-backend:1.16.1"
}

variable "dify-agent-local-sandbox-image" {
  description = "Dify Agent v2 local shell sandbox container image"
  type        = string
  default     = "langgenius/dify-agent-local-sandbox:1.16.1"
}

variable "enable-dify-agent-v2" {
  description = "Enable the Dify Agent v2 experience in the web UI while retaining classic Agent support"
  type        = bool
  default     = true
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

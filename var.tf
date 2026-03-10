################################################################################
# Azure Subscription & Resource Group
################################################################################

variable "subscription-id" {
  description = "Azure subscription ID"
  type        = string
  default     = "76958d76-d94f-402b-a86b-fc6a720a2ba8"
}

variable "group-name" {
  description = "Resource group name prefix"
  type        = string
  default     = "dify-ina-latest"
  type = string
  default = "b41f99a1-c79c-41eb-8bdf-8a27f63ceae6"
}

variable "group-name" {
  type = string
  default = "dify-lab"
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
# Storage Configuration
################################################################################

variable "storage-account" {
  description = "Storage account name for file shares and blob storage"
  type        = string
  default     = "labdifystorage"
}

variable "storage-account-container" {
  description = "Blob container name for Dify files"
  type        = string
  default     = "dfy"
}

################################################################################
# Redis Configuration
################################################################################

variable "redis" {
  type = string
  default = "labdifyredis"
}

################################################################################
# PostgreSQL Configuration
################################################################################

variable "psql-flexible" {
  description = "PostgreSQL flexible server name"
  type        = string
  default     = "labdifypsql"
}

variable "pgsql-user" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "difyadmin"
}

variable "pgsql-password" {
  description = "PostgreSQL administrator password (CHANGE THIS!)"
  type        = string
  sensitive   = true
  # No default - must be provided at deployment time
}

################################################################################
# Azure Container Apps Configuration
################################################################################

variable "aca-env" {
  description = "Container Apps environment name"
  type        = string
  default     = "dify-lab-env"
}

variable "aca-loga" {
  description = "Log Analytics workspace name"
  type        = string
  default     = "dify-loga"
}

variable "aca-dify-customer-domain" {
  description = "Custom domain for Dify application"
  type        = string
  default     = "agents.innoarchitects.ch"
}

################################################################################
# Dify Container Images (Dify 1.11.3)
################################################################################

variable "dify-api-image" {
  description = "Dify API container image"
  type        = string
  default     = "langgenius/dify-api:1.11.3"
}

variable "dify-sandbox-image" {
  description = "Dify sandbox container image"
  type        = string
  default     = "langgenius/dify-sandbox:0.2.12"
}

variable "dify-web-image" {
  description = "Dify web frontend container image"
  type        = string
  default     = "langgenius/dify-web:1.11.3"
}

variable "dify-plugin-daemon-image" {
  description = "Dify plugin daemon container image"
  type        = string
  default     = "langgenius/dify-plugin-daemon:0.5.2-local"
}

################################################################################
# Dify Security Configuration (CHANGE THESE IN PRODUCTION!)
################################################################################

variable "dify-secret-key" {
  description = "Secret key for Dify API encryption. Generate with: openssl rand -base64 42"
  type        = string
  sensitive   = true
  default     = "sk-9f73s3ljTXVcMT3Blb3ljTqtsKiGHXVcMT3BlbkFJLK7U"
}

variable "dify-plugin-daemon-key" {
  description = "Plugin daemon authentication key"
  type        = string
  sensitive   = true
  default     = "lYkiYYT6owG+71oLerGzA7GXCgOT++6ovaezWAjpCjf+Sjc3ZtU+qUEi"
}

variable "dify-inner-api-key" {
  description = "Internal API key for plugin communication"
  type        = string
  sensitive   = true
  default     = "QaHbTe77CtuXmsfyhR7+vRjI/+XbV1AaFy691iy+kGDv2Jvy0/eAh8Y1"
}

variable "dify-sandbox-api-key" {
  description = "API key for sandbox code execution"
  type        = string
  sensitive   = true
  default     = "dify-sandbox"
}


################################################################################
# Azure Subscription & Resource Group
################################################################################

variable "subscription-id" {
  description = "Azure subscription ID"
  type        = string
  default     = "<SubscriptionID>"
}

variable "group-name" {
  description = "Resource group name prefix"
  type        = string
  default     = "dify-lab"
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
  type    = string
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
  description = "PostgreSQL administrator password (CHANGE THIS! See README.md)"
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

################################################################################
# Dify Container Images (Dify 1.16.0-rc1)
################################################################################

variable "dify-api-image" {
  description = "Dify API container image"
  type        = string
  default     = "langgenius/dify-api:1.16.0-rc1"
}

variable "dify-sandbox-image" {
  description = "Dify sandbox container image"
  type        = string
  default     = "langgenius/dify-sandbox:0.2.15"
}

variable "dify-web-image" {
  description = "Dify web frontend container image"
  type        = string
  default     = "langgenius/dify-web:1.16.0-rc1"
}

variable "dify-plugin-daemon-image" {
  description = "Dify plugin daemon container image"
  type        = string
  default     = "langgenius/dify-plugin-daemon:0.6.3-local"
}

variable "dify-agent-backend-image" {
  description = "Dify Agent backend container image (experimental, new in 1.16.0)"
  type        = string
  default     = "langgenius/dify-agent-backend:1.16.0-rc1"
}

variable "dify-agent-local-sandbox-image" {
  description = "Dify Agent local sandbox (shellctl) container image (experimental, new in 1.16.0)"
  type        = string
  default     = "langgenius/dify-agent-local-sandbox:1.16.0-rc1"
}

################################################################################
# Dify Security Configuration
#
# WARNING: The defaults below are obvious placeholders. They MUST be replaced
# in `terraform.tfvars` (or via TF_VAR_* env vars) before any non-lab use.
# Generate strong values with: openssl rand -base64 42
################################################################################

variable "dify-secret-key" {
  description = "Secret key for Dify API encryption. REPLACE before deploying. Generate with: openssl rand -base64 42"
  type        = string
  sensitive   = true
  default     = "replace-me-dify-secret-key-generate-with-openssl-rand-base64-42"
}

variable "dify-plugin-daemon-key" {
  description = "Plugin daemon authentication key. REPLACE before deploying. Generate with: openssl rand -base64 42"
  type        = string
  sensitive   = true
  default     = "replace-me-dify-plugin-daemon-secret-generate-with-openssl-rand-base64-42"
}

variable "dify-inner-api-key" {
  description = "Internal API key for plugin <-> API communication. REPLACE before deploying. Generate with: openssl rand -base64 42"
  type        = string
  sensitive   = true
  default     = "replace-me-dify-inner-api-secret-generate-with-openssl-rand-base64-42"
}

variable "dify-sandbox-api-key" {
  description = "API key for sandbox code execution. REPLACE before deploying. Generate with: openssl rand -base64 42"
  type        = string
  sensitive   = true
  default     = "replace-me-dify-sandbox-api-secret-generate-with-openssl-rand-base64-42"
}

################################################################################
# Dify Agent Configuration (New in 1.16.0-rc1 - Experimental)
#
# WARNING: The Dify Agent feature is experimental. All agents share one sandbox.
# Only provide agent services to trusted, non-malicious users.
################################################################################

variable "dify-agent-server-secret-key" {
  description = "JWE encryption key for Agent Stub bearer tokens. REPLACE before deploying. Generate with: python -c 'import secrets; print(secrets.token_urlsafe(32))'"
  type        = string
  sensitive   = true
  default     = "replace-me-dify-agent-server-secret-key"
}

variable "dify-agent-shellctl-auth-token" {
  description = "Auth token for shellctl communication. Can be empty for dev. Generate with: openssl rand -base64 32"
  type        = string
  sensitive   = true
  default     = ""
}


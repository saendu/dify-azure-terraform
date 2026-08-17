resource "random_password" "dify_secret_key" {
  length  = 64
  special = false
}

resource "random_password" "dify_plugin_daemon_key" {
  length  = 64
  special = false
}

resource "random_password" "dify_inner_api_key" {
  length  = 64
  special = false
}

resource "random_password" "dify_sandbox_api_key" {
  length  = 64
  special = false
}

resource "random_password" "dify_agent_api_token" {
  length  = 64
  special = false
}

resource "random_bytes" "dify_agent_server_secret_key" {
  length = 32
}

resource "random_password" "dify_agent_shellctl_auth_token" {
  length  = 64
  special = false
}

resource "random_password" "pgsql_admin_password" {
  length  = 32
  special = false
}

locals {
  dify_secret_key_value        = random_password.dify_secret_key.result
  dify_plugin_daemon_key_value = random_password.dify_plugin_daemon_key.result
  dify_inner_api_key_value     = random_password.dify_inner_api_key.result
  dify_sandbox_api_key_value   = random_password.dify_sandbox_api_key.result
  dify_agent_api_token_value   = random_password.dify_agent_api_token.result
  # Dify requires unpadded base64url that decodes to exactly 32 bytes.
  dify_agent_server_secret_key_value   = replace(replace(replace(random_bytes.dify_agent_server_secret_key.base64, "+", "-"), "/", "_"), "=", "")
  dify_agent_shellctl_auth_token_value = random_password.dify_agent_shellctl_auth_token.result
  pgsql_admin_password_value           = random_password.pgsql_admin_password.result
}

output "generated_dify_secret_key" {
  description = "Auto-generated Dify secret key"
  value       = random_password.dify_secret_key.result
  sensitive   = true
}

output "generated_dify_plugin_daemon_key" {
  description = "Auto-generated plugin daemon key"
  value       = random_password.dify_plugin_daemon_key.result
  sensitive   = true
}

output "generated_dify_inner_api_key" {
  description = "Auto-generated inner API key"
  value       = random_password.dify_inner_api_key.result
  sensitive   = true
}

output "generated_dify_sandbox_api_key" {
  description = "Auto-generated sandbox API key"
  value       = random_password.dify_sandbox_api_key.result
  sensitive   = true
}

output "generated_dify_agent_api_token" {
  description = "Auto-generated API-to-Agent-backend bearer token"
  value       = random_password.dify_agent_api_token.result
  sensitive   = true
}

output "generated_dify_agent_server_secret_key" {
  description = "Auto-generated Agent Stub JWE derivation secret"
  value       = local.dify_agent_server_secret_key_value
  sensitive   = true
}

output "generated_dify_agent_shellctl_auth_token" {
  description = "Auto-generated Agent shell-control authentication token"
  value       = random_password.dify_agent_shellctl_auth_token.result
  sensitive   = true
}

output "generated_pgsql_admin_password" {
  description = "Auto-generated PostgreSQL admin password"
  value       = random_password.pgsql_admin_password.result
  sensitive   = true
}

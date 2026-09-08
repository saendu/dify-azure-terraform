resource "azurerm_storage_account" "acafileshare" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "dfy" {
  name                  = "dfy"
  storage_account_id    = azurerm_storage_account.acafileshare.id
  container_access_type = "private"
}


module "nginx_fileshare" {
  source             = "./fileshare_module"
  storage_account_id = azurerm_storage_account.acafileshare.id
  local_mount_dir    = "mountfiles/nginx"
  share_name         = "nginx"
}

module "sandbox_fileshare" {
  source             = "./fileshare_module"
  storage_account_id = azurerm_storage_account.acafileshare.id
  local_mount_dir    = "mountfiles/sandbox"
  share_name         = "sandbox"
}

module "ssrf_proxy_fileshare" {
  source             = "./fileshare_module"
  storage_account_id = azurerm_storage_account.acafileshare.id
  local_mount_dir    = "mountfiles/ssrfproxy"
  share_name         = "ssrfproxy"
}

module "agent_ssrf_proxy_fileshare" {
  source             = "./fileshare_module"
  storage_account_id = azurerm_storage_account.acafileshare.id
  local_mount_dir    = "mountfiles/agent-ssrfproxy"
  share_name         = "agentssrfproxy"
}

module "plugin_daemon_fileshare" {
  source             = "./fileshare_module"
  storage_account_id = azurerm_storage_account.acafileshare.id
  local_mount_dir    = "mountfiles/plugin_daemon"
  share_name         = "plugindaemon"
}

# API storage share for persistent data
resource "azurerm_storage_share" "api_storage" {
  name               = "api-storage"
  storage_account_id = azurerm_storage_account.acafileshare.id
  quota              = 50
}

# Dify 1.17.0 local Agent sandbox persistence. Home snapshots and active
# workspaces must survive Container App revision replacement.
resource "azurerm_storage_share" "dify_agent_local_sandbox_home" {
  name               = "agent-home"
  storage_account_id = azurerm_storage_account.acafileshare.id
  quota              = 50
}

resource "azurerm_storage_share" "dify_agent_local_sandbox_workspace" {
  name               = "agent-workspace"
  storage_account_id = azurerm_storage_account.acafileshare.id
  quota              = 50
}

resource "random_password" "plugin_dify_inner_api_key" {
  length  = 48
  special = false
}

resource "random_password" "plugin_daemon_key" {
  length  = 48
  special = false
}

resource "random_password" "sandbox_api_key" {
  length  = 32
  special = false
}

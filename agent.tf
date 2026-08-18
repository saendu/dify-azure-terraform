################################################################################
# Dify Agent v2 Services (Dify 1.16.1)
################################################################################

resource "azurerm_container_app_environment_storage" "agentssrfproxyfileshare" {
  name                         = "agentssrfproxyfileshare"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  account_name                 = azurerm_storage_account.acafileshare.name
  share_name                   = module.agent_ssrf_proxy_fileshare.share_name
  access_key                   = azurerm_key_vault_secret.storage_account_key.value
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app" "agent_ssrf_proxy" {
  name                         = "agentssrfproxy"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    max_replicas = 1
    min_replicas = 1

    container {
      name   = "agentssrfproxy"
      image  = "ubuntu/squid:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      volume_mounts {
        name = "agentssrfproxy"
        path = "/etc/squid"
      }
    }

    volume {
      name         = "agentssrfproxy"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.agentssrfproxyfileshare.name
    }
  }

  ingress {
    target_port      = 3128
    exposed_port     = 3128
    external_enabled = false

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }

    transport = "tcp"
  }
}

resource "azurerm_container_app" "local_sandbox" {
  name                         = "localsandbox"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  depends_on = [azurerm_container_app.agent_ssrf_proxy]

  template {
    # The official local Agent sandbox is stateful and singleton.
    max_replicas = 1
    min_replicas = 1

    container {
      name   = "localsandbox"
      image  = var.dify-agent-local-sandbox-image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "SHELLCTL_AUTH_TOKEN"
        value = azurerm_key_vault_secret.dify_agent_shellctl_auth_token.value
      }
      env {
        name  = "SHELLCTL_ENABLE_PATH_ISOLATION"
        value = "true"
      }
      env {
        name  = "HTTP_PROXY"
        value = "http://agentssrfproxy:3128"
      }
      env {
        name  = "HTTPS_PROXY"
        value = "http://agentssrfproxy:3128"
      }
      env {
        name  = "NO_PROXY"
        value = "localhost,127.0.0.1"
      }
    }
  }

  ingress {
    target_port      = 5004
    exposed_port     = 5004
    external_enabled = false

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }

    transport = "tcp"
  }
}

resource "azurerm_container_app" "agent_backend" {
  name                         = "agentbackend"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  depends_on = [
    azurerm_container_app.local_sandbox,
    azurerm_container_app.plugin_daemon,
  ]

  template {
    max_replicas = 1
    min_replicas = 1

    container {
      name   = "agentbackend"
      image  = var.dify-agent-backend-image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "DIFY_AGENT_REDIS_URL"
        value = "rediss://:${azurerm_key_vault_secret.redis_primary_key.value}@${azurerm_redis_cache.redis.hostname}:6380/2"
      }
      env {
        name  = "DIFY_AGENT_REDIS_PREFIX"
        value = "dify-agent"
      }
      env {
        name  = "DIFY_AGENT_PLUGIN_DAEMON_URL"
        value = "http://plugindaemon:5002"
      }
      env {
        name  = "DIFY_AGENT_PLUGIN_DAEMON_API_KEY"
        value = azurerm_key_vault_secret.dify_plugin_daemon_key.value
      }
      env {
        name  = "DIFY_AGENT_INNER_API_URL"
        value = "http://api:5001"
      }
      env {
        name  = "DIFY_AGENT_INNER_API_KEY"
        value = azurerm_key_vault_secret.dify_inner_api_key.value
      }
      env {
        name  = "DIFY_AGENT_SHELLCTL_ENTRYPOINT"
        value = "http://localsandbox:5004"
      }
      env {
        name  = "DIFY_AGENT_SHELLCTL_AUTH_TOKEN"
        value = azurerm_key_vault_secret.dify_agent_shellctl_auth_token.value
      }
      env {
        name  = "DIFY_AGENT_STUB_API_BASE_URL"
        value = "http://agentbackend:5050/agent-stub"
      }
      env {
        name  = "DIFY_AGENT_SERVER_SECRET_KEY"
        value = azurerm_key_vault_secret.dify_agent_server_secret_key.value
      }
      env {
        name  = "DIFY_AGENT_API_TOKEN"
        value = azurerm_key_vault_secret.dify_agent_api_token.value
      }
      env {
        name  = "DIFY_AGENT_SHUTDOWN_GRACE_SECONDS"
        value = "30"
      }
      env {
        name  = "DIFY_AGENT_RUN_RETENTION_SECONDS"
        value = "259200"
      }
      env {
        name  = "DIFY_AGENT_SHELL_REDACT_PATTERNS"
        value = ""
      }
    }
  }

  ingress {
    target_port      = 5050
    exposed_port     = 5050
    external_enabled = false

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }

    transport = "tcp"
  }
}

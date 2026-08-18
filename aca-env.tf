resource "azurerm_log_analytics_workspace" "aca-loga" {
  name                = local.aca_log_analytics_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}


resource "azurerm_container_app_environment" "dify-aca-env" {
  name                       = local.aca_environment_name
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.aca-loga.id
  infrastructure_subnet_id   = azurerm_subnet.acasubnet.id
  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  depends_on = [
    azurerm_redis_cache.redis,
    azurerm_postgresql_flexible_server.postgres
  ]
}

resource "azurerm_container_app_environment_storage" "nginxfileshare" {
  name                         = "nginxshare"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  account_name                 = azurerm_storage_account.acafileshare.name
  # share_name = 
  share_name  = module.nginx_fileshare.share_name
  access_key  = azurerm_key_vault_secret.storage_account_key.value
  access_mode = "ReadWrite"
}

resource "azurerm_container_app" "nginx" {
  name                         = "nginx"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    http_scale_rule {
      name                = "nginx"
      concurrent_requests = "10"
    }
    max_replicas = 10
    min_replicas = 1
    container {
      name   = "nginx"
      image  = "nginx:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      volume_mounts {
        name = "nginxconf"
        path = "/etc/nginx"
      }
    }
    volume {
      name         = "nginxconf"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.nginxfileshare.name
    }
  }
  ingress {
    target_port      = 80
    external_enabled = true
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
    transport = "auto"
  }
}

resource "azurerm_container_app_environment_storage" "ssrfproxyfileshare" {
  name                         = "ssrfproxyfileshare"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  account_name                 = azurerm_storage_account.acafileshare.name
  # share_name = 
  share_name  = module.ssrf_proxy_fileshare.share_name
  access_key  = azurerm_key_vault_secret.storage_account_key.value
  access_mode = "ReadWrite"
}

resource "azurerm_container_app" "ssrfproxy" {
  name                         = "ssrfproxy"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    tcp_scale_rule {
      name                = "ssrfproxy"
      concurrent_requests = "10"
    }
    max_replicas = 10
    min_replicas = 1
    container {
      name   = "ssrfproxy"
      image  = "ubuntu/squid:latest"
      cpu    = 0.25
      memory = "0.5Gi"
      volume_mounts {
        name = "ssrfproxy"
        path = "/etc/squid"
      }
    }
    volume {
      name         = "ssrfproxy"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.ssrfproxyfileshare.name
    }
  }
  ingress {
    target_port      = 3128
    external_enabled = false
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
    transport = "tcp"
  }
}

resource "azurerm_container_app_environment_storage" "plugindaemonfileshare" {
  name                         = "plugindaemonfileshare"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  account_name                 = azurerm_storage_account.acafileshare.name
  share_name                   = module.plugin_daemon_fileshare.share_name
  access_key                   = azurerm_key_vault_secret.storage_account_key.value
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app_environment_storage" "apistoragefileshare" {
  name                         = "apistoragefileshare"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  account_name                 = azurerm_storage_account.acafileshare.name
  share_name                   = azurerm_storage_share.api_storage.name
  access_key                   = azurerm_key_vault_secret.storage_account_key.value
  access_mode                  = "ReadWrite"
}

resource "azurerm_container_app" "plugin_daemon" {
  name                         = "plugindaemon"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    tcp_scale_rule {
      name                = "plugindaemon"
      concurrent_requests = "10"
    }
    max_replicas = 10
    min_replicas = 1
    container {
      name   = "langgenius"
      image  = var.dify-plugin-daemon-image
      cpu    = 0.5
      memory = "1Gi"

      # Database configuration - Azure PostgreSQL requires SSL
      env {
        name  = "DB_SSL_MODE"
        value = "require"
      }
      env {
        name  = "DB_USERNAME"
        value = azurerm_postgresql_flexible_server.postgres.administrator_login
      }
      env {
        name  = "DB_PASSWORD"
        value = azurerm_key_vault_secret.postgres_password.value
      }
      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.postgres.fqdn
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_DATABASE"
        value = azurerm_postgresql_flexible_server_database.dify_plugin.name
      }
      env {
        name  = "DB_DEFAULT_DATABASE"
        value = "postgres"
      }

      # Redis configuration — Azure Redis only exposes the SSL port (6380).
      env {
        name  = "REDIS_HOST"
        value = azurerm_redis_cache.redis.hostname
      }
      env {
        name  = "REDIS_PORT"
        value = "6380"
      }
      env {
        name  = "REDIS_PASSWORD"
        value = azurerm_key_vault_secret.redis_primary_key.value
      }
      env {
        name  = "REDIS_USE_SSL"
        value = "true"
      }
      env {
        name  = "REDIS_DB"
        value = "0"
      }
      env {
        name  = "CELERY_BROKER_URL"
        value = "rediss://:${azurerm_key_vault_secret.redis_primary_key.value}@${azurerm_redis_cache.redis.hostname}:6380/1"
      }

      # Server configuration (correct env var names per plugin daemon config.go)
      env {
        name  = "SERVER_HOST"
        value = "0.0.0.0"
      }
      env {
        name  = "SERVER_PORT"
        value = "5002"
      }
      env {
        name  = "SERVER_KEY"
        value = azurerm_key_vault_secret.dify_plugin_daemon_key.value
      }
      env {
        name  = "GIN_MODE"
        value = "release"
      }

      # Platform configuration (required)
      env {
        name  = "PLATFORM"
        value = "local"
      }

      # Routine pool configuration (required)
      env {
        name  = "ROUTINE_POOL_SIZE"
        value = "1024"
      }

      # Local launching configuration (required for local platform)
      env {
        name  = "PLUGIN_LOCAL_LAUNCHING_CONCURRENT"
        value = "4"
      }

      # Dify API communication (correct env var names per plugin daemon config.go)
      env {
        name  = "DIFY_INNER_API_URL"
        value = "http://api:5001"
      }
      env {
        name  = "DIFY_INNER_API_KEY"
        value = azurerm_key_vault_secret.dify_inner_api_key.value
      }

      # Plugin remote installing configuration
      env {
        name  = "PLUGIN_REMOTE_INSTALLING_ENABLED"
        value = "true"
      }
      env {
        name  = "PLUGIN_REMOTE_INSTALLING_HOST"
        value = "0.0.0.0"
      }
      env {
        name  = "PLUGIN_REMOTE_INSTALLING_PORT"
        value = "5003"
      }

      # Plugin paths - Critical for Azure Container Apps (no symlinks)
      env {
        name  = "PLUGIN_WORKING_PATH"
        value = "/tmp/plugin_workdir"
      }
      env {
        name  = "PLUGIN_INSTALLED_PATH"
        value = "/tmp/plugin_installed"
      }
      env {
        name  = "PLUGIN_PACKAGE_CACHE_PATH"
        value = "/app/storage/plugin_packages"
      }
      env {
        name  = "PLUGIN_MEDIA_CACHE_PATH"
        value = "assets"
      }

      # UV package manager configuration (required for Azure Container Apps)
      env {
        name  = "UV_COPY"
        value = "1"
      }
      env {
        name  = "UV_LINK_MODE"
        value = "copy"
      }
      env {
        name  = "UV_NO_SYMLINKS"
        value = "1"
      }
      env {
        name  = "PYTHON_INTERPRETER_PATH"
        value = "/usr/bin/python3.12"
      }
      env {
        name  = "VIRTUAL_ENV_DISABLE_PROMPT"
        value = "1"
      }
      env {
        name  = "PYTHONPATH"
        value = "/tmp/plugin_workdir"
      }

      # Plugin execution configuration
      env {
        name  = "FORCE_VERIFYING_SIGNATURE"
        value = "true"
      }
      env {
        name  = "ENFORCE_LANGGENIUS_PLUGIN_SIGNATURES"
        value = "true"
      }
      env {
        name  = "MAX_PLUGIN_PACKAGE_SIZE"
        value = "52428800"
      }
      env {
        name  = "PYTHON_ENV_INIT_TIMEOUT"
        value = "120"
      }
      env {
        name  = "PLUGIN_MAX_EXECUTION_TIMEOUT"
        value = "600"
      }

      # Plugin stdio buffer configuration
      env {
        name  = "PLUGIN_STDIO_BUFFER_SIZE"
        value = "1024"
      }
      env {
        name  = "PLUGIN_STDIO_MAX_BUFFER_SIZE"
        value = "5242880"
      }

      # Storage configuration
      env {
        name  = "PLUGIN_STORAGE_TYPE"
        value = "local"
      }
      env {
        name  = "PLUGIN_STORAGE_LOCAL_ROOT"
        value = "/app/storage"
      }

      # Azure Blob storage (if needed for plugin storage)
      env {
        name  = "AZURE_BLOB_ACCOUNT_NAME"
        value = azurerm_storage_account.acafileshare.name
      }
      env {
        name  = "AZURE_BLOB_ACCOUNT_KEY"
        value = azurerm_key_vault_secret.storage_account_key.value
      }
      env {
        name  = "AZURE_BLOB_ACCOUNT_URL"
        value = azurerm_storage_account.acafileshare.primary_blob_endpoint
      }
      env {
        name  = "AZURE_BLOB_CONTAINER_NAME"
        value = azurerm_storage_container.dfy.name
      }

      # Profiling (disabled by default)
      env {
        name  = "PPROF_ENABLED"
        value = "false"
      }

      # UV cache directory (Dify 1.15.0 — path changed from /tmp/.uv-cache)
      env {
        name  = "UV_CACHE_DIR"
        value = "/tmp/uv_cache"
      }

      # PyPI mirror configuration (Dify 1.15.0 — auto-detect nearby mirror)
      env {
        name  = "PIP_MIRROR_AUTO_DETECT"
        value = "true"
      }
      env {
        name  = "PIP_MIRROR_URL"
        value = ""
      }

      volume_mounts {
        name = "plugindaemon-storage"
        path = "/app/storage"
      }
    }

    volume {
      name         = "plugindaemon-storage"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.plugindaemonfileshare.name
    }
  }

  ingress {
    target_port      = 5002
    exposed_port     = 5002
    external_enabled = false
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
    transport = "tcp"
  }
}

resource "azurerm_container_app_environment_storage" "sandboxfileshare" {
  name                         = "sandbox"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  account_name                 = azurerm_storage_account.acafileshare.name
  # share_name = 
  share_name  = module.sandbox_fileshare.share_name
  access_key  = azurerm_key_vault_secret.storage_account_key.value
  access_mode = "ReadWrite"
}

resource "azurerm_container_app" "sandbox" {
  name                         = "sandbox"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  template {
    tcp_scale_rule {
      name                = "sandbox"
      concurrent_requests = "10"
    }
    max_replicas = 10
    min_replicas = 1
    container {
      name   = "langgenius"
      image  = var.dify-sandbox-image
      cpu    = 0.5
      memory = "1Gi"
      env {
        name  = "API_KEY"
        value = azurerm_key_vault_secret.dify_sandbox_api_key.value
      }
      env {
        name  = "GIN_MODE"
        value = "release"
      }
      env {
        name  = "WORKER_TIMEOUT"
        value = "15"
      }
      env {
        name  = "ENABLE_NETWORK"
        value = "true"
      }
      env {
        name  = "HTTP_PROXY"
        value = "http://ssrfproxy:3128"
      }
      env {
        name  = "HTTPS_PROXY"
        value = "http://ssrfproxy:3128"
      }
      env {
        name  = "SANDBOX_PORT"
        value = "8194"
      }

      volume_mounts {
        name = "sandbox"
        path = "/dependencies"
      }
    }
    volume {
      name         = "sandbox"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.sandboxfileshare.name
    }
  }
  ingress {
    target_port      = 8194
    external_enabled = false
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
    transport = "tcp"
  }
}

resource "azurerm_container_app" "worker" {
  name                         = "worker"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  depends_on = [
    azurerm_container_app.nginx,
    azurerm_container_app.agent_backend,
  ]

  template {
    tcp_scale_rule {
      name                = "worker"
      concurrent_requests = "10"
    }
    max_replicas = 10
    min_replicas = 1
    container {
      name   = "langgenius"
      image  = var.dify-api-image
      cpu    = 1
      memory = "2Gi"

      # Core configuration
      env {
        name  = "MODE"
        value = "worker"
      }
      env {
        name  = "LOG_LEVEL"
        value = "INFO"
      }
      env {
        name  = "DEBUG"
        value = "false"
      }
      env {
        name  = "SECRET_KEY"
        value = azurerm_key_vault_secret.dify_secret_key.value
      }
      env {
        name  = "DEPLOY_ENV"
        value = "PRODUCTION"
      }

      # INTERNAL_FILES_URL is used for plugin daemon communication within Docker network
      env {
        name  = "INTERNAL_FILES_URL"
        value = "http://api:5001"
      }

      # Database configuration
      env {
        name  = "DB_USERNAME"
        value = azurerm_postgresql_flexible_server.postgres.administrator_login
      }
      env {
        name  = "DB_PASSWORD"
        value = azurerm_key_vault_secret.postgres_password.value
      }
      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.postgres.fqdn
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_DATABASE"
        value = azurerm_postgresql_flexible_server_database.difypgsqldb.name
      }
      env {
        name  = "SQLALCHEMY_POOL_SIZE"
        value = "10"
      }
      env {
        name  = "SQLALCHEMY_POOL_RECYCLE"
        value = "3600"
      }

      # Redis configuration
      env {
        name  = "REDIS_HOST"
        value = azurerm_redis_cache.redis.hostname
      }
      env {
        name  = "REDIS_PORT"
        value = "6380"
      }
      env {
        name  = "REDIS_PASSWORD"
        value = azurerm_key_vault_secret.redis_primary_key.value
      }
      env {
        name  = "REDIS_USE_SSL"
        value = "true"
      }
      env {
        name  = "REDIS_DB"
        value = "0"
      }
      env {
        name  = "CELERY_BROKER_URL"
        value = "rediss://:${azurerm_key_vault_secret.redis_primary_key.value}@${azurerm_redis_cache.redis.hostname}:6380/1"
      }
      env {
        name  = "CELERY_BACKEND"
        value = "redis"
      }

      # Event Bus / PubSub configuration (Dify 1.15.0 — streaming & HITL resume)
      env {
        name  = "EVENT_BUS_REDIS_URL"
        value = ""
      }
      env {
        name  = "EVENT_BUS_REDIS_CHANNEL_TYPE"
        value = "pubsub"
      }
      env {
        name  = "EVENT_BUS_REDIS_USE_CLUSTERS"
        value = "false"
      }
      env {
        name  = "PLUGIN_MODEL_PROVIDERS_CACHE_TTL"
        value = "86400"
      }
      env {
        name  = "PLUGIN_MODEL_PROVIDERS_CACHE_ENABLED"
        value = "true"
      }

      # Dify Agent v2 backend configuration (Dify 1.16.1)
      env {
        name  = "AGENT_BACKEND_BASE_URL"
        value = "http://agentbackend:5050"
      }
      env {
        name  = "AGENT_BACKEND_API_TOKEN"
        value = azurerm_key_vault_secret.dify_agent_api_token.value
      }
      env {
        name  = "AGENT_BACKEND_STREAM_READ_TIMEOUT_SECONDS"
        value = "30"
      }
      env {
        name  = "AGENT_BACKEND_STREAM_MAX_RECONNECTS"
        value = "3"
      }
      env {
        name  = "AGENT_BACKEND_RUN_TIMEOUT_SECONDS"
        value = "1200"
      }

      # Storage configuration - Azure Blob
      env {
        name  = "STORAGE_TYPE"
        value = "azure-blob"
      }
      env {
        name  = "AZURE_BLOB_ACCOUNT_NAME"
        value = azurerm_storage_account.acafileshare.name
      }
      env {
        name  = "AZURE_BLOB_ACCOUNT_KEY"
        value = azurerm_key_vault_secret.storage_account_key.value
      }
      env {
        name  = "AZURE_BLOB_ACCOUNT_URL"
        value = azurerm_storage_account.acafileshare.primary_blob_endpoint
      }
      env {
        name  = "AZURE_BLOB_CONTAINER_NAME"
        value = azurerm_storage_container.dfy.name
      }

      # Vector store configuration - pgvector
      env {
        name  = "VECTOR_STORE"
        value = "pgvector"
      }
      env {
        name  = "PGVECTOR_HOST"
        value = azurerm_postgresql_flexible_server.postgres.fqdn
      }
      env {
        name  = "PGVECTOR_PORT"
        value = "5432"
      }
      env {
        name  = "PGVECTOR_USER"
        value = azurerm_postgresql_flexible_server.postgres.administrator_login
      }
      env {
        name  = "PGVECTOR_PASSWORD"
        value = azurerm_key_vault_secret.postgres_password.value
      }
      env {
        name  = "PGVECTOR_DATABASE"
        value = azurerm_postgresql_flexible_server_database.pgvector.name
      }

      # Code execution configuration
      env {
        name  = "CODE_EXECUTION_API_KEY"
        value = azurerm_key_vault_secret.dify_sandbox_api_key.value
      }
      env {
        name  = "CODE_EXECUTION_ENDPOINT"
        value = "http://sandbox:8194"
      }

      # SSRF Proxy configuration
      env {
        name  = "SSRF_PROXY_HTTP_URL"
        value = "http://ssrfproxy:3128"
      }
      env {
        name  = "SSRF_PROXY_HTTPS_URL"
        value = "http://ssrfproxy:3128"
      }

      # Indexing configuration
      env {
        name  = "INDEXING_MAX_SEGMENTATION_TOKENS_LENGTH"
        value = "4000"
      }

      # Plugin daemon configuration
      env {
        name  = "PLUGIN_DAEMON_URL"
        value = "http://plugindaemon:5002"
      }
      env {
        name  = "PLUGIN_DAEMON_KEY"
        value = azurerm_key_vault_secret.dify_plugin_daemon_key.value
      }
      env {
        name  = "PLUGIN_MAX_PACKAGE_SIZE"
        value = "52428800"
      }
      env {
        name  = "INNER_API_KEY_FOR_PLUGIN"
        value = azurerm_key_vault_secret.dify_inner_api_key.value
      }

      # Celery worker configuration (Dify 1.14.0 default raised to 4)
      env {
        name  = "CELERY_WORKER_AMOUNT"
        value = "4"
      }

      # Redis key prefix (Dify 1.14.0)
      env {
        name  = "REDIS_KEY_PREFIX"
        value = ""
      }
    }
  }
}

resource "azurerm_container_app" "worker_beat" {
  name                         = "workerbeat"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  depends_on = [azurerm_container_app.nginx]

  template {
    # Beat is a singleton scheduler — must run exactly one replica.
    max_replicas = 1
    min_replicas = 1
    container {
      name   = "langgenius"
      image  = var.dify-api-image
      cpu    = 0.5
      memory = "1Gi"

      # Core configuration
      env {
        name  = "MODE"
        value = "beat"
      }
      env {
        name  = "LOG_LEVEL"
        value = "INFO"
      }
      env {
        name  = "DEBUG"
        value = "false"
      }
      env {
        name  = "SECRET_KEY"
        value = azurerm_key_vault_secret.dify_secret_key.value
      }
      env {
        name  = "DEPLOY_ENV"
        value = "PRODUCTION"
      }

      # Database configuration
      env {
        name  = "DB_USERNAME"
        value = azurerm_postgresql_flexible_server.postgres.administrator_login
      }
      env {
        name  = "DB_PASSWORD"
        value = azurerm_key_vault_secret.postgres_password.value
      }
      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.postgres.fqdn
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_DATABASE"
        value = azurerm_postgresql_flexible_server_database.difypgsqldb.name
      }
      env {
        name  = "SQLALCHEMY_POOL_SIZE"
        value = "5"
      }
      env {
        name  = "SQLALCHEMY_POOL_RECYCLE"
        value = "3600"
      }

      # Redis configuration
      env {
        name  = "REDIS_HOST"
        value = azurerm_redis_cache.redis.hostname
      }
      env {
        name  = "REDIS_PORT"
        value = "6380"
      }
      env {
        name  = "REDIS_PASSWORD"
        value = azurerm_key_vault_secret.redis_primary_key.value
      }
      env {
        name  = "REDIS_USE_SSL"
        value = "true"
      }
      env {
        name  = "REDIS_DB"
        value = "0"
      }
      env {
        name  = "REDIS_KEY_PREFIX"
        value = ""
      }
      env {
        name  = "CELERY_BROKER_URL"
        value = "rediss://:${azurerm_key_vault_secret.redis_primary_key.value}@${azurerm_redis_cache.redis.hostname}:6380/1"
      }
      env {
        name  = "CELERY_BACKEND"
        value = "redis"
      }

      # Event Bus / PubSub configuration (Dify 1.15.0)
      env {
        name  = "EVENT_BUS_REDIS_URL"
        value = ""
      }
      env {
        name  = "EVENT_BUS_REDIS_CHANNEL_TYPE"
        value = "pubsub"
      }
      env {
        name  = "EVENT_BUS_REDIS_USE_CLUSTERS"
        value = "false"
      }

      # Storage configuration - Azure Blob (beat may emit cleanup tasks that touch storage refs)
      env {
        name  = "STORAGE_TYPE"
        value = "azure-blob"
      }
      env {
        name  = "AZURE_BLOB_ACCOUNT_NAME"
        value = azurerm_storage_account.acafileshare.name
      }
      env {
        name  = "AZURE_BLOB_ACCOUNT_KEY"
        value = azurerm_key_vault_secret.storage_account_key.value
      }
      env {
        name  = "AZURE_BLOB_ACCOUNT_URL"
        value = azurerm_storage_account.acafileshare.primary_blob_endpoint
      }
      env {
        name  = "AZURE_BLOB_CONTAINER_NAME"
        value = azurerm_storage_container.dfy.name
      }

      # Scheduled task toggles
      env {
        name  = "ENABLE_HUMAN_INPUT_TIMEOUT_TASK"
        value = "true"
      }
      env {
        name  = "WORKFLOW_LOG_CLEANUP_ENABLED"
        value = "false"
      }
    }
  }
}

resource "azurerm_container_app" "api" {
  name                         = "api"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  depends_on = [
    azurerm_container_app.nginx,
    azurerm_container_app.agent_backend,
  ]

  template {
    tcp_scale_rule {
      name                = "api"
      concurrent_requests = "10"
    }
    max_replicas = 10
    min_replicas = 1
    container {
      name   = "langgenius"
      image  = var.dify-api-image
      cpu    = 1
      memory = "2Gi"

      volume_mounts {
        name = "api-storage"
        path = "/app/api/storage"
      }

      # Core configuration
      env {
        name  = "MODE"
        value = "api"
      }
      env {
        name  = "LOG_LEVEL"
        value = "INFO"
      }
      env {
        name  = "DEBUG"
        value = "false"
      }
      env {
        name  = "FLASK_DEBUG"
        value = "false"
      }
      env {
        name  = "SECRET_KEY"
        value = azurerm_key_vault_secret.dify_secret_key.value
      }
      env {
        name  = "DEPLOY_ENV"
        value = "PRODUCTION"
      }

      # URL configuration - will be set dynamically based on nginx
      env {
        name  = "CONSOLE_WEB_URL"
        value = ""
      }
      env {
        name  = "CONSOLE_API_URL"
        value = ""
      }
      env {
        name  = "SERVICE_API_URL"
        value = ""
      }
      env {
        name  = "APP_WEB_URL"
        value = ""
      }
      env {
        name  = "FILES_URL"
        value = ""
      }
      # INTERNAL_FILES_URL is used for plugin daemon communication within Docker network
      # Required for proper plugin file access
      env {
        name  = "INTERNAL_FILES_URL"
        value = "http://api:5001"
      }
      env {
        name  = "INIT_PASSWORD"
        value = ""
      }
      env {
        name  = "FILES_ACCESS_TIMEOUT"
        value = "300"
      }
      env {
        name  = "MIGRATION_ENABLED"
        value = "true"
      }
      # Access token configuration
      env {
        name  = "ACCESS_TOKEN_EXPIRE_MINUTES"
        value = "60"
      }
      env {
        name  = "REFRESH_TOKEN_EXPIRE_DAYS"
        value = "30"
      }

      # Database configuration
      env {
        name  = "DB_USERNAME"
        value = azurerm_postgresql_flexible_server.postgres.administrator_login
      }
      env {
        name  = "DB_PASSWORD"
        value = azurerm_key_vault_secret.postgres_password.value
      }
      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.postgres.fqdn
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_DATABASE"
        value = azurerm_postgresql_flexible_server_database.difypgsqldb.name
      }
      env {
        name  = "SQLALCHEMY_POOL_SIZE"
        value = "10"
      }
      env {
        name  = "SQLALCHEMY_POOL_RECYCLE"
        value = "3600"
      }

      # Redis configuration
      env {
        name  = "REDIS_HOST"
        value = azurerm_redis_cache.redis.hostname
      }
      env {
        name  = "REDIS_PORT"
        value = "6380"
      }
      env {
        name  = "REDIS_PASSWORD"
        value = azurerm_key_vault_secret.redis_primary_key.value
      }
      env {
        name  = "REDIS_USE_SSL"
        value = "true"
      }
      env {
        name  = "REDIS_DB"
        value = "0"
      }
      env {
        name  = "CELERY_BROKER_URL"
        value = "rediss://:${azurerm_key_vault_secret.redis_primary_key.value}@${azurerm_redis_cache.redis.hostname}:6380/1"
      }

      # Event Bus / PubSub configuration (Dify 1.15.0 — streaming & HITL resume)
      env {
        name  = "EVENT_BUS_REDIS_URL"
        value = ""
      }
      env {
        name  = "EVENT_BUS_REDIS_CHANNEL_TYPE"
        value = "pubsub"
      }
      env {
        name  = "EVENT_BUS_REDIS_USE_CLUSTERS"
        value = "false"
      }

      # Server-side API URL (Dify 1.15.0 — used by web for SSR)
      env {
        name  = "SERVER_CONSOLE_API_URL"
        value = "http://api:5001"
      }

      # Feature toggles (Dify 1.15.0)
      env {
        name  = "ENABLE_LEARN_APP"
        value = "true"
      }
      env {
        name  = "PLUGIN_MODEL_PROVIDERS_CACHE_TTL"
        value = "86400"
      }
      env {
        name  = "PLUGIN_MODEL_PROVIDERS_CACHE_ENABLED"
        value = "true"
      }

      # Dify Agent v2 backend configuration (Dify 1.16.1)
      env {
        name  = "AGENT_BACKEND_BASE_URL"
        value = "http://agentbackend:5050"
      }
      env {
        name  = "AGENT_BACKEND_API_TOKEN"
        value = azurerm_key_vault_secret.dify_agent_api_token.value
      }
      env {
        name  = "AGENT_BACKEND_STREAM_READ_TIMEOUT_SECONDS"
        value = "30"
      }
      env {
        name  = "AGENT_BACKEND_STREAM_MAX_RECONNECTS"
        value = "3"
      }
      env {
        name  = "AGENT_BACKEND_RUN_TIMEOUT_SECONDS"
        value = "1200"
      }

      # CORS configuration
      env {
        name  = "WEB_API_CORS_ALLOW_ORIGINS"
        value = "*"
      }
      env {
        name  = "CONSOLE_CORS_ALLOW_ORIGINS"
        value = "*"
      }

      # Storage configuration - Azure Blob
      env {
        name  = "STORAGE_TYPE"
        value = "azure-blob"
      }
      env {
        name  = "AZURE_BLOB_ACCOUNT_NAME"
        value = azurerm_storage_account.acafileshare.name
      }
      env {
        name  = "AZURE_BLOB_ACCOUNT_KEY"
        value = azurerm_key_vault_secret.storage_account_key.value
      }
      env {
        name  = "AZURE_BLOB_ACCOUNT_URL"
        value = azurerm_storage_account.acafileshare.primary_blob_endpoint
      }
      env {
        name  = "AZURE_BLOB_CONTAINER_NAME"
        value = azurerm_storage_container.dfy.name
      }

      # Vector store configuration - pgvector
      env {
        name  = "VECTOR_STORE"
        value = "pgvector"
      }
      env {
        name  = "PGVECTOR_HOST"
        value = azurerm_postgresql_flexible_server.postgres.fqdn
      }
      env {
        name  = "PGVECTOR_PORT"
        value = "5432"
      }
      env {
        name  = "PGVECTOR_USER"
        value = azurerm_postgresql_flexible_server.postgres.administrator_login
      }
      env {
        name  = "PGVECTOR_PASSWORD"
        value = azurerm_key_vault_secret.postgres_password.value
      }
      env {
        name  = "PGVECTOR_DATABASE"
        value = azurerm_postgresql_flexible_server_database.pgvector.name
      }

      # Code execution configuration
      env {
        name  = "CODE_EXECUTION_API_KEY"
        value = azurerm_key_vault_secret.dify_sandbox_api_key.value
      }
      env {
        name  = "CODE_EXECUTION_ENDPOINT"
        value = "http://sandbox:8194"
      }
      env {
        name  = "CODE_MAX_NUMBER"
        value = "9223372036854775807"
      }
      env {
        name  = "CODE_MIN_NUMBER"
        value = "-9223372036854775808"
      }
      env {
        name  = "CODE_MAX_DEPTH"
        value = "5"
      }
      env {
        name  = "CODE_MAX_PRECISION"
        value = "20"
      }
      env {
        name  = "CODE_MAX_STRING_LENGTH"
        value = "400000"
      }
      env {
        name  = "CODE_MAX_OBJECT_ARRAY_LENGTH"
        value = "30"
      }
      env {
        name  = "CODE_MAX_STRING_ARRAY_LENGTH"
        value = "30"
      }
      env {
        name  = "CODE_MAX_NUMBER_ARRAY_LENGTH"
        value = "3000"
      }
      env {
        name  = "TEMPLATE_TRANSFORM_MAX_LENGTH"
        value = "400000"
      }

      # SSRF Proxy configuration
      env {
        name  = "SSRF_PROXY_HTTP_URL"
        value = "http://ssrfproxy:3128"
      }
      env {
        name  = "SSRF_PROXY_HTTPS_URL"
        value = "http://ssrfproxy:3128"
      }

      # Indexing configuration
      env {
        name  = "INDEXING_MAX_SEGMENTATION_TOKENS_LENGTH"
        value = "4000"
      }

      # Plugin daemon configuration - Updated for 1.14.0
      env {
        name  = "PLUGIN_DAEMON_URL"
        value = "http://plugindaemon:5002"
      }
      env {
        name  = "PLUGIN_DAEMON_KEY"
        value = azurerm_key_vault_secret.dify_plugin_daemon_key.value
      }
      env {
        name  = "PLUGIN_REMOTE_INSTALL_HOST"
        value = "plugindaemon"
      }
      env {
        name  = "PLUGIN_REMOTE_INSTALL_PORT"
        value = "5003"
      }
      env {
        name  = "PLUGIN_MAX_PACKAGE_SIZE"
        value = "52428800"
      }
      env {
        name  = "PLUGIN_DAEMON_TIMEOUT"
        value = "600.0"
      }
      env {
        name  = "INNER_API_KEY_FOR_PLUGIN"
        value = azurerm_key_vault_secret.dify_inner_api_key.value
      }

      # Marketplace configuration
      env {
        name  = "MARKETPLACE_ENABLED"
        value = "true"
      }
      env {
        name  = "MARKETPLACE_API_URL"
        value = "https://marketplace.dify.ai"
      }

      # Workflow configuration
      env {
        name  = "WORKFLOW_MAX_EXECUTION_STEPS"
        value = "500"
      }
      env {
        name  = "WORKFLOW_MAX_EXECUTION_TIME"
        value = "1200"
      }
      env {
        name  = "LOOP_NODE_MAX_COUNT"
        value = "100"
      }
      env {
        name  = "MAX_TOOLS_NUM"
        value = "10"
      }
      env {
        name  = "MAX_PARALLEL_LIMIT"
        value = "10"
      }
      env {
        name  = "MAX_ITERATIONS_NUM"
        value = "99"
      }
      env {
        name  = "MAX_TREE_DEPTH"
        value = "50"
      }

      # Celery worker configuration (Dify 1.14.0 default)
      env {
        name  = "CELERY_WORKER_AMOUNT"
        value = "4"
      }
      env {
        name  = "SERVER_WORKER_CLASS"
        value = "gevent"
      }

      # Collaboration mode (Dify 1.14.0 - disabled; requires WebSocket ingress setup to enable)
      env {
        name  = "ENABLE_COLLABORATION_MODE"
        value = "false"
      }

      # Markdown rendering and security (Dify 1.14.0)
      env {
        name  = "ALLOW_INLINE_STYLES"
        value = "false"
      }
      env {
        name  = "ALLOW_UNSAFE_DATA_SCHEME"
        value = "false"
      }

      # Redis key prefix (Dify 1.14.0 - empty disables prefixing)
      env {
        name  = "REDIS_KEY_PREFIX"
        value = ""
      }

      # Scheduled task toggles (handled by worker_beat)
      env {
        name  = "ENABLE_HUMAN_INPUT_TIMEOUT_TASK"
        value = "true"
      }
      env {
        name  = "WORKFLOW_LOG_CLEANUP_ENABLED"
        value = "false"
      }

      # Sentry configuration
      env {
        name  = "SENTRY_DSN"
        value = ""
      }
      env {
        name  = "SENTRY_TRACES_SAMPLE_RATE"
        value = "1.0"
      }
      env {
        name  = "SENTRY_PROFILES_SAMPLE_RATE"
        value = "1.0"
      }
    }

    volume {
      name         = "api-storage"
      storage_type = "AzureFile"
      storage_name = azurerm_container_app_environment_storage.apistoragefileshare.name
    }
  }

  ingress {
    target_port      = 5001
    exposed_port     = 5001
    external_enabled = false
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
    transport = "tcp"
  }
}

resource "azurerm_container_app" "web" {
  name                         = "web"
  container_app_environment_id = azurerm_container_app_environment.dify-aca-env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  depends_on = [azurerm_container_app.nginx]

  template {
    tcp_scale_rule {
      name                = "web"
      concurrent_requests = "10"
    }
    max_replicas = 10
    min_replicas = 1
    container {
      name   = "langgenius"
      image  = var.dify-web-image
      cpu    = 0.5
      memory = "1Gi"

      # API URL configuration - will be proxied through nginx
      env {
        name  = "CONSOLE_API_URL"
        value = ""
      }
      env {
        name  = "APP_API_URL"
        value = ""
      }

      # Server-side API URL (Dify 1.15.0 — used for SSR requests)
      env {
        name  = "SERVER_CONSOLE_API_URL"
        value = "http://api:5001"
      }

      # Agent v2 and feature preview (Dify 1.16.1)
      env {
        name  = "NEXT_PUBLIC_ENABLE_AGENT_V2"
        value = tostring(var.enable-dify-agent-v2)
      }
      env {
        name  = "NEXT_PUBLIC_ENABLE_FEATURE_PREVIEW"
        value = "true"
      }

      # Sentry configuration
      env {
        name  = "SENTRY_DSN"
        value = ""
      }

      # Telemetry
      env {
        name  = "NEXT_TELEMETRY_DISABLED"
        value = "1"
      }

      # Timeouts
      env {
        name  = "TEXT_GENERATION_TIMEOUT_MS"
        value = "60000"
      }
      env {
        name  = "WORKFLOW_GENERATION_TIMEOUT_MS"
        value = "180000"
      }

      # Security (Dify 1.14.0)
      env {
        name  = "CSP_WHITELIST"
        value = ""
      }
      env {
        name  = "ALLOW_INLINE_STYLES"
        value = "false"
      }
      env {
        name  = "ALLOW_UNSAFE_DATA_SCHEME"
        value = "false"
      }
      env {
        name  = "ALLOW_EMBED"
        value = "false"
      }

      # WebSocket URL (only used when collaboration mode is enabled in api)
      env {
        name  = "NEXT_PUBLIC_SOCKET_URL"
        value = "ws://localhost"
      }

      # Marketplace configuration
      env {
        name  = "MARKETPLACE_ENABLED"
        value = "true"
      }
      env {
        name  = "MARKETPLACE_API_URL"
        value = "https://marketplace.dify.ai"
      }
      env {
        name  = "MARKETPLACE_URL"
        value = "https://marketplace.dify.ai"
      }

      # PM2 configuration
      env {
        name  = "PM2_INSTANCES"
        value = "2"
      }

      # Workflow limits
      env {
        name  = "LOOP_NODE_MAX_COUNT"
        value = "100"
      }
      env {
        name  = "MAX_TOOLS_NUM"
        value = "10"
      }
      env {
        name  = "MAX_PARALLEL_LIMIT"
        value = "10"
      }
      env {
        name  = "MAX_ITERATIONS_NUM"
        value = "99"
      }
      env {
        name  = "MAX_TREE_DEPTH"
        value = "50"
      }

      # Web datasources (Dify 1.14.0)
      env {
        name  = "ENABLE_WEBSITE_JINAREADER"
        value = "true"
      }
      env {
        name  = "ENABLE_WEBSITE_FIRECRAWL"
        value = "true"
      }
      env {
        name  = "ENABLE_WEBSITE_WATERCRAWL"
        value = "true"
      }
    }
  }

  ingress {
    target_port      = 3000
    exposed_port     = 3000
    external_enabled = false
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
    transport = "tcp"
  }
}

# Output the Dify application URL
output "dify_app_url" {
  value       = "https://${azurerm_container_app.nginx.latest_revision_fqdn}"
  description = "The URL of the Dify application"
}

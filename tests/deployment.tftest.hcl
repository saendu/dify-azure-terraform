mock_provider "azurerm" {
  # Key Vault validates these computed client-config values as UUIDs even when
  # the provider is mocked, so provide structurally valid fixture values.
  mock_data "azurerm_client_config" {
    defaults = {
      client_id       = "00000000-0000-0000-0000-000000000001"
      object_id       = "00000000-0000-0000-0000-000000000002"
      subscription_id = "00000000-0000-0000-0000-000000000003"
      tenant_id       = "00000000-0000-0000-0000-000000000004"
    }
  }
}
mock_provider "random" {}

run "dify_1_17_0_full_agent_plan" {
  command = plan

  assert {
    condition = (
      azurerm_container_app.api.template[0].container[0].image == "langgenius/dify-api:1.17.0" &&
      azurerm_container_app.web.template[0].container[0].image == "langgenius/dify-web:1.17.0" &&
      azurerm_container_app.plugin_daemon.template[0].container[0].image == "langgenius/dify-plugin-daemon:0.6.10-local" &&
      azurerm_container_app.agent_backend.template[0].container[0].image == "langgenius/dify-agent-backend:1.17.0" &&
      azurerm_container_app.local_sandbox.template[0].container[0].image == "langgenius/dify-agent-local-sandbox:1.17.0"
    )
    error_message = "The planned deployment must use the Dify 1.17.0 core, plugin, and Agent images."
  }

  assert {
    condition = (
      var.enable-dify-agent-v2 &&
      one([for item in azurerm_container_app.web.template[0].container[0].env : item.value if item.name == "NEXT_PUBLIC_ENABLE_AGENT_V2"]) == "true"
    )
    error_message = "Agent v2 must be enabled by default in the planned web revision."
  }

  assert {
    condition = (
      !azurerm_container_app.agent_backend.ingress[0].external_enabled &&
      !azurerm_container_app.local_sandbox.ingress[0].external_enabled &&
      !azurerm_container_app.agent_ssrf_proxy.ingress[0].external_enabled &&
      azurerm_container_app.local_sandbox.template[0].min_replicas == 1 &&
      azurerm_container_app.local_sandbox.template[0].max_replicas == 1 &&
      azurerm_container_app.worker_beat.template[0].min_replicas == 1 &&
      azurerm_container_app.worker_beat.template[0].max_replicas == 1
    )
    error_message = "Agent services must stay internal and stateful schedulers/sandboxes must stay singleton."
  }

  assert {
    condition = (
      one([for item in azurerm_container_app.api.template[0].container[0].env : item.value if item.name == "FILES_ACCESS_TIMEOUT"]) == "300" &&
      one([for item in azurerm_container_app.api.template[0].container[0].env : item.value if item.name == "PLUGIN_DAEMON_TIMEOUT"]) == "600.0" &&
      one([for item in azurerm_container_app.api.template[0].container[0].env : item.value if item.name == "APP_MAX_EXECUTION_TIME"]) == "3600" &&
      one([for item in azurerm_container_app.api.template[0].container[0].env : item.value if item.name == "WORKFLOW_MAX_EXECUTION_TIME"]) == "3600" &&
      one([for item in azurerm_container_app.agent_backend.template[0].container[0].env : item.value if item.name == "DIFY_AGENT_RUN_TIMEOUT_SECONDS"]) == "3600" &&
      one([for item in azurerm_container_app.web.template[0].container[0].env : item.value if item.name == "TEXT_GENERATION_TIMEOUT_MS"]) == "60000"
    )
    error_message = "The planned revisions must use the 1.17.0 execution defaults and preserve established plugin, file, and web timeouts."
  }

  assert {
    condition = (
      one([for item in azurerm_container_app.agent_backend.template[0].container[0].env : item.value if item.name == "DIFY_AGENT_RUNTIME_BACKEND"]) == "local" &&
      one([for item in azurerm_container_app.agent_backend.template[0].container[0].env : item.value if item.name == "DIFY_AGENT_LOCAL_SANDBOX_ENDPOINT"]) == "http://localsandbox:5004" &&
      one([for item in azurerm_container_app.agent_backend.template[0].container[0].env : item.value if item.name == "DIFY_AGENT_SANDBOX_FILES_BASE_URL"]) == "http://api:5001"
    )
    error_message = "Agent v2 must use the Dify 1.17.0 local runtime contract."
  }

  assert {
    condition = (
      contains([for mount in azurerm_container_app.local_sandbox.template[0].container[0].volume_mounts : mount.path], "/home/dify") &&
      contains([for mount in azurerm_container_app.local_sandbox.template[0].container[0].volume_mounts : mount.path], "/workspace")
    )
    error_message = "The local Agent sandbox must persist its Home Snapshot and workspace paths."
  }
}

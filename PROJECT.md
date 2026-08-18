# Dify Infrastructure Documentation

## Overview
This project contains the Terraform configuration for deploying a Dify environment on Azure. Dify is an open-source LLM application development platform that provides a complete solution for building AI applications.

**Current Version: Dify 1.16.1**

## Quick Start

1. Copy `environments/dev.tfvars copy.example` to `environments/dev.tfvars`.
2. Set the subscription, solution, environment, region, and network prefix for the target environment.
3. Run `terraform init` and `terraform plan -var-file="environments/dev.tfvars"`.
4. Apply the reviewed plan. Terraform generates the application and database secrets and stores them in Azure Key Vault.

⚠️ **IMPORTANT**: Never commit environment `.tfvars` files or Terraform state to version control.

## Infrastructure Components

### Core Resources
1. **Resource Group**
  - Name: dify-ina-latest
  - Region: Switzerland North

2. **Virtual Network**
  - IP Prefix: 10.99
  - Contains dedicated subnet for Azure Container Apps

3. **Database**
  - PostgreSQL Flexible Server
  - Name: inalatestdifypsql
  - Used for storing application data
  - Databases:
    - `difypgsqldb` - Main Dify database
    - `pgvector` - Vector store database (with pgvector extension)
    - `dify_plugin` - Plugin daemon database

4. **Caching**
  - Azure Redis Cache
  - Name: inalatestdifyredis
  - Used for session management, caching, and Celery broker

5. **Storage**
  - Azure Storage Account
  - Name: inalatestdifystorage
  - Container: dfy (Azure Blob for file storage)
  - File Shares:
    - `nginx` - Nginx configuration
    - `sandbox` - Sandbox dependencies
    - `ssrfproxy` - SSRF proxy configuration
    - `agentssrfproxy` - Dedicated Agent v2 SSRF proxy configuration
    - `plugindaemon` - Plugin daemon storage
    - `api-storage` - API persistent storage

### Azure Container Apps Environment
- Name: dify-ina-latest-env
- Log Analytics Workspace: dify-loga
- Infrastructure Subnet: Dedicated subnet for container apps
- Workload Profile: Consumption-based

### Container Applications

#### 1. Nginx (Reverse Proxy)
- **Role**: Reverse proxy and static file serving
- **Image**: nginx:latest
- **Scaling**: 1-10 replicas
- **Features**:
  - Routes API, Console, and Web traffic
  - Plugin endpoint routing (`/e/`)
  - 50MB client body size limit for plugin uploads

#### 2. SSRF Proxy
- **Role**: Security proxy for sandbox environment
- **Image**: ubuntu/squid:latest
- **Scaling**: 1-10 replicas
- **Purpose**: Prevents Server-Side Request Forgery attacks

#### 3. Sandbox
- **Role**: Isolated environment for code execution
- **Image**: langgenius/dify-sandbox:0.2.15
- **Scaling**: 1-10 replicas
- **Features**: Network access through SSRF proxy

#### 4. Plugin Daemon (New in Dify 1.x)
- **Role**: Plugin execution and management
- **Image**: langgenius/dify-plugin-daemon:0.6.3-local
- **Scaling**: 1-10 replicas
- **Critical Settings**:
  - `DB_SSL_MODE=require` (Required for Azure PostgreSQL)
  - UV package manager with copy mode (no symlinks)
  - Plugin working paths in `/tmp` for Azure compatibility
  - Correct env var names (see configuration section below)

#### 5. Worker
- **Role**: Background job processing (Celery)
- **Image**: langgenius/dify-api:1.16.1
- **Scaling**: 1-10 replicas
- **Mode**: worker

#### 6. Worker Beat (New in Dify 1.14.0)
- **Role**: Celery scheduled task dispatcher
- **Image**: langgenius/dify-api:1.16.1
- **Scaling**: Singleton (min=max=1) — beat MUST run as a single replica
- **Mode**: beat
- **Drives**: workflow log cleanup, sandbox expired-record cleanup, human-input timeout tasks

#### 7. API
- **Role**: Main application API
- **Image**: langgenius/dify-api:1.16.1
- **Scaling**: 1-10 replicas
- **Mode**: api
- **Features**: Migration enabled, marketplace integration

#### 8. Web
- **Role**: Frontend application
- **Image**: langgenius/dify-web:1.16.1
- **Scaling**: 1-10 replicas
- **Custom Domain**: agents.innoarchitects.ch (optional)

#### 9. Agent Backend (Dify Agent v2)
- **Role**: Runs Agent v2 orchestration and Agent Stub APIs
- **Image**: langgenius/dify-agent-backend:1.16.1
- **Scaling**: Singleton
- **Ingress**: Internal TCP 5050

#### 10. Local Agent Sandbox
- **Role**: Linux shell workspace for Agent v2
- **Image**: langgenius/dify-agent-local-sandbox:1.16.1
- **Scaling**: Singleton
- **Ingress**: Internal TCP 5004

#### 11. Agent SSRF Proxy
- **Role**: Restricts the local Agent sandbox's supported HTTP(S) flows
- **Image**: ubuntu/squid:latest
- **Scaling**: Singleton
- **Ingress**: Internal TCP 3128

### Container Images (Dify 1.16.1)
- API: langgenius/dify-api:1.16.1
- Web: langgenius/dify-web:1.16.1
- Sandbox: langgenius/dify-sandbox:0.2.15
- Plugin Daemon: langgenius/dify-plugin-daemon:0.6.3-local
- Agent Backend: langgenius/dify-agent-backend:1.16.1
- Agent Local Sandbox: langgenius/dify-agent-local-sandbox:1.16.1

## Key Configuration Notes for Dify 1.x on Azure

### Plugin Daemon Configuration
The plugin daemon requires special configuration for Azure Container Apps.

⚠️ **IMPORTANT**: The plugin daemon uses different environment variable names than the Dify API!
Check the [official config.go](https://github.com/langgenius/dify-plugin-daemon/blob/main/internal/types/app/config.go) for authoritative env var names.

**Required Server Configuration:**
```
SERVER_HOST=0.0.0.0
SERVER_PORT=5002
SERVER_KEY=<your-plugin-daemon-key>   # NOT PLUGIN_DAEMON_KEY!
GIN_MODE=release
PLATFORM=local
ROUTINE_POOL_SIZE=1024
PLUGIN_LOCAL_LAUNCHING_CONCURRENT=4
```

**Dify API Communication:**
```
DIFY_INNER_API_URL=http://api:5001   # NOT PLUGIN_DIFY_INNER_API_URL!
DIFY_INNER_API_KEY=<your-inner-api-key>   # NOT PLUGIN_DIFY_INNER_API_KEY!
```

**Database Configuration:**
```
DB_SSL_MODE=require   # Required for Azure PostgreSQL
DB_USERNAME=<db-user>
DB_PASSWORD=<db-pass>
DB_HOST=<db-host>
DB_PORT=5432
DB_DATABASE=dify_plugin
DB_DEFAULT_DATABASE=postgres   # Required!
```

**Azure-Specific Settings (UV Package Manager):**
```
UV_COPY=1
UV_LINK_MODE=copy
UV_NO_SYMLINKS=1
```
Azure File Shares don't support symlinks, so UV must use copy mode.

**Plugin Paths:**
```
PLUGIN_WORKING_PATH=/tmp/plugin_workdir
PLUGIN_INSTALLED_PATH=/tmp/plugin_installed
```
Use `/tmp` for working directories due to Azure File Share limitations.

**Python Configuration:**
```
PYTHON_INTERPRETER_PATH=/usr/bin/python3.12
PYTHONPATH=/tmp/plugin_workdir
```

### API/Worker Plugin Communication
The API and Worker containers need these to communicate with the plugin daemon:
```
PLUGIN_DAEMON_URL=http://plugindaemon:5002
PLUGIN_DAEMON_KEY=<your-plugin-daemon-key>   # Must match SERVER_KEY in plugin daemon!
INNER_API_KEY_FOR_PLUGIN=<your-inner-api-key>   # Must match DIFY_INNER_API_KEY in plugin daemon!
```

### Environment Variable Mapping (Important!)
The Dify API and Plugin Daemon use **different env var names** that must match:

| API/Worker Container | Plugin Daemon Container | Must Match |
| --- | --- | --- |
| `PLUGIN_DAEMON_KEY` | `SERVER_KEY` | ✅ Yes |
| `INNER_API_KEY_FOR_PLUGIN` | `DIFY_INNER_API_KEY` | ✅ Yes |
| N/A | `DIFY_INNER_API_URL` | Points to API |
| `PLUGIN_DAEMON_URL` | N/A | Points to Plugin Daemon |

### Service Discovery
All services communicate internally using their container names:
- API: `http://api:5001`
- Web: `http://web:3000`
- Sandbox: `http://sandbox:8194`
- SSRF Proxy: `http://ssrfproxy:3128`
- Plugin Daemon: `http://plugindaemon:5002`
- Agent Backend: `http://agentbackend:5050`
- Agent Local Sandbox: `http://localsandbox:5004`
- Agent SSRF Proxy: `http://agentssrfproxy:3128`

### Nginx Routing
The nginx configuration includes routing for:
- `/console/api` → API service
- `/api` → API service
- `/v1` → API service (Service API)
- `/files` → API service
- `/e/` → **Plugin Daemon** (Plugin webhook endpoints, NOT API!)
- `/explore` → Web service (explicitly routed)
- `/mcp` → API service (MCP endpoints)
- `/triggers` → API service
- `/` → Web service (Frontend - handles /plugins, /apps, /tools, etc.)

⚠️ **Note**: The `/e/` endpoint MUST route to the plugin daemon, not the API. This is a common misconfiguration.

## Security Considerations
1. Application and database credentials are generated by Terraform and stored in Azure Key Vault
2. Network isolation through dedicated subnet
3. SSRF proxy for sandbox security
4. Azure Container Apps environment with infrastructure subnet
5. SSL required for PostgreSQL connections
6. Plugin signature verification enabled
7. Terraform state contains sensitive values and must remain outside Git
8. Agent v2 bearer, JWE, and shell-control credentials are generated independently and stored in Key Vault
9. Agent v2 is for trusted users; ACA does not provide Docker-equivalent per-service bridge-network isolation in one environment

## Dependencies
- Azure Provider: hashicorp/azurerm (`~> 4.79`)
- Random Provider: hashicorp/random (`~> 3.6`)
- Local Provider: hashicorp/local (`~> 2.9`)
- Azure subscription selected through the `subscription-id` variable

## File Structure
- `provider.tf`: Azure provider configuration
- `var.tf`: Variable definitions
- `vnet.tf`: Virtual network configuration
- `postgresql.tf`: PostgreSQL database setup
- `redis-cache.tf`: Redis cache configuration
- `fileshare.tf`: File share setup
- `aca-env.tf`: Container Apps environment and applications
- `agent.tf`: Dify Agent v2 backend, local sandbox, and dedicated SSRF proxy
- `mountfiles/`: Mount file configurations
  - `nginx/`: Nginx configuration files
  - `sandbox/`: Sandbox dependencies
  - `ssrfproxy/`: SSRF proxy configuration
  - `agent-ssrfproxy/`: Agent v2 SSRF proxy configuration
  - `plugin_daemon/`: Plugin daemon configuration
- `fileshare_module/`: File share Terraform module

## Deployment Notes
1. The infrastructure is designed for production use with proper isolation
2. All services are deployed in Switzerland North region
3. The setup includes proper logging and monitoring through Log Analytics
4. File storage is managed through Azure Storage with dedicated shares
5. The environment uses consumption-based scaling for cost optimization
6. All critical services have min_replicas=1 for reliability

## Maintenance Considerations
1. Regular updates of container images should be planned
2. Monitor Redis cache and PostgreSQL performance
3. Review Log Analytics data retention (currently 30 days)
4. Regular backup of PostgreSQL database
5. Monitor storage account usage and costs
6. Check plugin daemon logs for plugin installation issues

## Upgrade Notes (from pre-1.0 to 1.11.3)

### Breaking Changes
1. **Plugin Daemon**: New required service for plugin management
2. **Database**: Additional `dify_plugin` database required
3. **Hostnames**: Underscores removed from service names (plugin_daemon → plugindaemon)
4. **Environment Variables**: Many new plugin-related variables added

### Key Differences from Docker Compose
1. Azure File Shares don't support symlinks - UV package manager needs copy mode
2. Azure PostgreSQL requires SSL - DB_SSL_MODE must be set to "require"
3. Service names must not contain underscores in Azure Container Apps

## Upgrade Notes (1.15.0 → 1.16.1)

### Classic Agent and Agent v2 coexistence

The classic Agent path remains installed. Dify Agent v2 adds `agentbackend`, `localsandbox`, and `agentssrfproxy`. The Terraform variable `enable-dify-agent-v2` defaults to `true` and drives `NEXT_PUBLIC_ENABLE_AGENT_V2`. Set it to `false` to select the classic UI without deleting the Agent v2 infrastructure.

### Image changes

| Component | 1.15.0 | 1.16.1 |
| --- | --- | --- |
| dify-api | 1.15.0 | 1.16.1 |
| dify-web | 1.15.0 | 1.16.1 |
| Agent backend | absent | 1.16.1 |
| Agent local sandbox | absent | 1.16.1 |
| plugin daemon | 0.6.3-local | 0.6.3-local |
| classic sandbox | 0.2.15 | 0.2.15 |

### Credentials and service wiring

- `AGENT_BACKEND_API_TOKEN` on API/worker matches `DIFY_AGENT_API_TOKEN` on Agent backend.
- `DIFY_AGENT_SERVER_SECRET_KEY` is generated for Agent Stub JWE tokens.
- `DIFY_AGENT_SHELLCTL_AUTH_TOKEN` matches `SHELLCTL_AUTH_TOKEN` on the local Agent sandbox.
- All values are generated by Terraform and stored in Azure Key Vault; no Dify development defaults are used.

### Timeout compatibility

The upgrade preserves `PYTHON_ENV_INIT_TIMEOUT=120`, `PLUGIN_MAX_EXECUTION_TIMEOUT=600`, `WORKER_TIMEOUT=15`, `FILES_ACCESS_TIMEOUT=300`, `PLUGIN_DAEMON_TIMEOUT=600.0`, `TEXT_GENERATION_TIMEOUT_MS=60000`, `WORKFLOW_MAX_EXECUTION_TIME=1200`, `ACCESS_TOKEN_EXPIRE_MINUTES=60`, `REFRESH_TOKEN_EXPIRE_DAYS=30`, and `SQLALCHEMY_POOL_RECYCLE=3600`.

New values are additive: `AGENT_BACKEND_STREAM_READ_TIMEOUT_SECONDS=30`, `AGENT_BACKEND_STREAM_MAX_RECONNECTS=3`, `AGENT_BACKEND_RUN_TIMEOUT_SECONDS=1200`, and `WORKFLOW_GENERATION_TIMEOUT_MS=180000`.

### Database migrations and upgrade handling

`MIGRATION_ENABLED=true` runs the 1.16.0 and 1.16.1 migrations on API startup. Back up PostgreSQL and storage before upgrading an existing environment. The 1.15.0 `flask backfill-plugin-auto-upgrade` command remains required once for older installations that never ran it; a new empty database does not require the backfill.

### Agent sandbox network limitation

The dedicated Agent proxy follows Dify 1.16.1's ACL model: private access is limited to `/agent-stub/` on `agentbackend` and `/files/` on `api`, while external HTTP(S) is proxied. ACA in one managed environment cannot enforce the same per-service network isolation as Docker Compose. Only trusted users should receive Agent v2 access.

## Upgrade Notes (1.14.0 → 1.15.0)

### Image Version Bumps
| Component | 1.14.0 | 1.15.0 |
| --- | --- | --- |
| dify-api | 1.14.0 | 1.15.0 |
| dify-web | 1.14.0 | 1.15.0 |
| dify-sandbox | 0.2.15 | 0.2.15 (unchanged) |
| dify-plugin-daemon | 0.6.0-local | 0.6.3-local |

### New Environment Variables (defaults applied in Terraform)

**API, Worker, and Worker Beat**
- `EVENT_BUS_REDIS_URL=""` — Redis URL for PubSub; empty defaults to main Redis config
- `EVENT_BUS_REDIS_CHANNEL_TYPE="pubsub"` — channel type (`pubsub` or `sharded`)
- `EVENT_BUS_REDIS_USE_CLUSTERS="false"` — Redis cluster mode for PubSub

**API only**
- `SERVER_CONSOLE_API_URL="http://api:5001"` — internal API URL for server-side rendering
- `ENABLE_LEARN_APP="true"` — feature toggle for learn app
- `PLUGIN_MODEL_PROVIDERS_CACHE_TTL="86400"` — model providers cache TTL

**Worker only**
- `PLUGIN_MODEL_PROVIDERS_CACHE_TTL="86400"`

**Plugin Daemon**
- `UV_CACHE_DIR="/tmp/uv_cache"` — path changed from `/tmp/.uv-cache`
- `PIP_MIRROR_AUTO_DETECT="true"` — auto-detect nearby PyPI mirror
- `PIP_MIRROR_URL=""` — manually pin PyPI mirror

**Web**
- `SERVER_CONSOLE_API_URL="http://api:5001"` — server-side API URL for SSR
- `NEXT_PUBLIC_ENABLE_FEATURE_PREVIEW="false"` — enable preview features in UI

### Architecture Changes
- **Event Bus (PubSub)**: Streaming workflow executions and HITL resume now communicate via Redis PubSub (Event Bus). The `EVENT_BUS_REDIS_*` vars configure this. For small deployments, the default Redis instance is sufficient.
- **New Celery queue `workflow_based_app_execution`** (from 1.14.1): Already handled automatically — our workers consume all queues since `CELERY_QUEUES` is not restricted.

### Post-Deploy Manual Step (Required)
After `terraform apply`, exec into the API container and run:
```bash
flask backfill-plugin-auto-upgrade
```
This migrates existing plugin auto-upgrade settings into the new category-scoped model. If skipped, previously configured plugin auto-upgrade settings may stop taking effect.

### Database Migrations
Run automatically on API container start (`MIGRATION_ENABLED=true`). No manual migration step required.

## Upgrade Notes (1.11.3 → 1.14.0)

### Image Version Bumps
| Component | 1.11.3 | 1.14.0 |
| --- | --- | --- |
| dify-api | 1.11.3 | 1.14.0 |
| dify-web | 1.11.3 | 1.14.0 |
| dify-sandbox | 0.2.12 | 0.2.15 |
| dify-plugin-daemon | 0.5.2-local | 0.6.0-local |

### New Service: `workerbeat`
Dify 1.14.0 splits Celery scheduled-task dispatch into a dedicated `beat` service. The Terraform now provisions an `azurerm_container_app.worker_beat` running `MODE=beat` as a singleton (min=max=1).
Without it, scheduled cleanup tasks (workflow logs, expired sandbox records, human-input timeouts) will not fire.

### New Environment Variables (defaults applied in Terraform)

**API and Worker**
- `CELERY_WORKER_AMOUNT=4` (Dify 1.14.0 default raised from 1)
- `SERVER_WORKER_CLASS=gevent`
- `REDIS_KEY_PREFIX=""` (configurable namespace; empty disables prefixing)
- `MAX_TREE_DEPTH=50`

**API only**
- `ENABLE_COLLABORATION_MODE=false` (off by default; enabling requires WebSocket ingress configuration and `SERVER_WORKER_CLASS=geventwebsocket.gunicorn.workers.GeventWebSocketWorker`)
- `ALLOW_INLINE_STYLES=false` (Markdown CSP control)
- `ALLOW_UNSAFE_DATA_SCHEME=false`
- `ENABLE_HUMAN_INPUT_TIMEOUT_TASK=true` (toggle for beat-driven HITL timeout)
- `WORKFLOW_LOG_CLEANUP_ENABLED=false` (toggle for beat-driven log retention)

**Web**
- `NEXT_PUBLIC_SOCKET_URL=ws://localhost` (only used when collaboration is enabled)
- `ALLOW_INLINE_STYLES=false`, `ALLOW_UNSAFE_DATA_SCHEME=false`, `ALLOW_EMBED=false`
- `MAX_TREE_DEPTH=50`
- `ENABLE_WEBSITE_JINAREADER=true`, `ENABLE_WEBSITE_FIRECRAWL=true`, `ENABLE_WEBSITE_WATERCRAWL=true`

### Behavioural Changes Worth Knowing
- **PostgreSQL connections** — Dify 1.14.0's docker-compose raises `max_connections` to 200 for production replica counts. This deployment instead lowers `SQLALCHEMY_POOL_SIZE` (api/worker = 10, worker_beat = 5) to fit comfortably within the Burstable B1ms default (~50 connections). If you scale `min_replicas` up significantly or move to production load, raise pool sizes back to 30 and bump `max_connections` via `azurerm_postgresql_flexible_server_configuration` (or upgrade the PG tier).
- **Celery concurrency** — `CELERY_WORKER_AMOUNT=4` increases CPU/memory pressure on the worker container. The current 1 vCPU / 2 GiB sizing is sufficient for moderate load but monitor and resize if needed.
- **Plugin Daemon env-var names** — Unchanged. The plugin daemon container still reads `SERVER_KEY`, `DIFY_INNER_API_URL`, `DIFY_INNER_API_KEY` (the docker-compose variable names `PLUGIN_DAEMON_KEY` / `PLUGIN_DIFY_INNER_API_*` are only the *outer* env-substitution keys, not the names the binary reads).

### Optional: Enabling Collaboration Mode
Workflow collaboration is **not** enabled by this Terraform. To enable:
1. Set `ENABLE_COLLABORATION_MODE=true` and `SERVER_WORKER_CLASS=geventwebsocket.gunicorn.workers.GeventWebSocketWorker` on the `api` container.
2. Configure WebSocket ingress through nginx (`Upgrade`/`Connection` headers) and expose a public `wss://` endpoint.
3. Set `NEXT_PUBLIC_SOCKET_URL=wss://<your-domain>` on the `web` container.

### Key Differences from Docker Compose (still applicable)
1. Azure File Shares don't support symlinks - UV package manager needs copy mode
2. Azure PostgreSQL requires SSL - DB_SSL_MODE must be set to "require"
3. Service names must not contain underscores in Azure Container Apps

## References
- [Dify Official Documentation](https://docs.dify.ai)
- [Dify GitHub Repository](https://github.com/langgenius/dify)
- [Azure Container Apps Documentation](https://docs.microsoft.com/azure/container-apps)
- [mwakayama's Terraform Example](https://github.com/mwakayama/dify-azure-terraform-example-v1_2)
- [GitHub Issue Discussion](https://github.com/nikawang/dify-azure-terraform/issues/13)

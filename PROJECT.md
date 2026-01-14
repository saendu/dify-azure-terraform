# Dify Infrastructure Documentation

## Overview
This project contains the Terraform configuration for deploying a Dify environment on Azure. Dify is an open-source LLM application development platform that provides a complete solution for building AI applications.

**Current Version: Dify 1.11.3**

## Quick Start

1. Copy `terraform.tfvars.example` to `terraform.tfvars`
2. Update the required variables (especially `pgsql-password`)
3. Generate new secret keys for production:
   ```bash
   openssl rand -base64 42  # For dify-secret-key
   openssl rand -base64 42  # For dify-plugin-daemon-key
   openssl rand -base64 42  # For dify-inner-api-key
   ```
4. Run `terraform init && terraform apply`

⚠️ **IMPORTANT**: Never commit `terraform.tfvars` to version control!

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
- **Image**: langgenius/dify-sandbox:0.2.12
- **Scaling**: 1-10 replicas
- **Features**: Network access through SSRF proxy

#### 4. Plugin Daemon (New in Dify 1.x)
- **Role**: Plugin execution and management
- **Image**: langgenius/dify-plugin-daemon:0.5.2-local
- **Scaling**: 1-10 replicas
- **Critical Settings**:
  - `DB_SSL_MODE=require` (Required for Azure PostgreSQL)
  - UV package manager with copy mode (no symlinks)
  - Plugin working paths in `/tmp` for Azure compatibility
  - Correct env var names (see configuration section below)

#### 5. Worker
- **Role**: Background job processing (Celery)
- **Image**: langgenius/dify-api:1.11.3
- **Scaling**: 1-10 replicas
- **Mode**: worker

#### 6. API
- **Role**: Main application API
- **Image**: langgenius/dify-api:1.11.3
- **Scaling**: 1-10 replicas
- **Mode**: api
- **Features**: Migration enabled, marketplace integration

#### 7. Web
- **Role**: Frontend application
- **Image**: langgenius/dify-web:1.11.3
- **Scaling**: 1-10 replicas
- **Custom Domain**: agents.innoarchitects.ch (optional)

### Container Images (Dify 1.11.3)
- API: langgenius/dify-api:1.11.3
- Web: langgenius/dify-web:1.11.3
- Sandbox: langgenius/dify-sandbox:0.2.12
- Plugin Daemon: langgenius/dify-plugin-daemon:0.5.2-local

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
|---------------------|------------------------|------------|
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
1. Database credentials are managed through variables
2. Network isolation through dedicated subnet
3. SSRF proxy for sandbox security
4. Azure Container Apps environment with infrastructure subnet
5. SSL required for PostgreSQL connections
6. Plugin signature verification enabled

## Dependencies
- Azure Provider: hashicorp/azurerm (version 3.109.0)
- Azure Subscription ID: 76958d76-d94f-402b-a86b-fc6a720a2ba8

## File Structure
- `provider.tf`: Azure provider configuration
- `var.tf`: Variable definitions
- `vnet.tf`: Virtual network configuration
- `postgresql.tf`: PostgreSQL database setup
- `redis-cache.tf`: Redis cache configuration
- `fileshare.tf`: File share setup
- `aca-env.tf`: Container Apps environment and applications
- `mountfiles/`: Mount file configurations
  - `nginx/`: Nginx configuration files
  - `sandbox/`: Sandbox dependencies
  - `ssrfproxy/`: SSRF proxy configuration
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

## References
- [Dify Official Documentation](https://docs.dify.ai)
- [Dify GitHub Repository](https://github.com/langgenius/dify)
- [Azure Container Apps Documentation](https://docs.microsoft.com/azure/container-apps)
- [mwakayama's Terraform Example](https://github.com/mwakayama/dify-azure-terraform-example-v1_2)
- [GitHub Issue Discussion](https://github.com/nikawang/dify-azure-terraform/issues/13)

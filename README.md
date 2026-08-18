# Dify on Azure with Terraform

Deploy Dify 1.16.1 on Azure Container Apps with PostgreSQL Flexible Server, Azure Cache for Redis, and Azure Storage. Classic Agent and Agent v2 are installed together; Agent v2 is enabled by default.

This README is focused on one thing: making environment configuration repeatable and easy.

Important: this stack is now pinned to `azurerm` provider v4.x.

## What this Terraform deploys

| Component | Azure Service |
| --- | --- |
| nginx | Azure Container Apps |
| web | Azure Container Apps |
| api | Azure Container Apps |
| worker | Azure Container Apps |
| workerbeat | Azure Container Apps (singleton scheduler) |
| sandbox | Azure Container Apps |
| ssrfproxy | Azure Container Apps |
| plugindaemon | Azure Container Apps |
| agentbackend | Azure Container Apps (internal singleton) |
| localsandbox | Azure Container Apps (internal singleton) |
| agentssrfproxy | Azure Container Apps (internal singleton) |
| db | Azure Database for PostgreSQL Flexible Server |
| redis | Azure Cache for Redis |
| storage | Azure Storage Account (Blob + File Shares) |
| keyvault | Azure Key Vault (public endpoint, no private endpoint) |
| foundry | Azure AI Foundry Account + Project |

## Environment strategy (recommended)

Use one tfvars file per environment and always deploy with -var-file.

Example layout:

```text
environments/
   dev.tfvars
   stage.tfvars
   prod.tfvars
```


## Step-by-step deployment runbook

### 1. Prerequisites

- Terraform 1.5+
- Azure CLI installed
- Azure CLI logged in with access to target subscription
- Contributor right


### 2. Azure login and provider registration

```bash
az login
```

### 3. Create your environment variable file

Copy `environments/dev.tfvars copy.example` to your environment file, for example `environments/dev.tfvars`.

Agent v2 defaults to enabled. To select the classic Agent experience while keeping the Agent v2 services installed and ready, set:

```hcl
enable-dify-agent-v2 = false
```


### 4. Plan for an environment

#### 4a.
```bash
terraform init
```
#### 4b.
```bash
terraform plan -var-file="environments/dev.tfvars" -out="dev.tfplan"
```

Review:

### 6. Apply

```bash
terraform apply "dev.tfplan"
```

Or without a saved plan file:

```bash
terraform apply -var-file="environments/dev.tfvars"
```

### 7. Verify deployment

Get URL output:

```bash
terraform output dify_app_url
```

Quick checks in Azure:

```bash
az containerapp list -g "rg-<solution>-<env>" -o table
az postgres flexible-server list -g "rg-<solution>-<env>" -o table
az redis list -g "rg-<solution>-<env>" -o table
```

Foundry and Key Vault checks:

```bash
terraform output foundry_account_id
terraform output foundry_project_id
terraform output keyvault_name
```

If Terraform generated secrets for you, you can read them after apply:

```bash
terraform output -raw generated_dify_secret_key
terraform output -raw generated_dify_plugin_daemon_key
terraform output -raw generated_dify_inner_api_key
terraform output -raw generated_dify_sandbox_api_key
terraform output -raw generated_dify_agent_api_token
terraform output -raw generated_dify_agent_server_secret_key
terraform output -raw generated_dify_agent_shellctl_auth_token
```

### 8. Repeat for stage/prod

Use a different tfvars file per environment:

```bash
terraform plan  -var-file="environments/prod.tfvars" -out="prod.tfplan"
terraform apply "prod.tfplan"
```

## Terraform state security

- By default, this repo creates local `terraform.tfstate` and `terraform.tfstate.backup` files.
- State contains sensitive values, including generated application, database, Redis, and storage credentials.
- Keep state and environment `.tfvars` files ignored; never commit them to Git.
- For shared environments, configure an encrypted, access-controlled remote backend such as the Terraform `azurerm` backend.
- Restrict backend access to deployment identities and administrators, and enable the storage account's recovery and audit controls.
- If state is committed or otherwise exposed, remove it from distribution and rotate every affected credential.

## Practical checks after code review

From the current Terraform code, these are the most important things to set per environment:

- Required:
   - subscription-id
- Runtime secrets:
   - generated automatically and written to Key Vault
- Naming and uniqueness:
   - solution
   - env
- Network collision avoidance:
   - ip-prefix (if you deploy into an existing networked estate)

## Suggested deployment plan

1. Create environments/dev.tfvars with safe non-production sizing and unique names.
2. Run terraform plan with dev.tfvars and review only; do not apply yet.
3. Apply in dev and validate app URL and core service health.
4. Clone dev.tfvars into stage.tfvars and prod.tfvars, then adjust names, region, and secrets.
5. Plan and apply each environment independently using its own var-file.

## Common pitfalls to avoid

- Using long or invalid `solution`/`env` values can generate invalid resource names.
- Exposing generated secret outputs in terminal logs or CI artifacts is insecure.
- Committing tfvars with secrets to Git.

## Dify Agent v2 security boundary

Dify 1.16.1 warns that Agent v2 should only be made available to trusted users. This deployment adds the release's dedicated Agent SSRF proxy, generated bearer/JWE/shell-control secrets, internal-only service ingress, and shell path isolation.

Azure Container Apps does not reproduce Docker Compose's per-service bridge-network isolation inside one managed environment. Proxy ACLs restrict supported HTTP(S) flows, but arbitrary malicious sandbox code could attempt direct sockets within the shared ACA environment. Do not present Agent v2 to untrusted users without an additional Azure network-security design.

## Preserved and new timeouts

The upgrade preserves the existing values exactly:

- `PYTHON_ENV_INIT_TIMEOUT=120`
- `PLUGIN_MAX_EXECUTION_TIMEOUT=600`
- `WORKER_TIMEOUT=15`
- `FILES_ACCESS_TIMEOUT=300`
- `PLUGIN_DAEMON_TIMEOUT=600.0`
- `TEXT_GENERATION_TIMEOUT_MS=60000`
- `WORKFLOW_MAX_EXECUTION_TIME=1200`
- `ACCESS_TOKEN_EXPIRE_MINUTES=60`
- `REFRESH_TOKEN_EXPIRE_DAYS=30`
- `SQLALCHEMY_POOL_RECYCLE=3600`

Dify 1.16.1 adds `AGENT_BACKEND_STREAM_READ_TIMEOUT_SECONDS=30`, `AGENT_BACKEND_RUN_TIMEOUT_SECONDS=1200`, and `WORKFLOW_GENERATION_TIMEOUT_MS=180000`; these are additive and do not replace the existing settings.

## Fresh installation and upgrades

- Fresh database: `MIGRATION_ENABLED=true` runs Dify migrations when the API starts.
- Existing installation: back up PostgreSQL and storage before applying the new Container App revisions.
- If an existing environment reached 1.15.0 without running `flask backfill-plugin-auto-upgrade`, run that command once after database migration. It is not required for an empty database.

## References

- Dify docs: https://docs.dify.ai
- Dify GitHub: https://github.com/langgenius/dify
- Azure Container Apps docs: https://learn.microsoft.com/azure/container-apps
- Additional project notes: [PROJECT.md](./PROJECT.md)

## Post-deployment: access and configure Dify

This section starts after `terraform apply` has completed successfully.

### 1. Get the Dify URL

From the project root:

```bash
terraform output dify_app_url
https://nginx--oxc668g.whiteriver-7c20261f.westeurope.azurecontainerapps.io/
```

### 3. Complete first-time Dify initialization

When you open Dify for the first time:

1. Create the initial workspace owner account.
2. Set workspace name.
3. Sign in to the Dify console.

Important: the first account becomes the initial admin/owner for that workspace.

### 4. Prepare model credentials (Azure side)

Before adding models in Dify, make sure you have:

- An Azure OpenAI (or Azure AI model deployment with OpenAI-compatible endpoint) deployment for chat/completions.
- An embedding deployment (recommended for knowledge and RAG features).
- Endpoint and API key.

If you are using Azure OpenAI, endpoint format is:

```text
https://<resource>.openai.azure.com/openai/v1
```

The `/openai/v1` suffix is required.

### 5. Configure model provider in Dify

In Dify UI:

1. Go to `Settings` -> `Model Provider`.
2. Click `Add Model`.
3. Choose `Azure OpenAI`.
4. Fill in:
   - Endpoint
   - API key
   - Deployment name (use deployment name, not base model family name)
5. Save and run provider test.

Repeat for all required model types (chat and embeddings at minimum).

### 6. Configure knowledge retrieval defaults (recommended)

In Dify UI:

1. Open `Knowledge`.
2. Create a test knowledge base.
3. Select your embedding model.
4. Upload a small sample document.
5. Run a test query to verify retrieval quality.

This validates model connectivity and vector flow early.

### 7. Validate plugin and internal routing

This Terraform stack includes plugin daemon and nginx routing for plugin endpoints.

Quick checks:

1. Open Dify `Plugins` page and ensure it loads.
2. Install a lightweight/test plugin.
3. Confirm installation succeeds without daemon connection errors.

If plugin operations fail, inspect logs for `plugindaemon`, `api`, and `nginx`.

### 8. Create and test your first app

In Dify UI:

1. Create a new app (Chat app is the fastest test).
2. Attach your configured chat model.
3. Add a simple system prompt.
4. Publish and test in the playground.

Success criteria:

- Prompt returns responses.
- No model auth/deployment errors.
- No plugin daemon or worker errors in runtime logs.

### 9. Optional production hardening checklist

- Use a custom domain and certificate on the ingress endpoint.
- Restrict public access (IP restrictions/WAF/reverse proxy as needed).
- Rotate model keys and app secrets regularly.
- Configure monitoring/alerts for Container Apps, PostgreSQL, and Redis.
- Back up PostgreSQL and test restore procedure.

## Day-2 operations: where to update configuration

- Infrastructure/env vars: update Terraform files and re-apply.
- App logic, prompts, tools, apps: update in Dify UI.
- Secrets used by containers: update in Key Vault and roll out a new revision when required.

This split keeps infra reproducible while allowing fast iteration in Dify.

# Notes Sändu (deprecated)

## Checklist
- [ ] Update variables in `var.tf`
- [ ] Set passwords in `terraform.tfvars` (see: Generate secure keys)
- [ ] Clean state if needed:
```bash
  rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup *.tfplan
```

## Commands

```bash
# Login
az login
az login --use-device-code --tenant <name>.onmicrosoft.com 
az account set --subscription <subscriptionID>

# Register provider (first time only)
az provider register --namespace Microsoft.App

# Deploy
terraform init
terraform plan
terraform apply
```

## Production Variables

### Existing resource group
terraform import azurerm_resource_group.rg /subscriptions/<subscriptionId>/resourceGroups/<groupName>

⚠️ **Must change for production:**

| Variable | Description |
| --- | --- |
| `subscription-id` | Your Azure subscription ID |
| `pgsql-password` | PostgreSQL password (no default, required) |
| `dify-secret-key` | API encryption key |
| `dify-plugin-daemon-key` | Plugin daemon auth key |
| `dify-inner-api-key` | Internal API key |
| `dify-sandbox-api-key` | Sandbox execution key |

#### Generate secure keys
Generate secure keys and write them to `terraform.tfvars`:
```bash
cat <<EOF > terraform.tfvars
pgsql-password         = "$(openssl rand -base64 24 | tr -d '/+=' | head -c 32)"
dify-secret-key        = "$(openssl rand -base64 42)"
dify-plugin-daemon-key = "$(openssl rand -base64 42)"
dify-inner-api-key     = "$(openssl rand -base64 42)"
dify-sandbox-api-key   = "$(openssl rand -base64 42)"
EOF
```

**Should also review:**
- `group-name` - Resource group name
- `region` - Azure region
- `storage-account`, `redis`, `psql-flexible` - Must be globally unique
# Notes Sändu

## Checklist
- [ ] Update variables in `var.tf`
- [ ] Set passwords in `terraform.tfvars`
- [ ] Clean state if needed:
  ```bash
  rm -rf .terraform .terraform.lock.hcl terraform.tfstate
  ```

## Commands

```bash
# Login
az login
az account set --subscription 76958d76-d94f-402b-a86b-fc6a720a2ba8

# Register provider (first time only)
az provider register --namespace Microsoft.App

# Deploy
terraform init
terraform plan
terraform apply
```

---

# Dify Azure Terraform

Deploy [Dify](https://github.com/langgenius/dify) (v1.11.3) on Azure using Terraform.

## Architecture

| Component | Azure Service |
|-----------|---------------|
| nginx | Container Apps |
| web | Container Apps |
| api | Container Apps |
| worker | Container Apps |
| sandbox | Container Apps |
| ssrf_proxy | Container Apps |
| plugin_daemon | Container Apps |
| db | PostgreSQL Flexible Server |
| redis | Azure Cache for Redis |
| storage | Azure Blob Storage |

## Production Variables

⚠️ **Must change for production:**

| Variable | Description |
|----------|-------------|
| `subscription-id` | Your Azure subscription ID |
| `pgsql-password` | PostgreSQL password (no default, required) |
| `dify-secret-key` | API encryption key |
| `dify-plugin-daemon-key` | Plugin daemon auth key |
| `dify-inner-api-key` | Internal API key |
| `dify-sandbox-api-key` | Sandbox execution key |

Generate secure keys:
```bash
openssl rand -base64 42
```

**Should also review:**
- `group-name` - Resource group name
- `region` - Azure region
- `storage-account`, `redis`, `psql-flexible` - Must be globally unique

## Quick Start

1. Copy and configure variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

2. Deploy:
   ```bash
   terraform init
   terraform apply
   ```

## Documentation

See [PROJECT.md](PROJECT.md) for detailed configuration and troubleshooting.

## References

- [Dify Documentation](https://docs.dify.ai)
- [Dify GitHub](https://github.com/langgenius/dify)
- [Azure Container Apps](https://docs.microsoft.com/azure/container-apps)

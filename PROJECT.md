# Dify Infrastructure Documentation

## Overview
This project contains the Terraform configuration for deploying a Dify environment on Azure. Dify is an open-source LLM application development platform that provides a complete solution for building AI applications.

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

4. **Caching**
   - Azure Redis Cache
   - Name: inalatestdifyredis
   - Used for session management and caching

5. **Storage**
   - Azure Storage Account
   - Name: inalatestdifystorage
   - Container: dfy
   - Used for file storage and sharing

### Azure Container Apps Environment
- Name: dify-ina-latest-env
- Log Analytics Workspace: dify-loga
- Infrastructure Subnet: Dedicated subnet for container apps
- Workload Profile: Consumption-based

### Container Applications
1. **Nginx**
   - Role: Reverse proxy and static file serving
   - HTTP Scale Rule: 10 concurrent requests
   - Storage: Nginx file share

2. **SSRF Proxy**
   - Role: Security proxy for sandbox environment
   - Storage: SSRF proxy file share

3. **Sandbox**
   - Role: Isolated environment for code execution
   - Storage: Sandbox file share

4. **Worker**
   - Role: Background job processing
   - Environment Variables: Configured for Redis and PostgreSQL connectivity

5. **API**
   - Role: Main application API
   - Environment Variables: Configured for all required services
   - Storage: Nginx file share

6. **Web**
   - Role: Frontend application
   - Environment Variables: Configured for API connectivity
   - Custom Domain: agents.innoarchitects.ch

### Container Images
- API: langgenius/dify-api:1.1.3
- Sandbox: langgenius/dify-sandbox:0.2.5
- Web: langgenius/dify-web:1.1.3

## Security Considerations
1. Database credentials are managed through variables
2. Network isolation through dedicated subnet
3. SSRF proxy for sandbox security
4. Azure Container Apps environment with infrastructure subnet

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
- `fileshare_module/`: File share module

## Deployment Notes
1. The infrastructure is designed for production use with proper isolation
2. All services are deployed in Switzerland North region
3. The setup includes proper logging and monitoring through Log Analytics
4. File storage is managed through Azure Storage with dedicated shares
5. The environment uses consumption-based scaling for cost optimization

## Maintenance Considerations
1. Regular updates of container images should be planned
2. Monitor Redis cache and PostgreSQL performance
3. Review Log Analytics data retention (currently 30 days)
4. Regular backup of PostgreSQL database
5. Monitor storage account usage and costs 
# Notes Sändu

## Todos
[] Change variables in var.tf
[] Change all passwords
[] Delete .terraform.lock.hcl AND terraform.tfstate

## Terraform
az login
az account set --subscription 76958d76-d94f-402b-a86b-fc6a720a2ba8

### requirements
az provider register --namespace Microsoft.App
az provider show --namespace Microsoft.App

### run script
terraform init
terraform plan
terraform apply

## ChatSource
https://chatgpt.com/g/g-VIsiBgv06-azure-expert/c/0289d230-55bf-4131-88b3-46dc21419275

## Create Self-Signed Certificate in Azure Key Vault
az keyvault certificate create --vault-name <your-key-vault-name> --name <certificate-name> --policy "$(az keyvault certificate get-default-policy)"

## Download the Certificate as PFX File
az keyvault secret download --vault-name <your-key-vault-name> --name <certificate-name> --file <output-file.pfx> --encoding base64

## Extract the Private Key and Certificate
openssl pkcs12 -in output-file.pfx -nocerts -out private-key.pem -nodes
openssl pkcs12 -in output-file.pfx -nokeys -out certificate.pem

## Combine the Private Key and Certificate into a Single PEM File
cat private-key.pem certificate.pem > combined.pem

## Export the Combined PEM to a New PFX File with a Password
openssl pkcs12 -export -in combined.pem -out new-output-file.pfx -password pass:Test0001

# dify-azure-terraform
Deploy [langgenius/dify](https://github.com/langgenius/dify), an LLM based chat bot app on Azure with terraform.

### Topology
Front-end access:
- nginx -> Azure Container Apps (Serverless)

Back-end components:
- web -> Azure Container Apps (Serverless)
- api -> Azure Container Apps (Serverless)
- worker -> Azure Container Apps (minimum of 1 instance)
- sandbox -> Azure Container Apps (Serverless)
- ssrf_proxy -> Azure Container Apps (Serverless)
- db -> Azure Database for PostgreSQL
- vectordb -> Azure Database for PostgreSQL
- redis -> Azure Cache for Redis

Before you provision Dify, please check and set the variables in var.tf file.

### Terraform Variables Documentation

This document provides detailed descriptions of the variables used in the Terraform configuration for setting up the Dify environment.

#### Subscription ID

- **Variable Name**: `subscription-id`
- **Type**: `string`
- **Default Value**: `0000000000000`

#### Virtual Network Variables

##### Region

- **Variable Name**: `region`
- **Type**: `string`
- **Default Value**: `japaneast`

##### VNET Address IP Prefix

- **Variable Name**: `ip-prefix`
- **Type**: `string`
- **Default Value**: `10.99`

#### Storage Account

- **Variable Name**: `storage-account`
- **Type**: `string`
- **Default Value**: `acadifytest`

##### Storage Account Container

- **Variable Name**: `storage-account-container`
- **Type**: `string`
- **Default Value**: `dfy`

#### Redis

- **Variable Name**: `redis`
- **Type**: `string`
- **Default Value**: `acadifyredis`

#### PostgreSQL Flexible Server

- **Variable Name**: `psql-flexible`
- **Type**: `string`
- **Default Value**: `acadifypsql`

##### PostgreSQL User

- **Variable Name**: `pgsql-user`
- **Type**: `string`
- **Default Value**: `user`

##### PostgreSQL Password

- **Variable Name**: `pgsql-password`
- **Type**: `string`
- **Default Value**: `#QWEASDasdqwe`

#### ACA Environment Variables

##### ACA Environment

- **Variable Name**: `aca-env`
- **Type**: `string`
- **Default Value**: `dify-aca-env`

##### ACA Log Analytics Workspace

- **Variable Name**: `aca-loga`
- **Type**: `string`
- **Default Value**: `dify-loga`

##### ACA Certificate Path

- **Variable Name**: `aca-cert-path`
- **Type**: `string`
- **Default Value**: `./certs/difycert.pfx`

##### ACA Certificate Password

- **Variable Name**: `aca-cert-password`
- **Type**: `string`
- **Default Value**: `password`

##### ACA Dify Customer Domain

- **Variable Name**: `aca-dify-customer-domain`
- **Type**: `string`
- **Default Value**: `dify.nikadwang.com`

#### Container Images

##### Dify API Image

- **Variable Name**: `dify-api-image`
- **Type**: `string`
- **Default Value**: `langgenius/dify-api:0.6.16`

##### Dify Sandbox Image

- **Variable Name**: `dify-sandbox-image`
- **Type**: `string`
- **Default Value**: `langgenius/dify-sandbox:0.2.1`

##### Dify Web Image

- **Variable Name**: `dify-web-image`
- **Type**: `string`
- **Default Value**: `langgenius/dify-web:0.6.16`
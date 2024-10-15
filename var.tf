variable "subscription-id" {
  type = string
  default = "76958d76-d94f-402b-a86b-fc6a720a2ba8"
}

variable "group-name" {
  type = string
  default = "dify-ina"
}

#virtual network variables
variable "region" {
  type = string
  default = "switzerlandnorth"
}

variable "ip-prefix" {
  type = string
  default = "10.99"
}
#end virtual network variables

variable "storage-account" {
  type = string
  default = "inadifystorage"
}

variable "storage-account-container" {
  type = string
  default = "dfy"
}

variable "redis" {
  type = string
  default = "inadifyredis"
}

variable "psql-flexible" {
  type = string
  default = "inadifypsql"
}

variable "pgsql-user" {
  type = string
  default = "user"
}

variable "pgsql-password" {
  type = string
  default = "Test0001"
}

variable "aca-env" {
  type = string
  default = "dify-ina-env"
}

variable "aca-loga" {
  type = string
  default = "dify-loga"
}

variable "aca-dify-customer-domain" {
  type = string
  default = "agents.innoarchitects.ch"
}

variable "dify-api-image" {
  type = string
  default = "langgenius/dify-api:0.10.0-beta3"
}

variable "dify-sandbox-image" {
  type = string
  default = "langgenius/dify-sandbox:0.2.5"
}

variable "dify-web-image" {
  type = string
  default = "langgenius/dify-web:0.10.0-beta3"
}


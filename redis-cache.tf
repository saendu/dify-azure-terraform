#create resource group for redis cache
# resource "azurerm_resource_group" "redis" {
#   name     = "rg-${var.region}-redis"
#   location = var.region
# }

#create azure redis cache with vnet integration
resource "azurerm_redis_cache" "redis" {
  name                = var.redis
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  capacity            = 0
  family              = "C"
  sku_name            = "Standard"
  enable_non_ssl_port = true
  minimum_tls_version = "1.2"

  public_network_access_enabled = true
  redis_version       = "6"
  
  # subnet_id           = azurerm_subnet.redissubnet.id
  # zones               = [ "1" ]

  redis_configuration {
    maxmemory_policy = "allkeys-lru"
  }
}

output "redis_cache_hostname" {
  value = azurerm_redis_cache.redis.hostname
}

output "redis_cache_key" {
  value = azurerm_redis_cache.redis.primary_access_key
  sensitive = true
}

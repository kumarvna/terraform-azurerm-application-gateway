#---------------------------
# Local declarations
#---------------------------
locals {
  backend_address_pool_name      = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-bapool"
  backend_http_settings_name     = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-be-http-set"
  frontend_port_name             = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-feport"
  frontend_ip_configuration_name = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-feip"
  backend_http_settings          = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-be-htst"
  http_probe_name                = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-be-htpb"
  http_listener_name             = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-be-htln"
  listener_name                  = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-httplstn"
  request_routing_rule_name      = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-rqrt"
  redirect_configuration_name    = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-rdrcfg"
  gateway_ip_configuration_name  = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-gwipc"
  ssl_certificate_name           = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-ssl"
  trusted_root_certificate_name  = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-ssl-trust-cert"
  url_path_map_name              = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-upm-name"
}

#----------------------------------------------------------
# Resource Group, VNet, Subnet selection & Random Resources
#----------------------------------------------------------
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_subnet" "snet" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.rg.name
}

data "azurerm_log_analytics_workspace" "logws" {
  count               = var.log_analytics_workspace_name != null ? 1 : 0
  name                = var.log_analytics_workspace_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

data "azurerm_storage_account" "storeacc" {
  count               = var.hub_storage_account_name != null ? 1 : 0
  name                = var.hub_storage_account_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "random_string" "str" {
  length  = 6
  special = false
  upper   = false
  keepers = {
    domain_name_label = var.app_gateway_name
  }
}

#-----------------------------------
# Public IP for Load Balancer
#-----------------------------------
resource "azurerm_public_ip" "pip" {
  name                = lower("${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-gw-pip")
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = var.public_ip_allocation_method
  sku                 = var.public_ip_sku
  domain_name_label   = format("gw%s%s", lower(replace(var.app_gateway_name, "/[[:^alnum:]]/", "")), random_string.str.result)
  tags                = merge({ "ResourceName" = lower("${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-gw-pip") }, var.tags, )
}


resource "azurerm_application_gateway" "main" {
  name                = lower("appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}")
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  enable_http2        = var.enable_http2
  zones               = var.zones
  tags                = merge({ "ResourceName" = lower("appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}") }, var.tags, )

  sku {
    name     = var.app_gateway_sku.name
    tier     = var.app_gateway_sku.tier
    capacity = var.app_gateway_sku.capacity
  }

  dynamic "autoscale_configuration" {
    for_each = var.capacity
    content {
      min_capacity = lookup(capacity.value, "min_capacity")
      max_capacity = lookup(capacity.value, "max_capacity")
    }
  }

  gateway_ip_configuration {
    name      = "local.gateway_ip_configuration_name"
    subnet_id = data.azurerm_subnet.snet.id
  }

  frontend_ip_configuration {
    name                          = local.frontend_ip_configuration_name
    public_ip_address_id          = azurerm_public_ip.pip.id
    private_ip_address_allocation = var.private_ip_address != null ? "Static" : null
    private_ip_address            = var.private_ip_address != true ? var.private_ip_address : null
    subnet_id                     = var.private_ip_address != true ? data.azurerm_subnet.snet.id : null
  }

  frontend_port {
    name = var.frontend_port == 80 ? "${local.frontend_port_name}-80" : "${local.frontend_port_name}-443"
    port = var.frontend_port
  }

  dynamic "backend_address_pool" {
    for_each = var.backend_address_pool
    content {
      name         = lookup(var.backend_address_pool, "name", local.backend_address_pool_name)
      fqdns        = lookup(var.backend_address_pool, "fqdns", null)
      ip_addresses = lookup(var.backend_address_pool, "ip_addresses", null)
    }
  }

  # authentication_certificate and trusted_root_certificate dynamic blocks to be added here 

  dynamic "backend_http_settings" {
    for_each = var.backend_http_settings
    content {
      name                                = lookup(var.backend_http_settings, "name", local.backend_http_settings)
      cookie_based_affinity               = lookup(var.backend_http_settings, "enable_cookie_based_affinity", "Disabled")
      affinity_cookie_name                = lookup(var.backend_http_settings, "affinity_cookie_name", null)
      path                                = lookup(var.backend_http_settings, "path", "/")
      port                                = lookup(var.backend_http_settings, "port", 443)
      protocol                            = lookup(var.backend_http_settings, "protocol", "Https")
      request_timeout                     = lookup(var.backend_http_settings, "request_timeout", 20)
      host_name                           = lookup(var.backend_http_settings, "host_name", null)
      probe_name                          = local.http_probe_name
      trusted_root_certificate_names      = lookup(var.backend_http_settings, "port") == 443 ? [local.trusted_root_certificate_name] : null
      pick_host_name_from_backend_address = lookup(var.backend_http_settings, "pick_host_name_from_backend_address", false)


      connection_draining {
        enabled           = lookup(var.backend_http_settings, "enable_connection_draining", true)
        drain_timeout_sec = lookup(var.backend_http_settings, "connection_drain_timeout", 600)
      }
    }
  }

  dynamic "probe" {
    for_each = var.health_probe
    content {
      name                                      = lookup(var.health_probe, "name", local.http_probe_name)
      host                                      = lookup(var.health_probe, "pick_host_name_from_backend_address") == false ? lookup(var.health_probe, "host", "127.0.0.1") : null
      interval                                  = lookup(var.health_probe, "interval", 30)
      port                                      = lookup(var.health_probe, "port", 80)
      protocol                                  = lookup(var.health_probe, "port") == 80 ? "Http" : "Https"
      path                                      = lookup(var.health_probe, "path", "/")
      timeout                                   = lookup(var.health_probe, "timeout", 30)
      unhealthy_threshold                       = lookup(var.health_probe, "unhealthy_threshold", 3)
      pick_host_name_from_backend_http_settings = lookup(var.health_probe, "pick_host_name_from_backend_http_settings", false)
      minimum_servers                           = lookup(var.health_probe, "minimum_servers", 0)
    }
  }

  dynamic "http_listener" {
    for_each = var.http_listeners
    content {
      name                           = lookup(var.http_listeners, "name", local.http_listener_name)
      frontend_ip_configuration_name = local.frontend_ip_configuration_name
      frontend_port_name             = var.frontend_port == 80 ? "${local.frontend_port_name}-80" : "${local.frontend_port_name}-443"
      protocol                       = var.frontend_port == 80 ? "Http" : "Https"
      require_sni                    = lookup(var.http_listeners, "require_sni", false)
      host_name                      = lookup(var.http_listeners, "host_name", null)
      host_names                     = lookup(var.http_listeners, "host_names", null)
      ssl_certificate_name           = var.frontend_port == 443 ? local.ssl_certificate_name : null
    }
  }

  dynamic "request_routing_rule" {
    for_each = var.request_routing_rules
    content {
      name                       = lookup(var.request_routing_rules, "name", local.request_routing_rule_name)
      rule_type                  = lookup(var.request_routing_rules, "rule_type", "Basic")
      http_listener_name         = lookup(var.request_routing_rules, "http_listener_name", local.http_listener_name)
      backend_address_pool_name  = lookup(var.request_routing_rules, "backend_address_pool_name", local.backend_address_pool_name)
      backend_http_settings_name = lookup(var.request_routing_rules, "backend_http_settings_name", local.backend_http_settings_name)
      url_path_map_name          = lookup(var.request_routing_rules, "url_path_map_name", local.url_path_map_name)
    }
  }


  dynamic "ssl_certificate" {
    for_each = var.ssl_certificate
    content {
      name                = local.ssl_certificate_name
      data                = base64encode(file(lookup(var.ssl_certificate, "data", null)))
      password            = lookup(var.ssl_certificate, "password", null)
      key_vault_secret_id = lookup(var.ssl_certificate, "key_vault_secret_id", null)
    }
  }

  dynamic "ssl_policy" {
    for_each = var.ssl_policy
    content {
      disabled_protocols   = lookup(var.ssl_policy, "disabled_protocols", [])
      policy_type          = lookup(var.ssl_policy, "policy_type", "Predefined")
      policy_name          = lookup(var.ssl_policy, "policy_name", "AppGwSslPolicy20170401S")
      cipher_suites        = lookup(var.ssl_policy, "cipher_suites", [])
      min_protocol_version = lookup(var.ssl_policy, "min_protocol_version", null)
    }
  }

  dynamic "url_path_map" {
    for_each = var.url_path_maps
    content {
      name                               = url_path_map.value.name
      default_backend_http_settings_name = url_path_map.value.default_backend_http_settings_name
      default_backend_address_pool_name  = url_path_map.value.default_backend_address_pool_name

      dynamic "path_rule" {
        for_each = url_path_map.value.path_rules
        content {
          name                       = path_rule.value.name
          backend_address_pool_name  = path_rule.value.backend_address_pool_name
          backend_http_settings_name = path_rule.value.backend_http_settings_name
          paths                      = path_rule.value.paths
        }
      }
    }
  }


  #waf_configuration {}

  #custom_error_configuration {}

  #firewall_policy_id {}

  #redirect_configuration {}

  #identity {}


  #rewrite_rule_set {}


}

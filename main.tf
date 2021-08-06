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
  count               = var.storage_account_name != null ? 1 : 0
  name                = var.storage_account_name
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
    name     = var.sku.name
    tier     = var.sku.tier
    capacity = var.sku.capacity
  }

  dynamic "autoscale_configuration" {
    for_each = var.autoscale_configuration != null ? [var.autoscale_configuration] : []
    content {
      min_capacity = lookup(autoscale_configuration.value, "min_capacity")
      max_capacity = lookup(autoscale_configuration.value, "max_capacity")
    }
  }

  gateway_ip_configuration {
    name      = local.gateway_ip_configuration_name
    subnet_id = data.azurerm_subnet.snet.id
  }

  frontend_ip_configuration {
    name                          = local.frontend_ip_configuration_name
    public_ip_address_id          = azurerm_public_ip.pip.id
    private_ip_address            = var.private_ip_address != null ? var.private_ip_address : null
    private_ip_address_allocation = var.private_ip_address != null ? "Static" : null
    subnet_id                     = var.private_ip_address != null ? data.azurerm_subnet.snet.id : null
  }

  frontend_port {
    name = var.frontend_port == 80 ? "${local.frontend_port_name}-80" : "${local.frontend_port_name}-443"
    port = var.frontend_port

  }

  dynamic "backend_address_pool" {
    for_each = var.backend_address_pool != null ? [var.backend_address_pool] : []
    content {
      name         = lookup(var.backend_address_pool, "name", local.backend_address_pool_name)
      fqdns        = lookup(var.backend_address_pool, "fqdns", null)
      ip_addresses = lookup(var.backend_address_pool, "ip_addresses", null)
    }
  }

  dynamic "backend_http_settings" {
    for_each = var.backend_http_settings != null ? [var.backend_http_settings] : []
    content {
      name                                = lookup(var.backend_http_settings, "name", local.backend_http_settings_name)
      cookie_based_affinity               = lookup(var.backend_http_settings, "cookie_based_affinity", "Disabled")
      affinity_cookie_name                = lookup(var.backend_http_settings, "affinity_cookie_name", null)
      path                                = lookup(var.backend_http_settings, "path", "/")
      port                                = lookup(var.backend_http_settings, "port", 443)
      probe_name                          = lookup(var.backend_http_settings, "probe_name", local.probe_name)
      protocol                            = lookup(var.backend_http_settings, "protocol", "Https")
      request_timeout                     = lookup(var.backend_http_settings, "request_timeout", 30)
      host_name                           = var.backend_http_settings.pick_host_name_from_backend_address == false ? lookup(var.backend_http_settings, "host_name") : null
      pick_host_name_from_backend_address = lookup(var.backend_http_settings, "pick_host_name_from_backend_address", false)

      dynamic "authentication_certificate" {
        for_each = var.backend_http_settings.authentication_certificate != null ? [var.backend_http_settings.authentication_certificate] : []
        content {
          name = var.backend_http_settings.authentication_certificate.name
        }
      }

      trusted_root_certificate_names = lookup(var.backend_http_settings, "trusted_root_certificate_names", null)

      dynamic "connection_draining" {
        for_each = var.backend_http_settings.connection_draining != null ? [var.backend_http_settings.connection_draining] : []
        content {
          enabled           = var.backend_http_settings.enable_connection_draining
          drain_timeout_sec = var.backend_http_settings.connection_drain_timeout
        }
      }
    }
  }

  dynamic "http_listener" {
    for_each = var.http_listener != null ? [var.http_listener] : []
    content {
      name                           = lookup(var.http_listener, "name", local.http_listener_name)
      frontend_ip_configuration_name = local.frontend_ip_configuration_name
      frontend_port_name             = var.frontend_port == 80 ? "${local.frontend_port_name}-80" : "${local.frontend_port_name}-443"
      host_name                      = lookup(var.http_listener, "host_name", null)
      host_names                     = lookup(var.http_listener, "host_names", null)
      protocol                       = var.frontend_port == 80 ? "Http" : "Https"
      require_sni                    = lookup(var.http_listener, "require_sni", false)
      ssl_certificate_name           = var.frontend_port == 443 ? local.ssl_certificate_name : null
      firewall_policy_id             = var.http_listener.firewall_policy_id
      dynamic "custom_error_configuration" {
        for_each = var.http_listener.custom_error_configuration != null ? [var.http_listener.custom_error_configuration] : []
        content {
          status_code           = var.http_listener.custom_error_configuration.status_code
          custom_error_page_url = var.http_listener.custom_error_configuration.custom_error_page_url
        }
      }
    }
  }

  dynamic "request_routing_rule" {
    for_each = var.request_routing_rule != null ? [var.request_routing_rule] : []
    content {
      name                        = lookup(var.request_routing_rule, "name", local.request_routing_rule_name)
      rule_type                   = lookup(var.request_routing_rule, "rule_type", "Basic")
      http_listener_name          = local.http_listener_name
      backend_address_pool_name   = var.request_routing_rule.redirect_configuration_name != null ? local.backend_address_pool_name : null
      backend_http_settings_name  = var.request_routing_rule.redirect_configuration_name != null ? local.backend_http_settings_name : null
      redirect_configuration_name = lookup(var.request_routing_rule, "redirect_configuration_name", null)
      rewrite_rule_set_name       = lookup(var.request_routing_rule, "rewrite_rule_set_name", null)
      url_path_map_name           = lookup(var.request_routing_rule, "url_path_map_name", null)
    }
  }

}



/* 
must:
name
rg
location
sku 
autoscale_configuration
gateway_ip_configuration 
frontend_ip_configuration
frontend_port 
backend_address_pool
backend_http_settings
http_listener
request_routing_rule

optional:
identity 
authentication_certificate
trusted_root_certificate 
ssl_policy
ssl_certificate 
probe 
url_path_map
waf_configuration
custom_error_configuration
firewall_policy_id
redirect_configuration
rewrite_rule_set
 */

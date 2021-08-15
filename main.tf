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
  gateway_ip_configuration_name  = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-gwipc"
  ssl_certificate_name           = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-ssl"
  trusted_root_certificate_name  = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-ssl-trust-cert"
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

#-----------------------------------
# Public IP for Load Balancer
#-----------------------------------
resource "azurerm_public_ip" "pip" {
  name                = lower("${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-gw-pip")
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = var.sku.tier == "Standard" ? "Dynamic" : "Static" #var.public_ip_allocation_method
  sku                 = var.sku.tier == "Standard" ? "Basic" : "Standard" #var.public_ip_sku
  tags                = merge({ "ResourceName" = lower("${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-gw-pip") }, var.tags, )
}

resource "azurerm_application_gateway" "main" {
  name                = lower("appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}")
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  enable_http2        = var.enable_http2
  zones               = var.zones
  firewall_policy_id  = var.firewall_policy_id != null ? var.firewall_policy_id : null
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
      probe_name                          = lookup(var.backend_http_settings, "probe_name", null)
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
      backend_address_pool_name   = var.request_routing_rule.redirect_configuration_name == null ? local.backend_address_pool_name : null #local.backend_address_pool_name : null
      backend_http_settings_name  = var.request_routing_rule.redirect_configuration_name == null ? local.backend_http_settings_name : null
      redirect_configuration_name = lookup(var.request_routing_rule, "redirect_configuration_name", null)
      rewrite_rule_set_name       = lookup(var.request_routing_rule, "rewrite_rule_set_name", null)
      url_path_map_name           = lookup(var.request_routing_rule, "url_path_map_name", null)
    }
  }

  dynamic "identity" {
    for_each = var.identity_ids != null ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = var.identity_ids
    }
  }
  dynamic "authentication_certificate" {
    for_each = var.authentication_certificate != null ? [var.authentication_certificate] : []
    content {
      name = var.authentication_certificate.name
      data = filebase64(lookup(var.authentication_certificate, "data"))
    }
  }

  dynamic "trusted_root_certificate" {
    for_each = var.trusted_root_certificate != null ? [var.trusted_root_certificate] : []
    content {
      name = var.trusted_root_certificate.name
      data = filebase64(lookup(var.trusted_root_certificate, "data"))
    }
  }

  dynamic "ssl_policy" {
    for_each = var.ssl_policy != null ? [var.ssl_policy] : []
    content {
      disabled_protocols   = var.ssl_policy.policy_type == null && var.ssl_policy.policy_name == null ? var.ssl_policy.disabled_protocols : null
      policy_type          = lookup(var.ssl_policy, "policy_type", "Predefined")
      policy_name          = var.ssl_policy.policy_type == "Predefined" ? var.ssl_policy.policy_name : null
      cipher_suites        = var.ssl_policy.policy_type == "Custom" ? var.ssl_policy.cipher_suites : null
      min_protocol_version = var.ssl_policy.min_protocol_version
    }
  }

  dynamic "ssl_certificate" {
    for_each = var.ssl_certificate != null ? [var.ssl_certificate] : []
    content {
      name                = local.ssl_certificate_name
      data                = var.ssl_certificate.key_vault_secret_id == null ? filebase64(lookup(var.ssl_certificate, "data")) : null
      password            = var.ssl_certificate.key_vault_secret_id == null ? var.ssl_certificate.password : null
      key_vault_secret_id = lookup(var.ssl_certificate, "key_vault_secret_id", null)
    }
  }

  dynamic "probe" {
    for_each = var.health_probe != null ? [var.health_probe] : []
    content {
      name                                      = local.http_probe_name
      host                                      = var.health_probe.pick_host_name_from_backend_address == false ? lookup(var.health_probe, "host", "127.0.0.1") : null
      interval                                  = lookup(var.health_probe, "interval", 30)
      protocol                                  = var.health_probe.port == 80 ? "Http" : "Https"
      path                                      = lookup(var.health_probe, "path", "/")
      timeout                                   = lookup(var.health_probe, "timeout", 30)
      unhealthy_threshold                       = lookup(var.health_probe, "unhealthy_threshold", 3)
      port                                      = lookup(var.health_probe, "port", 80)
      pick_host_name_from_backend_http_settings = lookup(var.health_probe, "pick_host_name_from_backend_http_settings", false)
      minimum_servers                           = lookup(var.health_probe, "minimum_servers", 0)
    }
  }

  dynamic "url_path_map" {
    for_each = var.url_path_maps[*]
    content {
      name                                = lookup(var.url_path_maps, "name", null)
      default_backend_address_pool_name   = var.url_path_maps.default_redirect_configuration_name == null ? local.backend_address_pool_name : null
      default_backend_http_settings_name  = var.url_path_maps.default_redirect_configuration_name == null ? local.backend_http_settings_name : null
      default_redirect_configuration_name = lookup(var.url_path_maps, "default_redirect_configuration_name", null)
      default_rewrite_rule_set_name       = lookup(var.url_path_maps, "default_rewrite_rule_set_name", null)

      dynamic "path_rule" {
        for_each = lookup(var.url_path_maps.value, "path_rule")
        content {
          name                        = lookup(var.url_path_maps.path_rule.value, "path_rule_name", null)
          paths                       = flatten([lookup(var.url_path_maps.path_rule.value, "paths", null)])
          backend_address_pool_name   = var.url_path_maps.path_rule.value.redirect_configuration_name == null ? local.backend_address_pool_name : null
          backend_http_settings_name  = var.url_path_maps.path_rule.value.redirect_configuration_name == null ? local.backend_http_settings_name : null
          redirect_configuration_name = lookup(var.url_path_maps.path_rule.value, "redirect_configuration_name", null)
          rewrite_rule_set_name       = lookup(var.url_path_maps.path_rule.value, "rewrite_rule_set_name", null)
          firewall_policy_id          = lookup(var.url_path_maps.path_rule.value, "firewall_policy_id", null)
        }
      }
    }
  }

  dynamic "redirect_configuration" {
    for_each = var.redirect_configuration[*]
    content {
      name                 = lookup(redirect_configuration.value, "name", null)
      redirect_type        = lookup(redirect_configuration.value, "redirect_type", "Permanent")
      target_listener_name = lookup(redirect_configuration.value, "target_listener_name", null)
      target_url           = lookup(redirect_configuration.value, "target_url", null)
      include_path         = lookup(redirect_configuration.value, "include_path", "true")
      include_query_string = lookup(redirect_configuration.value, "include_query_string", "true")
    }
  }

  

}



/* 

backend addresspools -map
backend_http_settings - map
http_listenr - map
request_routing_rule - map

optional: 

waf_configuration
custom_error_configuration
firewall_policy_id

rewrite_rule_set
 */

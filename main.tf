#---------------------------
# Local declarations
#---------------------------
locals {
  backend_address_pool_name      = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-bapool"      # remove
  backend_http_settings_name     = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-be-http-set" # remove
  frontend_port_name             = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-feport"
  frontend_ip_configuration_name = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-feip"
  #backend_http_settings          = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-be-htst"
  http_probe_name    = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-be-htpb"
  http_listener_name = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-be-htln" # remove
  #  listener_name                 = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-httplstn" # remove
  request_routing_rule_name     = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-rqrt"
  gateway_ip_configuration_name = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-gwipc"
  ssl_certificate_name          = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-ssl"
  trusted_root_certificate_name = "appgw-${var.app_gateway_name}-${data.azurerm_resource_group.rg.location}-ssl-trust-cert"
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
  allocation_method   = var.sku.tier == "Standard" ? "Dynamic" : "Static"
  sku                 = var.sku.tier == "Standard" ? "Basic" : "Standard"
  domain_name_label   = var.domain_name_label
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

  #----------------------------------------------------------
  # Backend Address Pool Configuration
  #----------------------------------------------------------
  dynamic "backend_address_pool" {
    for_each = var.backend_address_pools
    content {
      name         = backend_address_pool.value.name
      fqdns        = backend_address_pool.value.fqdns
      ip_addresses = backend_address_pool.value.ip_addresses
    }
  }

  #----------------------------------------------------------
  # Backend HTTP Settings
  #----------------------------------------------------------
  dynamic "backend_http_settings" {
    for_each = var.backend_http_settings
    content {
      name                                = backend_http_settings.value.name
      cookie_based_affinity               = lookup(backend_http_settings.value, "cookie_based_affinity", "Disabled")
      affinity_cookie_name                = lookup(backend_http_settings.value, "affinity_cookie_name", null)
      path                                = lookup(backend_http_settings.value, "path", "/")
      port                                = backend_http_settings.value.enable_https ? 443 : 80
      probe_name                          = lookup(backend_http_settings.value, "probe_name", null)
      protocol                            = backend_http_settings.value.enable_https ? "Https" : "Http"
      request_timeout                     = lookup(backend_http_settings.value, "request_timeout", 30)
      host_name                           = backend_http_settings.value.pick_host_name_from_backend_address == false ? lookup(backend_http_settings.value, "host_name") : null
      pick_host_name_from_backend_address = lookup(backend_http_settings.value, "pick_host_name_from_backend_address", false)

      dynamic "authentication_certificate" {
        for_each = backend_http_settings.value.authentication_certificate[*]
        content {
          name = authentication_certificate.value.name
        }
      }

      trusted_root_certificate_names = lookup(backend_http_settings.value, "trusted_root_certificate_names", null)

      dynamic "connection_draining" {
        for_each = backend_http_settings.value.connection_draining[*]
        content {
          enabled           = connection_draining.value.enable_connection_draining
          drain_timeout_sec = connection_draining.value.drain_timeout_sec
        }
      }
    }
  }

  #----------------------------------------------------------
  # HTTP Listener Configuration
  #----------------------------------------------------------
  dynamic "http_listener" {
    for_each = var.http_listeners
    content {
      name                           = http_listener.value.name
      frontend_ip_configuration_name = local.frontend_ip_configuration_name
      frontend_port_name             = var.frontend_port == 80 ? "${local.frontend_port_name}-80" : "${local.frontend_port_name}-443"
      host_name                      = lookup(http_listener.value, "host_name", null)
      host_names                     = lookup(http_listener.value, "host_names", null)
      protocol                       = var.frontend_port == 80 ? "Http" : "Https"
      require_sni                    = http_listener.value.ssl_certificate_name != null ? http_listener.value.require_sni : null
      ssl_certificate_name           = var.frontend_port == 443 ? http_listener.value.ssl_certificate_name : null
      firewall_policy_id             = http_listener.value.firewall_policy_id
      dynamic "custom_error_configuration" {
        for_each = http_listener.value.custom_error_configuration[*]
        content {
          status_code           = custom_error_configuration.value.status_code
          custom_error_page_url = custom_error_configuration.value.custom_error_page_url
        }
      }
    }
  }

  #----------------------------------------------------------
  # Request routing rules Configuration
  #----------------------------------------------------------
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

  #---------------------------------------------------------------
  # Identity block Configuration
  # A list with a single user managed identity id to be assigned
  #---------------------------------------------------------------
  dynamic "identity" {
    for_each = var.identity_ids != null ? [1] : []
    content {
      type         = "UserAssigned"
      identity_ids = var.identity_ids
    }
  }

  #----------------------------------------------------------
  # Authentication SSL Certificate Configuration
  #----------------------------------------------------------
  dynamic "authentication_certificate" {
    for_each = var.authentication_certificate != null ? [var.authentication_certificate] : []
    content {
      name = var.authentication_certificate.name
      data = filebase64(lookup(var.authentication_certificate, "data"))
    }
  }

  #----------------------------------------------------------
  # Trusted Root SSL Certificate Configuration
  #----------------------------------------------------------
  dynamic "trusted_root_certificate" {
    for_each = var.trusted_root_certificate != null ? [var.trusted_root_certificate] : []
    content {
      name = var.trusted_root_certificate.name
      data = filebase64(lookup(var.trusted_root_certificate, "data"))
    }
  }

  #----------------------------------------------------------------------------------------------------------------------------------------------------------------------
  # SSL Policy for Application Gateway
  # Application Gateway has three predefined security policies to get the appropriate level of security
  # AppGwSslPolicy20150501 - MinProtocolVersion(TLSv1_0), AppGwSslPolicy20170401 - MinProtocolVersion(TLSv1_1), AppGwSslPolicy20170401S - MinProtocolVersion(TLSv1_2)
  #----------------------------------------------------------------------------------------------------------------------------------------------------------------------
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

  #----------------------------------------------------------
  # SSL Certificate (.pfx) Configuration
  #----------------------------------------------------------
  dynamic "ssl_certificate" {
    for_each = var.ssl_certificate != null ? [var.ssl_certificate] : []
    content {
      name                = local.ssl_certificate_name
      data                = var.ssl_certificate.key_vault_secret_id == null ? filebase64(lookup(var.ssl_certificate, "data")) : null
      password            = var.ssl_certificate.key_vault_secret_id == null ? var.ssl_certificate.password : null
      key_vault_secret_id = lookup(var.ssl_certificate, "key_vault_secret_id", null)
    }
  }

  #----------------------------------------------------------
  # Health Probe
  #----------------------------------------------------------
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

  #----------------------------------------------------------
  # URL Path Mappings
  #----------------------------------------------------------
  dynamic "url_path_map" {
    for_each = var.url_path_maps[*]
    content {
      name                                = url_path_map.value.name
      default_backend_http_settings_name  = url_path_map.value.default_redirect_configuration_name == null ? local.backend_address_pool_name : null
      default_backend_address_pool_name   = url_path_map.value.default_redirect_configuration_name == null ? local.backend_http_settings_name : null
      default_redirect_configuration_name = lookup(url_path_map.value, "default_redirect_configuration_name", null)
      default_rewrite_rule_set_name       = lookup(url_path_map.value, "default_rewrite_rule_set_name", null)

      dynamic "path_rule" {
        for_each = url_path_map.value.path_rules[*]
        content {
          name                        = path_rule.value.name
          backend_address_pool_name   = path_rule.value.redirect_configuration_name == null ? local.backend_address_pool_name : null
          backend_http_settings_name  = path_rule.value.backend_http_settings_name == null ? local.backend_http_settings_name : null
          paths                       = path_rule.value.paths
          redirect_configuration_name = lookup(path_rule.value, "redirect_configuration_name", null)
          rewrite_rule_set_name       = lookup(path_rule.value, "rewrite_rule_set_name", null)
          firewall_policy_id          = lookup(path_rule.value, "firewall_policy_id", null)
        }
      }
    }
  }

  #----------------------------------------------------------
  # Redirect Configuration
  #----------------------------------------------------------
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

  #----------------------------------------------------------
  # Custom error configuration
  #----------------------------------------------------------
  dynamic "custom_error_configuration" {
    for_each = var.custom_error_configuration[*]
    content {
      custom_error_page_url = lookup(custom_error_configuration.value, "custom_error_page_url", null)
      status_code           = lookup(custom_error_configuration.value, "status_code", null)
    }
  }

  #----------------------------------------------------------
  # Rewrite Rules Set configuration
  #----------------------------------------------------------
  dynamic "rewrite_rule_set" {
    for_each = var.rewrite_rule_set[*]
    content {
      name = var.rewrite_rule_set.name

      dynamic "rewrite_rule" {
        for_each = lookup(var.rewrite_rule_set, "rewrite_rules", [])
        content {
          name          = rewrite_rule.value.name
          rule_sequence = rewrite_rule.value.rule_sequence

          dynamic "condition" {
            for_each = lookup(rewrite_rule_set.value, "condition", [])
            content {
              variable    = condition.value.variable
              pattern     = condition.value.pattern
              ignore_case = condition.value.ignore_case
              negate      = condition.value.negate
            }
          }

          dynamic "request_header_configuration" {
            for_each = lookup(rewrite_rule.value, "request_header_configuration", [])
            content {
              header_name  = request_header_configuration.value.header_name
              header_value = request_header_configuration.value.header_value
            }
          }

          dynamic "response_header_configuration" {
            for_each = lookup(rewrite_rule.value, "response_header_configuration", [])
            content {
              header_name  = response_header_configuration.value.header_name
              header_value = response_header_configuration.value.header_value
            }
          }

          dynamic "url" {
            for_each = lookup(rewrite_rule.value, "url", [])
            content {
              path         = url.value.path
              query_string = url.value.query_string
              reroute      = url.value.reroute
            }
          }
        }
      }
    }
  }


}

# Azurerm Provider configuration
provider "azurerm" {
  features {}
}

module "app-gateway" {
  //  source = "github.com/tietoevry-infra-as-code/terraform-azurerm-application-gateway?ref=v1.0.0"
  source = "../../"
  # Resource Group and location, VNet and Subnet detials (Required)
  resource_group_name  = "rg-shared-westeurope-01"
  location             = "westeurope"
  virtual_network_name = "vnet-shared-hub-westeurope-001"
  subnet_name          = "snet-appgateway"
  app_gateway_name     = "testgateway"
  frontend_port        = 443

  /* # (Optional) To enable Azure Monitoring and install log analytics agents
  log_analytics_workspace_name = "logaws-yhjhmxvd-default-hub-westeurope"
  storage_account_name     = "stdiaglogsdefaulthub"
*/
  sku = {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  backend_address_pools = [
    {
      name  = "appgw-testgateway-westeurope-bapool01"
      fqdns = ["example1.com", "example2.com"]
    },
    {
      name         = "appgw-testgateway-westeurope-bapool02"
      ip_addresses = ["1.2.3.4", "2.3.4.5"]
    }
  ]

  backend_http_settings = [
    {
      name                  = "appgw-testgateway-westeurope-be-http-set1"
      cookie_based_affinity = "Disabled"
      path                  = "/"
      enable_https          = true
      request_timeout       = 30
      probe_name            = "appgw-testgateway-westeurope-probe1"
      connection_draining = {
        enable_connection_draining = true
        drain_timeout_sec          = 300

      }
    },
    {
      name                  = "appgw-testgateway-westeurope-be-http-set2"
      cookie_based_affinity = "Enabled"
      path                  = "/"
      enable_https          = false
      request_timeout       = 30
    }
  ]

  request_routing_rules = [
    {
      name                       = "appgw-testgateway-westeurope-be-rqrt"
      rule_type                  = "Basic"
      http_listener_name         = "appgw-testgateway-westeurope-be-htln01"
      backend_address_pool_name  = "appgw-testgateway-westeurope-bapool01"
      backend_http_settings_name = "appgw-testgateway-westeurope-be-http-set1"
    }
  ]

  http_listeners = [
    {
      name                 = "appgw-testgateway-westeurope-be-htln01"
      ssl_certificate_name = "appgw-testgateway-westeurope-ssl01"
      host_name            = null
      custom_error_configuration = [
        {
          custom_error_page_url = "https://stdiagfortesting.blob.core.windows.net/appgateway/custom_error_403_page.html"
          status_code           = "HttpStatus403"
        },
        {
          custom_error_page_url = "https://stdiagfortesting.blob.core.windows.net/appgateway/custom_error_502_page.html"
          status_code           = "HttpStatus502"
        }
      ]
    }
  ]

  # Application Gateway has three predefined security policies to get the appropriate level of security
  # AppGwSslPolicy20150501 - MinProtocolVersion(TLSv1_0), AppGwSslPolicy20170401 - MinProtocolVersion(TLSv1_1), AppGwSslPolicy20170401S - MinProtocolVersion(TLSv1_2)
  /*   ssl_policy = {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20170401S"
  } */

  ssl_certificates = [{
    name     = "appgw-testgateway-westeurope-ssl01"
    data     = "./keyBag.pfx"
    password = "lats1234"
  }]
  /* 
  redirect_configuration = [
    {
      name = "demo-redirect-configuration01"
    },
    {
      name                 = "demo-redirect-configuration02"
      redirect_type        = "Temporary"
      include_query_string = false
    }
  ]
 */
  /* 
  custom_error_configuration = [
    {
      custom_error_page_url = "https://example.com/custom_error_403_page.html"
      status_code           = "HttpStatus403"
    },
    {
      custom_error_page_url = "https://example.com/custom_error_502_page.html"
      status_code           = "HttpStatus502"
    }
  ] */

  url_path_maps = [
    {
      name                               = "testgateway-url-path"
      default_backend_address_pool_name  = "appgw-testgateway-westeurope-bapool01"
      default_backend_http_settings_name = "appgw-testgateway-westeurope-be-http-set1"
      path_rules = [
        {
          name                       = "api"
          paths                      = ["/api/*"]
          backend_address_pool_name  = "appgw-testgateway-westeurope-bapool01"
          backend_http_settings_name = "appgw-testgateway-westeurope-be-http-set1"
        },
        {
          name                       = "videos"
          paths                      = ["/videos/*"]
          backend_address_pool_name  = "appgw-testgateway-westeurope-bapool02"
          backend_http_settings_name = "appgw-testgateway-westeurope-be-http-set2"
        }
      ]
    }
  ]

  health_probes = [
    {
      name                = "appgw-testgateway-westeurope-probe1"
      host                = "127.0.0.1"
      interval            = 30
      path                = "/"
      port                = 443
      timeout             = 30
      unhealthy_threshold = 3
    }
  ]
  # a list with a single user managed identity id to be assigned
  /*   identity_ids = ["${azurerm_user_assigned_identity.example.id}"] */

  # Adding TAG's to your Azure resources (Required)
  # ProjectName and Env are already declared above, to use them here, create a varible. 
  tags = {
    ProjectName  = "tieto-internal"
    Env          = "dev"
    Owner        = "user@example.com"
    BusinessUnit = "CORP"
    ServiceClass = "Gold"
  }
}

/* 
resource "azurerm_user_assigned_identity" "example" {
  resource_group_name = "rg-shared-westeurope-01"
  location            = "westeurope"
  name                = "appgw-api"
}
 */

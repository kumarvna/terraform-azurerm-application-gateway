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
  subnet_name          = "snet-management"
  app_gateway_name     = "testgateway"
  frontend_port        = 443

  /* # (Optional) To enable Azure Monitoring and install log analytics agents
  log_analytics_workspace_name = "logaws-yhjhmxvd-default-hub-westeurope"
  storage_account_name     = "stdiaglogsdefaulthub"
*/
  sku = {
    name     = "Standard_Small"
    tier     = "Standard"
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

  request_routing_rule = {
    rule_type = "Basic"
  }

  http_listeners = [
    {
      name                 = "appgw-testgateway-westeurope-be-htln"
      ssl_certificate_name = null
      host_name            = null
      custom_error_configuration = [
        {
          custom_error_page_url = "https://example.com/custom_error_403_page.html"
          status_code           = "HttpStatus403"
        },
        {
          custom_error_page_url = "https://example.com/custom_error_502_page.html"
          status_code           = "HttpStatus502"
        }
      ]
    },
    {
      name                 = "appgw-testgateway-westeurope-be-htln02"
      ssl_certificate_name = null
      host_name            = null
      custom_error_configuration = [
        {
          custom_error_page_url = "https://example.com/custom_error_403_page.html"
          status_code           = "HttpStatus403"
        }
      ]
    }
  ]

  # Application Gateway has three predefined security policies to get the appropriate level of security
  # AppGwSslPolicy20150501 - MinProtocolVersion(TLSv1_0), AppGwSslPolicy20170401 - MinProtocolVersion(TLSv1_1), AppGwSslPolicy20170401S - MinProtocolVersion(TLSv1_2)
  ssl_policy = {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20170401S"
  }

  ssl_certificate = {
    data     = "./keyBag.pfx"
    password = "lats1234"
  }
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
      name = "testgateway-url-path"
      path_rules = [
        {
          name  = "api"
          paths = ["/api/*"]
        },
        {
          name  = "videos"
          paths = ["/videos/*"]
        }
      ]
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

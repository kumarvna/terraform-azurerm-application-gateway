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

  backend_address_pool = {
    fqdns = ["example.com"]
  }

  backend_http_settings = {
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 300
  }

  request_routing_rule = {
    rule_type = "Basic"
  }

  http_listener = {
    protocol = "Https"
  }

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

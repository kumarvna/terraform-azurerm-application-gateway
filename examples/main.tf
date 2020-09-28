module "app-gateway" {
  //  source = "github.com/tietoevry-infra-as-code/terraform-azurerm-application-gateway?ref=v1.0.0"
  source = "../"
  # Resource Group and location, VNet and Subnet detials (Required)
  resource_group_name  = "rg-shared-westeurope-01"
  location             = "westeurope"
  virtual_network_name = "vnet-shared-hub-westeurope-001"
  subnet_name          = "snet-management"
  app_gateway_name     = "testgateway"
  frontend_port        = 443

  /* # (Optional) To enable Azure Monitoring and install log analytics agents
  log_analytics_workspace_name = "logaws-yhjhmxvd-default-hub-westeurope"
  hub_storage_account_name     = "stdiaglogsdefaulthub"
*/
  app_gateway_sku = {
    name     = "Standard_Small"
    tier     = "Standard"
    capacity = 1
  }

  backend_address_pool = {
    fqdns = ["example.com"]
  }

  backend_http_settings = {
    name                  = "appgw-testgateway-westeurope-be-http-set"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 443
    protocol              = "Https"
    request_timeout       = 300
  }

  request_routing_rules = {
    rule_type = "Basic"
  }

  http_listeners = {
    name      = "appgw-testgateway-westeurope-http-lst"
    protocol  = "Https"
    host_name = "example.com"
  }

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

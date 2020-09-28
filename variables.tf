variable "resource_group_name" {
  description = "A container that holds related resources for an Azure solution"
  default     = ""
}

variable "location" {
  description = "The location/region to keep all your network resources. To get the list of all locations with table format from azure cli, run 'az account list-locations -o table'"
  default     = ""
}

variable "virtual_network_name" {
  description = "The name of the virtual network"
  default     = ""
}

variable "subnet_name" {
  description = "The name of the subnet to use in VM scale set"
  default     = ""
}

variable "app_gateway_name" {
  description = "The name of the application gateway"
  default     = ""
}

variable "log_analytics_workspace_name" {
  description = "The name of log analytics workspace name"
  default     = null
}

variable "hub_storage_account_name" {
  description = "The name of the hub storage account to store logs"
  default     = null
}

variable "public_ip_allocation_method" {
  description = "Defines the allocation method for this IP address. Possible values are Static or Dynamic"
  default     = "Static"
}

variable "public_ip_sku" {
  description = "The SKU of the Public IP. Accepted values are Basic and Standard. Defaults to Basic"
  default     = "Standard"
}

variable "enable_http2" {
  description = "Is HTTP2 enabled on the application gateway resource?"
  default     = false
}

variable "app_gateway_sku" {
  description = "The sku pricing model of v1 and v2"
  type        = object({ name = string, tier = string, capacity = number })
}

variable "capacity" {
  description = "Minimum or Maximum capacity for autoscaling. Accepted values are for Minimum in the range 0 to 100 and for Maximum in the range 2 to 125"
  default     = {}
}

variable "private_ip_address" {
  description = "Private IP Address to assign to the Load Balancer."
  default     = null
}

variable "frontend_port" {
  description = " The port used for this Frontend Port."
  default     = 80
}

variable "backend_address_pool" {
  description = "List of backend address pools"
  default     = {}
}

variable "backend_http_settings" {
  description = "List of backend HTTP settings."
  default     = {}
}

variable "health_probe" {
  description = "Health probes used to test backend health."
  default     = {}
}

variable "http_listeners" {
  description = "List of HTTP listeners."
  default     = {}
}

variable "request_routing_rules" {
  description = "Request routing rules to be used for listeners."
  default     = {}
}

variable "zones" {
  description = "A collection of availability zones to spread the Application Gateway over."
  type        = list(string)
  default     = [] #["1", "2", "3"]
}

variable "ssl_certificate" {
  description = "SSL certificate data for Application gateway"
  default     = {}
}

variable "ssl_policy" {
  description = "Application Gateway SSL configuration"
  default     = {}
}

variable "url_path_maps" {
  description = "URL path maps associated to path-based rules."
  default     = []
  type = list(object({
    name                               = string
    default_backend_http_settings_name = string
    default_backend_address_pool_name  = string
    path_rules = list(object({
      name                       = string
      backend_address_pool_name  = string
      backend_http_settings_name = string
      paths                      = list(string)
    }))
  }))
}

variable "waf_enabled" {
  description = "Is the Web Application Firewall be enabled?"
  default     = false
}

variable "nsg_diag_logs" {
  description = "NSG Monitoring Category details for Azure Diagnostic setting"
  default     = ["NetworkSecurityGroupEvent", "NetworkSecurityGroupRuleCounter"]
}

variable "pip_diag_logs" {
  description = "Load balancer Public IP Monitoring Category details for Azure Diagnostic setting"
  default     = ["DDoSProtectionNotifications", "DDoSMitigationFlowLogs", "DDoSMitigationReports"]
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

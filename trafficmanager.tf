resource "random_id" "server" {
  keepers = {
    azi_id = 1
  }
  byte_length = 8
}

resource "azurerm_traffic_manager_profile" "interprovider" {
  name                   = "interprovider-trafficmanager"
  resource_group_name    = "user17-rg"
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "${random_id.server.hex}"
    ttl           = 30
  }

  monitor_config {
    protocol = "http"
    port     = 80
    path     = "/"
  }
}

resource "azurerm_traffic_manager_endpoint" "azureLB" {
  name                = "first"
  resource_group_name = "user17-rg"
  profile_name        = "${azurerm_traffic_manager_profile.interprovider.name}"
  target              = "user17skcncazureip.koreasouth.cloudapp.azure.com"
  type                = "externalEndpoints"
  weight              = 1
}

resource "azurerm_traffic_manager_endpoint" "awsLB" {
  name                = "second"
  resource_group_name = "user17-rg"
  profile_name        = "${azurerm_traffic_manager_profile.interprovider.name}"
  target              = "albuser17-774421534.ap-northeast-1.elb.amazonaws.com"
  type                = "externalEndpoints"
  weight              = 2
}
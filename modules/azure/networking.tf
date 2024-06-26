resource "azurerm_virtual_network" "alz" {
  count               = local.use_private_networking ? 1 : 0
  name                = var.virtual_network_name
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.network[0].name
  address_space       = [var.virtual_network_address_space]
}

resource "azurerm_public_ip" "alz" {
  count               = local.use_private_networking ? 1 : 0
  name                = var.public_ip_name
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.network[0].name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "alz" {
  count               = local.use_private_networking ? 1 : 0
  name                = var.nat_gateway_name
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.network[0].name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "alz" {
  count                = local.use_private_networking ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.alz[0].id
  public_ip_address_id = azurerm_public_ip.alz[0].id
}

resource "azurerm_subnet" "container_instances" {
  count                             = local.use_private_networking ? 1 : 0
  name                              = var.virtual_network_subnet_name_container_instances
  resource_group_name               = azurerm_resource_group.network[0].name
  virtual_network_name              = azurerm_virtual_network.alz[0].name
  address_prefixes                  = [var.virtual_network_subnet_address_prefix_container_instances]
  private_endpoint_network_policies = "Enabled"
  delegation {
    name = "aci-delegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet_nat_gateway_association" "container_instances" {
  count          = local.use_private_networking ? 1 : 0
  subnet_id      = azurerm_subnet.container_instances[0].id
  nat_gateway_id = azurerm_nat_gateway.alz[0].id
}

resource "azurerm_subnet" "storage" {
  count                             = local.use_private_networking ? 1 : 0
  name                              = var.virtual_network_subnet_name_storage
  resource_group_name               = azurerm_resource_group.network[0].name
  virtual_network_name              = azurerm_virtual_network.alz[0].name
  address_prefixes                  = [var.virtual_network_subnet_address_prefix_storage]
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_private_dns_zone" "alz" {
  count               = local.use_private_networking ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.network[0].name
}

resource "azurerm_private_dns_zone_virtual_network_link" "alz" {
  count                 = local.use_private_networking ? 1 : 0
  name                  = var.private_endpoint_name
  resource_group_name   = azurerm_resource_group.network[0].name
  private_dns_zone_name = azurerm_private_dns_zone.alz[0].name
  virtual_network_id    = azurerm_virtual_network.alz[0].id
}

resource "azurerm_private_endpoint" "alz" {
  count               = local.use_private_networking ? 1 : 0
  name                = var.private_endpoint_name
  location            = var.azure_location
  resource_group_name = azurerm_resource_group.network[0].name
  subnet_id           = azurerm_subnet.storage[0].id

  private_service_connection {
    name                           = var.private_endpoint_name
    private_connection_resource_id = azurerm_storage_account.alz.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = var.private_endpoint_name
    private_dns_zone_ids = [azurerm_private_dns_zone.alz[0].id]
  }
}

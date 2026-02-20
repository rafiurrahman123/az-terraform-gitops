resource "azurerm_resource_group" "rg" {
  name     = "rg-budget-k8s"
  location = "East US"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-gitops-cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "gitops-k8s"
  sku_tier            = "Free" # No management fee

  default_node_pool {
    name       = "internal"
    node_count = 1
    vm_size    = "Standard_B2s" # ~ $30/mo (Burstable)
    
    # Using Spot instances for maximum savings
    priority        = "Spot"
    eviction_policy = "Delete"
    spot_max_price  = -1 
  }

  identity {
    type = "SystemAssigned"
  }
}
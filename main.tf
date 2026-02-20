# main.tf

resource "azurerm_resource_group" "rg" {
  name     = "rg-budget-k8s"
  location = "East US"
}
# 1. The AKS Cluster with a small "Regular" System Pool
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-gitops-cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "gitops-k8s"
  sku_tier            = "Free"

  default_node_pool {
    name       = "systempool"
    node_count = 1
    vm_size    = "Standard_B2s" # Smallest viable for system services
    # No Spot arguments allowed here
  }

  identity {
    type = "SystemAssigned"
  }
}

# 2. The Separate "Spot" Node Pool for your workloads
resource "azurerm_kubernetes_cluster_node_pool" "spot" {
  name                  = "spotpool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = "Standard_B2s"
  node_count            = 1
  
  # Spot configuration is allowed here
  priority        = "Spot"
  eviction_policy = "Delete"
  spot_max_price  = -1 # Pay up to the regular price

  node_labels = {
    "kubernetes.azure.com/scalesetpriority" = "spot"
  }
  
  node_taints = [
    "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
  ]
}

resource "azurerm_kubernetes_cluster_extension" "flux" {
  name           = "flux"
  cluster_id     = azurerm_kubernetes_cluster.aks.id
  extension_type = "microsoft.flux"
}

resource "azurerm_kubernetes_flux_configuration" "flux_config" {
  name       = "aks-gitops"
  cluster_id = azurerm_kubernetes_cluster.aks.id
  namespace  = "flux-system"
  scope      = "cluster"

  git_repository {
    url             = "https://github.com/YOUR_GITHUB_USERNAME/kube-gitops-terraform-github"
    reference_type  = "branch"
    reference_value = "main"
  }

  kustomizations {
    name = "infra"
    path = "./cluster-config" # Path where you will store your YAMLs
  }

  depends_on = [azurerm_kubernetes_cluster_extension.flux]
}
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
    vm_size    = "Standard_D2s_v3" # Smallest viable for system services
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
  vm_size               = "Standard_D2s_v3"
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

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm" # Terraform uses this to bypass local repo lists
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "7.7.0"

  set = [
    {
      name  = "server.service.type"
      value = "LoadBalancer"
    }
  ]
}
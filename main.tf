# 1. Get current Azure client info (needed to find your ID)
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-budget-k8s"
  location = "East US"
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-gitops-cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "gitops-k8s"

  # --- NEW SECURITY CONFIGURATION ---
  
  # Disables the "backdoor" local admin password
  local_account_disabled = true

  # Links the cluster to Entra ID and uses Azure to manage permissions
  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled      = true
    tenant_id              = data.azurerm_client_config.current.tenant_id
  }
  
  # ----------------------------------

  default_node_pool {
    name       = "systempool"
    node_count = 1
    vm_size    = "Standard_D2s_v3"
  }

  identity {
    type = "SystemAssigned"
  }
}

# 2. ADD THIS: Automatically gives YOU (the person running Terraform) 
# permissions to manage the cluster. Without this, you'd be locked out!
resource "azurerm_role_assignment" "aks_admin" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Keep your existing Helm release for ArgoCD here...
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }
}
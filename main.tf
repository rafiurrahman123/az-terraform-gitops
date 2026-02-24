# 1. Get current Azure client info
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-budget-k8s"
  location = "East US"
}

# 2. CREATE A STATIC IP (This keeps your URL the same even if you delete the cluster)
resource "azurerm_public_ip" "argocd_ip" {
  name                = "argocd-static-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 3. AKS CLUSTER CONFIGURATION
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-gitops-cluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "gitops-k8s"

  local_account_disabled = true

  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  default_node_pool {
    name       = "systempool"
    node_count = 1
    vm_size    = "Standard_D2s_v3"
  }

  identity {
    type = "SystemAssigned"
  }
}

# 4. RBAC ROLE ASSIGNMENT
resource "azurerm_role_assignment" "aks_admin" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

# 5. ARGOCD HELM INSTALLATION
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  # Set the LoadBalancer to use our Static IP
  set {
    name  = "server.service.loadBalancerIP"
    value = azurerm_public_ip.argocd_ip.ip_address
  }

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }
}

# 6. ENTRA ID APP REGISTRATION (For SSO Login)
resource "azuread_application" "argocd_sso" {
  display_name     = "argocd-sso"
  owners           = [data.azurerm_client_config.current.object_id]
  sign_in_audience = "AzureADMyOrg"

  web {
    # This automatically updates the Redirect URI to our Static IP
    redirect_uris = ["https://${azurerm_public_ip.argocd_ip.ip_address}/api/dex/callback"]
  }
}
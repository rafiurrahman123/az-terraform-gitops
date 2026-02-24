# 1. Get current Azure client info
data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "rg" {
  name     = "rg-budget-k8s"
  location = "East US"
}

# 2. STATIC IP
resource "azurerm_public_ip" "argocd_ip" {
  name                = "argocd-static-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 3. AKS CLUSTER
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

# 5. ARGOCD HELM INSTALLATION (Direct URL Method)
resource "helm_release" "argocd" {
  name             = "argocd"
  
  # By pointing to the .tgz directly, we bypass the entire repository index system
  chart            = "https://github.com/argoproj/argo-helm/releases/download/argo-cd-7.7.0/argo-cd-7.7.0.tgz"
  
  namespace        = "argocd"
  create_namespace = true

  # We set these to null to make sure the provider doesn't try to look at your local repos
  repository          = null
  repository_key_file = null

  values = [
    <<-EOT
    server:
      service:
        type: LoadBalancer
        loadBalancerIP: ${azurerm_public_ip.argocd_ip.ip_address}
    EOT
  ]
}
# 6. ENTRA ID APP REGISTRATION
resource "azuread_application" "argocd_sso" {
  display_name     = "argocd-sso"
  owners           = [data.azurerm_client_config.current.object_id]
  sign_in_audience = "AzureADMyOrg"

  web {
    redirect_uris = ["https://${azurerm_public_ip.argocd_ip.ip_address}/api/dex/callback"]
  }
}

# 7. OUTPUTS
output "argocd_url" {
  value = "https://${azurerm_public_ip.argocd_ip.ip_address}"
}
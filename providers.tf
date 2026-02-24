terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

# 1. ADD THIS BLOCK (Azure requires it)
provider "azurerm" {
  features {}
}

# 2. UPDATE THIS BLOCK (Note the = sign)
provider "helm" {
  kubernetes = {
    host                   = azurerm_kubernetes_cluster.aks.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
  }

  # THIS IS THE MAGIC FIX FOR THE DATADOG ERROR:
  # It tells Terraform: "Don't use my Windows Helm folders. Use these instead."
  repository_config_path = "${path.module}/.helm/repository/config.yaml"
  repository_cache       = "${path.module}/.helm/repository/cache"
}
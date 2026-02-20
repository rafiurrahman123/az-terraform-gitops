terraform {
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-lab"
    storage_account_name = "sttfstate8955" # Must be globally unique
    container_name       = "tfstate"
    key                  = "aks-gitops.terraform.tfstate"
    subscription_id      = "ade02fe8-df1d-4886-8d78-d725dac92cb7"
  }
}

# 1. Terraform Settings Block
terraform {
  # 1. Required Version Terraform
  required_version = ">= 1.0"
  # 2. Required Terraform Providers  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    
  }

# Terraform State Storage to Azure Storage Container
  backend "azurerm" {
    #resource_group_name   = "terraform-storage-rg"
    #storage_account_name  = "terraformstorage05"
    #container_name        = "tfstatebackupfile"
    #key                   = "aks-base.tfstate"
  }  
}



# 2. Terraform Provider Block for AzureRM
provider "azurerm" {
  subscription_id = "Your_Subscription_ID"
  features {
    
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}


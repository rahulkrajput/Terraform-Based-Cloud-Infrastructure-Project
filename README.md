# Provision Azure AKS Cluster using Terraform

## Prerequisites
Before we begin, make sure you have the following:

- Microsoft Azure Cloud Account
- Terraform installed on your local machine
- Azure CLI installed and configured

## Step-01: Brief Intro
- Install and Configure Terraform, Azure Cli
- Create SSH Keys for AKS Linux VMs
- Create Datasource for Azure AKS latest Version
- Create Azure AD AKS Admins Group Resource in Terraform
- Create AKS Cluster with default nodepool
- Create AKS Cluster Output Values
- Provision Azure AKS Cluster using Terraform
- Access and Test using Azure AKS default admin `--admin`
- Access and Test using Azure AD User as AKS Admin


## Step-02: Install and Configure Terraform, Azure Cli
To use Terraform and Azure Cli, you need to install it on your local machine. Follow these steps to install and configure Terraform:

- Download Terraform from the official website.
- Install Terraform according to your operating system (mine is Ubuntu OS). (Check the Reference at the end of this README file.)
- Verify the installation by running **terraform --version**.
- Install the Azure CLI on Linux
   - The easiest way to install the Azure CLI is through a script maintained by the Azure CLI team. 
```
 curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

- Configure your Azure credentials by running **az login --use-device-code**
```
# You will receive a device code like that:
To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code ITR5N7GCK to authenticate.

Open your browser and type in your Azure account email ID and paste the code.
```

## Step-03: Create SSH Public Key for Linux VMs
```
# Create Folder
mkdir $HOME/.ssh/aks-prod-sshkeys-terraform

# Create SSH Key
ssh-keygen \
    -m PEM \
    -t rsa \
    -b 4096 \
    -C "azureuser@myserver" \
    -f ~/.ssh/aks-prod-sshkeys-terraform/aksprodsshkey \
    -N mypassphrase

# List Files
ls -lrt $HOME/.ssh/aks-prod-sshkeys-terraform
```

## Step-04: Create a main.tf file as Following
```
# 1. Terraform Settings Block

terraform {

  # A. Required Version Terraform
  required_version = ">= 1.0" 

  # B. Required Terraform Providers  
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
    resource_group_name   = "terraform-storage-rg"
    storage_account_name  = "terraformstorage05"
    container_name        = "tfstatebackupfile"
    key                   = "aks-base.tfstate"
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
```

## Step-05: Create Terraform Input Vairables to variables.tf

- SSH Public Key for Linux VMs

```
# SSH Public Key for Linux VMs
variable "ssh_public_key" {
  default = "~/.ssh/aks-prod-sshkeys-terraform/aksprodsshkey.pub"
  description = "This variable defines the SSH Public Key for Linux k8s Worker nodes"  
}
```

## Step-06: Create a Terraform Datasource for getting latest Azure AKS Versions 

- Data sources allow data to be fetched or computed for use elsewhere in Terraform configuration. 
- Create **aks-versions-datasource.tf**
- **Important Note:**
  Keep in mind `include_preview` value should be **false** because the default value is true, which means we want to accept the preview version of Kubernetes and in a production-grade cluster it is not the right choice. We should always stick with stable versions.
```
# Datasource to get Latest Azure AKS latest Version
data "azurerm_kubernetes_service_versions" "current" {
  location = azurerm_resource_group.aks_rg.location
  include_preview = false  
}
```




## Step-07: Create Azure AD Group for AKS Admins Terraform Resource
- To enable AKS AAD Integration, we need to provide Azure AD group object id. 
- We will create a Azure AD Group in Active Directory for AKS Admins
```
# Create Azure AD Group in Active Directory for AKS Admins
resource "azuread_group" "aks_administrators" {
  name        = "${azurerm_resource_group.aks_rg.name}-cluster-administrators"
  description = "Azure AKS Kubernetes administrators for the ${azurerm_resource_group.aks_rg.name}-cluster."
}
```

## Step-08: Create AKS Cluster Terraform Resource
- Create a file named  **aks-cluster.tf**

```
# Provision AKS Cluster


resource "azurerm_kubernetes_cluster" "aks_cluster" {
  dns_prefix          = "${azurerm_resource_group.aks_rg.name}"
  location            = azurerm_resource_group.aks_rg.location
  name                = "${azurerm_resource_group.aks_rg.name}-cluster"
  resource_group_name = azurerm_resource_group.aks_rg.name
  kubernetes_version  = data.azurerm_kubernetes_service_versions.current.latest_version
  node_resource_group = "${azurerm_resource_group.aks_rg.name}-nrg"


  default_node_pool {
    name       = "systempool"
    vm_size    = "Standard_D2as_v4"
    orchestrator_version = data.azurerm_kubernetes_service_versions.current.latest_version
    auto_scaling_enabled = true
    max_count            = 3
    min_count            = 1
    os_disk_size_gb      = 30
    type           = "VirtualMachineScaleSets"
    node_public_ip_enabled = false
    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
      "nodepoolos"    = "linux"
      "app"           = "system-apps"
    }
    tags = {
      "nodepool-type" = "system"
      "environment"   = var.environment
      "nodepoolos"    = "linux"
      "app"           = "system-apps"
    }    
  }

# Identity (System Assigned or Service Principal)
  identity { type = "SystemAssigned" }



# RBAC and Azure AD Integration Block

azure_active_directory_role_based_access_control {
  
  admin_group_object_ids = [azuread_group.aks_administrators.object_id] 
}


# Linux Profile
linux_profile {
  admin_username = "Your_User_Name"
  ssh_key {
      key_data = file(var.ssh_public_key)
  }
}

# Network Profile
network_profile {
  load_balancer_sku = "standard"
  network_plugin = "azure"
}

# AKS Cluster Tags 
tags = {
  Environment = var.environment
}

}

```

## Step-09: Create Terraform Output Values for AKS Cluster
- Create a file named **outputs.tf**
```
# Create Outputs
# 1. Resource Group Location
# 2. Resource Group Id
# 3. Resource Group Name

# Resource Group Outputs
output "location" {
  value = azurerm_resource_group.aks_rg.location
}

output "resource_group_id" {
  value = azurerm_resource_group.aks_rg.id
}

output "resource_group_name" {
  value = azurerm_resource_group.aks_rg.name
}

# Azure AKS Versions Datasource
output "versions" {
  value = data.azurerm_kubernetes_service_versions.current.versions
}

output "latest_version" {
  value = data.azurerm_kubernetes_service_versions.current.latest_version
}

# Azure AD Group Object Id

output "azure_ad_group_object_id" {
  value = azuread_group.aks_administrators.object_id
}

# Azure AKS Outputs

output "aks_cluster_id" {
  value = azurerm_kubernetes_cluster.aks_cluster.id
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks_cluster.name
}

output "aks_cluster_kubernetes_version" {
  value = azurerm_kubernetes_cluster.aks_cluster.kubernetes_version
}

```

## Step-10: Deploy Terraform Resources
```
# Initialize Terraform 
terraform init

# Validate Terraform manifests
terraform validate

# Review the Terraform Plan
terraform plan

# Deploy Terraform manifests
terraform apply 
```

## Step-11: Access Terraform created AKS cluster using AKS default admin
```
# Azure AKS Get Credentials with --admin
az aks get-credentials --resource-group terraform-aks-prod --name terraform-aks-prod-cluster --admin

# Get Full Cluster Information
az aks show --resource-group terraform-aks-prod --name terraform-aks-prod-cluster -o table

# Get AKS Cluster Information using kubectl
kubectl cluster-info

# List Kubernetes Nodes
kubectl get nodes
```

## Step-12: Verify Resources using Azure Management Console
- Resource Group
  - terraform-aks-prod
  - terraform-aks-prod-nrg
- AKS Cluster & Node Pool
  - Cluster: terraform-aks-prod-cluster
  - AKS System Pool
- Azure AD Group
  - terraform-aks-prod-cluster-administrators


## Step-13: Create a User in Azure AD and Associate User to AKS Admin Group in Azure AD
- Create a user in Azure Active Directory
  - User Name: kube-user
  - Name: kube-user
  - First Name: kube
  - Last Name: user
  - Password: !@Kubeadmin!5
  - Groups: terraform-aks-prod-cluster-administrators
  - Click on Create
- Login and change password 
  - URL: https://portal.azure.com
  - Username: kube-user@xyz.onmicrosoft.com  (Change your domain name)
  - Old Password: !@Kubeadmin!5
  - New Password: !@Kubeadmin!6
  - Confirm Password: !@Kubeadmin!6

## Step-14: Access Terraform created AKS Cluster 
```
# Azure AKS Get Credentials with --admin
az aks get-credentials --resource-group terraform-aks-prod --name terraform-aks-prod-cluster --overwrite-existing

# List Kubernetes Nodes
kubectl get nodes
URL: https://microsoft.com/devicelogin
Code: ACJ3T9GUK (sample)
Username: kube-user@xyz.onmicrosoft.com  (Change your domain name)
Password: !@Kubeadmin!6
```
## Notes

- Make sure to replace placeholders (e.g., Your_Subscription_ID, your_cluster_name, your_region, your_resource_group_name, your_domain_name...etc) with your actual Configuration.

- This is a basic setup for demonstration purposes. In a production environment, you should follow best practices for security and performance.

## Reference:

- [Installation of Terraform](https://developer.hashicorp.com/terraform/install)
- [Install the Azure CLI on Linux](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?view=azure-cli-latest&pivots=apt)
- [Understand the concept of Terraform Datasources](https://www.terraform.io/docs/configuration/data-sources.html)
- [Data Source: Azurerm kubernetes service versions](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/kubernetes_service_versions)
- [Concept of Azure Active Directory group In Terraform for AKS Admins](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/group) 
- [Understand about the terraform resource named for Azurerm kubernetes cluster](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster)
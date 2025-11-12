# Provision Azure AKS and Install ArgoCD using Terraform & Azure DevOps

## Step-01: Brief Intro
- Create Azure DevOps Pipeline to create AKS cluster and Install ArgoCD using Terraform
- Terraform Manifests Validate
- Provision Prod AKS Cluster
- Install ArgoCD Server
- Declarative Management of Kubernetes Objects Using Kustomize


## Step-02: Install Azure Market Place Plugins in Azure DevOps
- Install below listed plugins in your respective Azure DevOps Organization
- [Plugin: Terraform by Microsoft Devlabs](https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks)



## Step-03: Review Terraform Manifests
### 01-main.tf
- Comment Terraform Backend, because we are going to configure that in Azure DevOps

### 02-variables.tf
- Two variables we will define in Azure DevOps and use it
  - Environment 
  - SSH Public Key (We Define SSH Variable here, but we fetch ssh key From Azure Devops Secure File)
 

### 03-resource-group.tf
- We are going to create resource groups for each environment with **terraform-aks-envname**
- Example Name:
  - terraform-aks-prod
  

### 04-aks-versions-datasource.tf
- We will get the latest version of AKS using this datasource. 
- `include_preview = false` will ensure that preview versions are not listed

### 05-aks-administrators-azure-ad.tf
- We are going to create Azure AD Group per environment for AKS Admins
- To create this group we need to ensure Azure AD Directory Write permission is there for our Service Principal (Service Connection) created in Azure DevOps
- Provide Permission to create Azure AD Groups

### 06-aks-cluster.tf
- Name of the AKS Cluster going to be **ResourceGroupName-Cluster**
- Example Names:
  - terraform-aks-prod-cluster
  
### 07-outputs.tf  
- We will put out output values very simple
- Resource Group 
  - Location
  - Name
  - ID
- AKS Cluster 
  - AKS Versions
  - AKS Latest Version
  - AKS Cluster ID
  - AKS Cluster Name
  - AKS Cluster Kubernetes Version
- AD Group
  - ID
  - Object ID
 
 


## Step-04: Create Github Repository

### Create Github Repository in Github
- Create Repository in your github
- Name: GitOps-Workflow-with-ArgoCD-on-Kubernetes-Project
- Descritpion: A GitOps Workflow project using ArgoCD on Kubernetes focuses on automating and managing deployments by using Git.
- Repository Type: Public or Private (As Per Requirement)
- Click on **Create Repository**

### Create files, Initialize Local Repo, Push to Remote Git Repo
```
# Create folder in local desktop

mkdir GitOps-Workflow-with-ArgoCD-on-Kubernetes-Project
cd GitOps-Workflow-with-ArgoCD-on-Kubernetes-Project

# Create new folders inside "GitOps-Workflow-with-ArgoCD-on-Kubernetes-Project" in local desktop
kubernetes-cluster-manifests (Create Yaml Files for Deployment on AKS Cluster)
terraform-manifests (Create Terraform Files for Provision AKS Cluster)
Pipelines (It is used for Save Pipeline, while Creating of AKS Cluster, Install ArgoCD and Docker Build Push Image via Azure Devops Pipeline)



# Initialize Git Repo
cd GitOps-Workflow-with-ArgoCD-on-Kubernetes-Project
git init

# Add Files & Commit to Local Repo
git add .
git commit -am "GitOps-Workflow-with-ArgoCD-on-Kubernetes-Project"

# Add Remote Origin and Push to Remote Repo
git remote add origin https://github.com/rahulkrajput/GitOps-Workflow-with-ArgoCD-on-Kubernetes-Project.git
git push --set-upstream origin master 

```     


## Step-05: Create New Azure DevOps Project for IAC
- Go to -> Azure DevOps -> Select Organization -> GitOps-Workflow-with-ArgoCD-on-Kubernetes ->  Create New Project
- Project Name: Provision-GitOps-Workflow-with-ArgoCD-on-Terraform-AKS-Cluster
- Project Descritpion: Provision-GitOps-Workflow-with-ArgoCD-on-Terraform-AKS-Cluster
- Visibility: Private
- Click on **Create**

## Step-06: Create Azure RM Service Connection for Terraform Commands
- This is a pre-requisite step required during Azure Pipelines
- Go to -> Azure DevOps -> Select Organization -> Select project **Provision-GitOps-Workflow-with-ArgoCD-on-Terraform-AKS-Cluster**
- Go to **Project Settings**
- Go to Pipelines -> Service Connections -> Create Service Connection
- Choose a Service Connection type: Azure Resource Manager
- Identity type: App registration (automatic)
- Credential: Workload identity federation (automatic)
- Scope Level: Subscription
- Subscription: Select_Your_Subscription
- Resource Group: No need to select any resource group
- Service Connection Name: GitOps-ArgoCD-Terraform-AKS-Cluster-svc-conn
- Description: Service Connection for provisioning GitOps workflow with ArgoCD On Terraform AKS Cluster
- Security: Grant access permissions to all pipelines (check it - leave to default)
- Click on **SAVE**


## Step-07: Provide Permission to create Azure AD Groups
- Provide permission for Service connection created in previous step to create Azure AD Groups
- Go to -> Azure DevOps -> Select Organization -> Select project **Provision-GitOps-Workflow-with-ArgoCD-on-Terraform-AKS-Cluster**
- Go to **Project Settings** -> Pipelines -> Service Connections 
- Open **GitOps-ArgoCD-Terraform-AKS-Cluster-svc-conn**
- Click on **Manage App registration**, new tab will be opened 
- Click on **View API Permissions**
- Click on **Add Permission**
- Select an API: Microsoft APIs
- Microsoft APIs: Use **Microsoft Graph**
- Click on **Application Permissions**
- Select permissions : "Directory" and click on it 
- Check **Directory.ReadWrite.All** and click on **Add Permission**
- Click on **Grant Admin consent for Default Directory**



## Step-08: Create SSH Public Key for Linux VMs
- Create this out of your git repository 
- **Important Note:**  We should not have these files in our git repos for security Reasons
```
# Create Folder
mkdir $HOME/ssh-keys-terraform-aks-devops

# Create SSH Keys
ssh-keygen \
    -m PEM \
    -t rsa \
    -b 4096 \
    -C "azureuser@myserver" \
    -f ~/ssh-keys-terraform-aks-devops/aks-terraform-devops-ssh-key-ubuntu \

Note: We will have passphrase as : empty when asked

# List Files
ls -lrt $HOME/ssh-keys-terraform-aks-devops
Private File: aks-terraform-devops-ssh-key-ubuntu (To be stored safe with us)
Public File: aks-terraform-devops-ssh-key-ubuntu.pub (To be uploaded to Azure DevOps)
```

## Step-09: Upload file to Azure DevOps as Secure File
- Go to Azure DevOps -> - Go to -> Azure DevOps -> Select Organization -> GitOps-Workflow-with-ArgoCD-on-Kubernetes ->  Create New Project
 -> Provision-GitOps-Workflow-with-ArgoCD-on-Terraform-AKS-Cluster -> Pipelines -> Library
- Secure File -> Upload file named **aks-terraform-devops-ssh-key-ubuntu.pub**
- Open the file and click on **Pipeline permissions -> Click on three dots -> Confirm open access -> Click on Open access**
- Click on **SAVE**


## Step-10: Create Azure Pipeline to Provision AKS Cluster
- Go to -> Azure DevOps -> Select Organization -> Select project 
- Go to Pipelines -> Pipelines -> Create Pipeline
### Where is your Code?
- Github
- Select Your Repository
- Provide your github password
- Click on **Approve and Install** on Github
### Configure your Pipeline
- Select Pipeline: Starter Pipeline  
- Pipeline Name: 01-Provision-and-Destroy-Terraform-AKS-Cluster-Pipeline.yml
- Design your Pipeline As Per Need
### Pipeline Save and Run
- Click on **Save and Run**
- Commit Message: Provision Prod AKS Cluster via terraform
- Click on **Job** and Verify Pipeline

### Verify new Storage Account in Azure Mgmt Console

- Verify Storage Account
- Verify Storage Container
- Verify tfstate file got created in storage container

### Verify new AKS Cluster in Azure Mgmt Console
- Verify Resource Group 
- Verify AKS Cluster
- Verify AD Group
- Verify Tags for a nodepool

### Connect to Prod AKS Cluster & verify
```

# List Nodepools
az aks nodepool list --cluster-name terraform-aks-prod-cluster --resource-group terraform-aks-prod -o table

# Setup kubeconfig
az aks get-credentials --resource-group <Resource-Group-Name>  --name <AKS-Cluster-Name>
az aks get-credentials --resource-group terraform-aks-prod  --name terraform-aks-prod-cluster --admin

# View Cluster Info
kubectl cluster-info

# List Kubernetes Worker Nodes
kubectl get nodes

# Verify Deployment Status:

- ArgoCD Pods:
kubectl get pods -n argocd

- ArgoCD Service:
kubectl get svc -n argocd

- Ingress Controller Pods:
kubectl get pod -n ingress-nginx

- Ingress Controller Service:
kubectl get svc -n ingress-nginx

```
## Step-11: Create Ingress File 
```
Create Ingress File with any Name (In Our Case we create "nginx-ingress.yml" File)

#  vi nginx-ingress.yml

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-http-ingress
  namespace: argocd
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS" #(Sometime it work with HTTPS and Sometime it work with HTTP Protocol, Also change Port number as well according to your Protocol HTTPS Or HTTP)
    nginx.ingress.kubernetes.io/service-upstream: "true"
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
spec:
  
  rules:
  - host: argocd.ubei.info # Add Your Domain
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443

# Apply Nginx-Ingress File

kubectl apply -f nginx-ingress.yml

```
## Step-11A: Verify Ingress Status

```
kubectl get ingress -n argocd
```
Output:

![Image](https://github.com/user-attachments/assets/7e84f16e-9bef-49db-ac89-ead7eb320cc5)



## Step-12: Edit argocd ConfigMap 
```
Edit argocd ConfigMap and Update yaml with 

    “ data:
           server.insecure: "true"  ”

# kubectl edit configmap argocd-cmd-params-cm -n argocd -o yaml

apiVersion: v1
data:
  server.insecure: "true" 
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"ConfigMap","metadata":{"annotations":{},"labels":{"app.kubernetes.io/name":"argocd-cmd-params-cm","app.kubernetes.io/part-of":"argocd"},"name":"argocd-cmd-params-cm","namespace":"argocd"}}
  creationTimestamp: "2025-11-02T13:18:49Z"
  labels:
    app.kubernetes.io/name: argocd-cmd-params-cm
    app.kubernetes.io/part-of: argocd
  name: argocd-cmd-params-cm
  namespace: argocd
  resourceVersion: "117859"
  uid: bceeb42d-ded5-4b3a-acbb-03639e4f1b1d

```
## Step-13: Create DNS Zone 

-	Go to Azure Portal and Search -> **DNS Zones**
-	Subscription: Your_Subscription 
-	Resource Group: terraform-aks-prod-nrg
-	Name: ubei.info (Zone Name)
-	Resource Group Location: centralindia
-	Click on Review + Create

## Step-13A: Copy Azure Nameservers Name

 -	Go to Azure Portal and Search -> DNS Zones-> ubei.info-> Overview
```
ns3-05.azure-dns.org	
ns2-05.azure-dns.net	
ns1-05.azure-dns.com	
ns4-05.azure-dns.info	
```
## Step-14: Go to Your Domain Registrar Update Nameservers 

- Verify before updation

```
nslookup -type=SOA ubei.info
nslookup -type=NS ubei.info
```


Output:

<img width="663" height="319" alt="Image" src="https://github.com/user-attachments/assets/53e9e5f3-35c3-4c38-89e0-3817e270470d" />




-	Login into your Domain Provider Account (My Domain Registrar: ionos.com)
-	Click on Add or edit name servers
-	Update Azure Name servers here and click on Save
-	Wait for Next 48 hours (but usually it updates Name Servers within 3-4 hours.)
-	Verify after updation

```
nslookup -type=NS ubei.info 8.8.8.8
nslookup -type=SOA ubei.info 8.8.8.8
```

Output:

<img width="877" height="614" alt="Image" src="https://github.com/user-attachments/assets/8926082f-3f0c-46a2-ba61-1cb6034774cd" />



##  Step-15: Now, Create A record in DNS Zone (ubei.info)

-	Go to RecordSet
-	Click on Add
-	Type Name : argocd
-	Value : Type your External-IP address (Which you got when you created the Ingress Controller. If want to know about it, go to Terminal & type “ kubectl get svc -n ingress-nginx ”)


![Image](https://github.com/user-attachments/assets/e01fe98c-e2ec-44e0-a58f-6d291c4df4df)

-	Go to Browser type Your host name “argocd.ubei.info”

Output: 

<img width="975" height="638" alt="Image" src="https://github.com/user-attachments/assets/57a8b726-5f4a-465e-ba52-7dc1c3e70cd3" />


## Step-16: Logon ArgoCD Dashboard

To log in to ArgoCD Dashboard, you need to have Credentials First for that.
- Go to Your Terminal and type the following Command:

```
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
Output:

![Image](https://github.com/user-attachments/assets/d1b0d335-fab1-4d67-bb61-eea1150d2a78)

- Username:  admin
- Password:  933hQdT-FwpAnePZ

After Login

Output: 

![Image](https://github.com/user-attachments/assets/cff84b6d-7eb4-4d60-a2ae-9b5e9fb7ad80)


## Step-17: Setting Up ArgoCD Application with AKS Cluster and Kustomize 

**First you have to structuring their Kustomize files for different environments, with a suggested directory structure should look like this:**

```
~/GitOps-ArgoCD
.
├── application
│     └── Web-App.yml
└── environment
      └── prod
          ├── base
          │     ├── 01-Deployment-Web-App.yml
          │     ├── 02-Service-Web-App.yml
          │     └── kustomization.yml
          └── overlays
                ├── 01-Deployment-Web-App.yml
                └── kustomization.yml
```

**Create a New Application file to Connect with your Git repo where your Manifests File exists for deploy on AKS Cluster**

- vi Web-App.yml

```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://github.com/rahulkrajput/GitOps-Workflow-with-ArgoCD-on-Kubernetes-Project.git'
    path: GitOps-ArgoCD/environment/prod/overlays
    targetRevision: main
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: kube-web
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    automated:
      selfHeal: true
      prune: true
```
- Apply Web-App.yml File with following Command:

```
kubectl apply -f Web-App.yml
```

Output: 

![Image](https://github.com/user-attachments/assets/b15d69ae-6ec3-454a-9476-d360cb15ec2f)

*Once the Application is created, ArgoCD will monitor your Git repository for changes and automatically apply updates to your Kubernetes cluster based on the Kustomize configurations.*

- Verify Deployment
```
# To get Namespace
kubectl get ns

# To get Pods
kubectl get pod -n kube-web

# To get Service
kubectl get svc -n kube-web
```
## Step-18 Check Web-App Working Or Not

- To get the IP from Service which we deployed while Deployment
 ```
 kubectl get svc -n kube-web
 ```
 Output:
 
 ![Image](https://github.com/user-attachments/assets/6a439cdf-2c63-454d-8e25-293e7b26b91e)

 - Copy the External-IP and paste it in browser and check web page working or not

 Output:

 ![Image](https://github.com/user-attachments/assets/66ca3b82-df5d-498b-a694-1e00f598e6dd)

 Now You See, Our Web Page Working Fine.

 **We've now successfully walked through the process of setting up ArgoCD on your Terraform Azure Kubernetes Service (AKS) cluster using Azure DevOps Pipeline**

## Step-19: Delete Resources
Delete the Resources either through the Pipeline Or Manually 

### Pipeline

- If you want to Delete AKS Cluster, Uncomment "destroy task" in Provision AKS Cluster(pipeline) and re-run the pipeline

### Manually
- Delete the Resource group which will delete all resources
  - terraform-aks-prod
  
- Delete AD Groups  

## Notes

- **Make sure to replace placeholders (e.g., Your_Subscription_ID, your_cluster_name, your_region, your_resource_group_name...etc) with your actual Configuration.**

- **This is a basic setup for demonstration purposes. In a production environment, you should follow best practices for security and performance.**

## References
- [Installation Of ArgoCD](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [Kubernetes - Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Installation Of Nginx Ingress-Controller On AKS Cluster with kubectl apply, using YAML manifests](https://kubernetes.github.io/ingress-nginx/deploy/#azure)
- [Azure DevOps Pipelines - Deployment Jobs](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/deployment-jobs?view=azure-devops)
- [Azure DevOps Pipelines - Environments](https://docs.microsoft.com/en-us/azure/devops/pipelines/process/environments?view=azure-devops)
- [Declarative Management of Kubernetes Objects Using Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/)



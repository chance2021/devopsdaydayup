# Project Name: Azure Key Vault Solution

## Project Goal
In this guide, you will learn how to respond to Azure Key Vault events that are received via Azure Event Grid by using Azure Logic Apps via Terraform.

## Table of Contents
- [Project Name: Azure Key Vault Solution](#project-name-azure-key-vault-solution)
  - [Project Goal](#project-goal)
  - [Table of Contents](#table-of-contents)
  - [Prerequisites](#prerequisites)
  - [Project Steps](#project-steps)
    - [1. Login Azure](#1-login-azure)
    - [2. Run the Terraform init](#2-run-the-terraform-init)
    - [3. Run the Terraform plan](#3-run-the-terraform-plan)
    - [4. Apply the changes](#4-apply-the-changes)
    - [5. Test](#5-test)
  - [Post Project](#post-project)
  - [Troubleshooting](#troubleshooting)
  - [Reference](#reference)

## <a name="prerequisites">Prerequisites</a>
- An Azure subscription
- Azure CLI
- Terraform
- Github Repository

## <a name="project_steps">Project Steps</a>

### 1. Login Azure
Login to your Azure account
```
az login
az account list
```

### 2. Run the Terraform init
Run below command
```
git clone https://github.com/chance2021/devopsdaydayup.git
cd devopsdaydayup/017-AzureKeyVaultSecretExpirySolution/terraform/dev
terraform init
```

### 3. Run the Terraform plan
Run the plan to make sure all required resources will be created
```
terraform plan
```

### 4. Apply the changes
Apply the changes to Azure
```
terraform apply
```

### 5. Test
Go to [Azure Portal](https://portal.azure.com) and check if all resources have been created under `devopsdaydayup` resource group

## <a name="post_project">Post Project</a>
Destroy all resources
```
terraform destroy
```

## <a name="troubleshooting">Troubleshooting</a>

## <a name="reference">Reference</a>
[Use Logic Apps to receive email about status changes of key vault secrets](https://learn.microsoft.com/en-us/azure/key-vault/general/event-grid-logicapps)
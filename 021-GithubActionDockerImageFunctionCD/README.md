# Deploy Docker Image to Azure Function Using GitHub Actions

This guide provides a step-by-step process to set up a GitHub Actions pipeline for deploying a Docker image to an Azure Function. The pipeline uses an Azure Service Principal with a federated credential for secure, passwordless authentication via OpenID Connect (OIDC).

**Table of Contents**
- [Deploy Docker Image to Azure Function Using GitHub Actions](#deploy-docker-image-to-azure-function-using-github-actions)
  - [Overview](#overview)
  - [Prerequisites](#prerequisites)
  - [Steps to Configure](#steps-to-configure)
    - [1. Generate a GitHub Personal Access Token (PAT)](#1-generate-a-github-personal-access-token-pat)
    - [2. Create an Azure Function](#2-create-an-azure-function)
    - [3. Create a Service Principal](#3-create-a-service-principal)
    - [4. Add a Federated Credential](#4-add-a-federated-credential)
    - [5. Configure GitHub Secrets](#5-configure-github-secrets)
    - [6. Set Up GitHub Actions Workflow](#6-set-up-github-actions-workflow)
  - [Workflow Details](#workflow-details)
    - [Trigger Conditions](#trigger-conditions)
    - [Steps](#steps)
    - [Testing and Validation](#testing-and-validation)
  - [Best Practices](#best-practices)
  - [Post Deployment](#post-deployment)

## Overview

This solution uses the following components:
1.	**Azure Function**: A serverless compute resource where the Docker image is deployed.
2.	**Service Principal (SPN)**: Provides Azure resource access with minimal permissions.
3.	**Federated Credential**: Enables secure authentication from GitHub Actions to Azure without storing long-lived secrets.
4.	**GitHub Actions**: Automates the deployment process triggered by changes in the codebase.

## Prerequisites
1. GitHub Repository with a Docker image and workflow configuration.
2. Access to an Azure Subscription and Resource Group.
3. Basic knowledge of GitHub Actions and Azure Function deployment.

## Steps to Configure
### 1. Generate a GitHub Personal Access Token (PAT)
To enable an Azure Function to pull a container image from a private GitHub Container Registry (GHCR), you need to create a Personal Access Token (PAT) with the appropriate permissions and configure your Azure Function to use these credentials.

Steps to achieve this:
	1.	Navigate to your GitHub account settings.
  2.	Go to Developer settings > Personal access tokens > Tokens (classic).
	3.	Click on Generate new token.
	4.	Provide a note for the token, set an expiration date, and select the necessary scopes.
	5. 	For accessing GHCR, ensure you select the **read:packages** scope to grant read access to your packages.
	6.	Generate the token and copy it securely; you won’t be able to view it again.

### 2. Create an Azure Function

Create an Azure Function that uses a custom container image.
```
TENANT_ID="<Your Azure Tenant ID>"
SUBSCRIPTION_ID="<Your Azure Subscription ID>"
RESOURCE_GROUP_NAME="<Your Azure Resource Group Name>"
REGION="eastus"  # Change to your preferred region
PLAN_NAME="devOpsLab21ServicePlan"
FUNCTION_APP_NAME="currentTime"
SPN_NAME="<Your Azure Service Princile Name>"
STORAGE_ACCOUNT_NAME="lab21$(head /dev/urandom | tr -dc 'a-z0-9'| head -c 18)"
GITHUB_USERNAME="<Your GitHub Username>"  
GITHUB_REPO_NAME="<Your GitHub Repository Name>"
GITHUB_BRANCH_NAME="<Your GitHub Branch Name>"
GITHUB_IMAGE_TAG="<Your GitHub Image Tag>" # You can find the image under Package tab under your main GitHub portal page.
GITHUB_PAT="<THE PAT You Got from Step 1>"
CONTAINER_IMAGE="ghcr.io/$GITHUB_USERNAME/$GITHUB_REPO_NAME:$GITHUB_IMAGE_TAG"  # Replace with your Docker image

# Create a Resource Group
az group create --name $RESOURCE_GROUP_NAME --location $REGION

# Create a Storage Account
az storage account create --name $STORAGE_ACCOUNT_NAME --location $REGION --resource-group $RESOURCE_GROUP_NAME --sku Standard_LRS

# Create a Service Plan
az appservice plan create --name $PLAN_NAME --resource-group $RESOURCE_GROUP_NAME --is-linux --sku B1

# Create a Function
az functionapp create \
    --resource-group $RESOURCE_GROUP_NAME \
    --plan $PLAN_NAME \
    --runtime custom \
    --functions-version 4 \
    --name $FUNCTION_APP_NAME \
    --storage-account $STORAGE_ACCOUNT_NAME

az functionapp config appsettings set --name $FUNCTION_APP_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --settings \
    "DOCKER_REGISTRY_SERVER_URL=https://ghcr.io" \
    "DOCKER_REGISTRY_SERVER_USERNAME=$GITHUB_USERNAME"\
    "DOCKER_REGISTRY_SERVER_PASSWORD=$GITHUB_PAT"

az functionapp config container set --name $FUNCTION_APP_NAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --image $CONTAINER_IMAGE
```

### 3. Create a Service Principal

Create a Service Principal with the required roles.
```
az ad sp create-for-rbac --name "$SPN_NAME" --role Reader --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME

```
Output Example:
```
{
  "appId": "12345678-abcd-1234-efgh-56789ijklmn0",
  "password": "your-client-secret",
  "tenant": "12345678-1234-5678-9101-112131415abc"
}
```
Save the App ID (Client ID), Tenant ID, and Subscription ID for later use. Create a role assignement
```
CLIENT_ID=$(az ad sp list --display-name $SPN_NAME --query "[0].appId" --output tsv)

az role assignment create \
    --assignee $CLIENT_ID \
    --role Contributor \
    --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Web/sites/$FUNCTION_APP_NAME
```
Then create a federation credentials for the SPN.
```
az role assignment list --assignee $CLIENT_ID --all --output table
```

### 4. Add a Federated Credential
Configure the Service Principal to use a federated credential for GitHub Actions.
```
az ad app federated-credential create \
    --id $CLIENT_ID \
    --parameters "{
        \"name\": \"GitHubActionsFederatedCredentialForTestBranch\",
        \"issuer\": \"https://token.actions.githubusercontent.com\",
        \"subject\": \"repo:$GITHUB_OWNER/$GITHUB_REPO_NAME:ref:refs/heads/$GITHUB_BRANCH_NAME\",
        \"audiences\": [\"api://AzureADTokenExchange\"]
    }"

az ad app federated-credential create \
    --id $CLIENT_ID \
    --parameters "{
        \"name\": \"GitHubActionsFederatedCredentialForMainBranch\",
        \"issuer\": \"https://token.actions.githubusercontent.com\",
        \"subject\": \"repo:$GITHUB_OWNER/$GITHUB_REPO_NAME:ref:refs/heads/main\",
        \"audiences\": [\"api://AzureADTokenExchange\"]
    }"
```

### 5. Configure GitHub Secrets

Add the following variables to your GitHub repository as **secrets**:
- **AZURE_CLIENT_ID**: App ID of the Service Principal.
- **AZURE_TENANT_ID**: Tenant ID from the SPN creation step.
- **AZURE_SUBSCRIPTION_ID**: Subscription ID of your Azure account.

Add the following variables to your GitHub repository as **variables**:
- **RESOURCE_GROUP_NAME**: Azure resource group name which the function app is created in
- **FUNCTION_APP_NAME**: Azure Function app name
- **IMAGE_NAME**: The image address without tag
- **IMAGE_TAG**: The image tag

> Note: Regarding how to set up secrets/variables, please refer to the following links
> - Setup Secrets: https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-a-repository
> - Setup Variables: https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/store-information-in-variables#creating-configuration-variables-for-a-repository
### 6. Set Up GitHub Actions Workflow

Create a workflow file `.github/workflows/deploy-to-azure.yml`:
```
name: Deploy Docker Image to Azure Function

on:
  push:
    paths:
      - '021-GithubActionDockerImageFunctionCD/**'
  workflow_dispatch:

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    name: Deploy to Azure Function
    runs-on: ubuntu-latest

    steps:
    # Step 1: Log in to Azure
    - name: Log in to Azure
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    # Step 2: Deploy the Docker image to Azure Function
    - name: Deploy to Azure Function
      run: |
        az functionapp config container set \
          --name ${{ vars.FUNCTION_APP_NAME }} \
          --resource-group ${{ vars.RESOURCE_GROUP_NAME }} \
          --docker-custom-image-name ${{ vars.IMAGE_NAME }}:${{ vars.IMAGE_TAG }}
```

## Workflow Details

### Trigger Conditions
- The workflow triggers on:
- Pushes to files in the 021-GithubActionDockerImageFunctionCD directory.
- Manual dispatch.

### Steps
1. Login to Azure:
Uses OIDC-based authentication to securely log in to Azure.
2. Deploy Docker Image:
Configures the Azure Function to use the specified Docker image.

### Testing and Validation
1. Push changes to the `021-GithubActionDockerImageFunctionCD` directory.
2. Navigate to the Actions tab in GitHub and monitor the workflow execution.
3. Validate that the Azure Function is updated with the new image by checking its Deployment Center in the Azure Portal.

## Best Practices
1.	Limit Permissions: Assign the Service Principal the least privilege required for the task.

## Post Deployment
Remove all resources by deleting the entire resource group once your lab is completed to avoid any further cost.
```
az group delete --name $Resource_Group_Name> --yes --no-wait
```
# Lab 24: GitHub Actions Terraform CICD for Azure Function/Storage

## Overview
This lab demonstrates a full CI/CD pipeline using GitHub Actions to manage the lifecycle (dev → qa → staging → prod) of Azure Function and Storage infrastructure via Terraform.

## Architecture
- **GitHub Actions Workflow**: Orchestrates Terraform operations (plan/apply/destroy) for different environments.
- **Terraform**: Manages Azure resources (Function App, Storage Account, etc.).
- **Azure Service Principal**: Used for authentication (credentials stored as GitHub secrets).
- **Branch/Environment Mapping**:
  - `feature/*`: CI (plan only) for feature branches.
  - `develop`: CI/CD for dev environment.
  - `release/*`: CI/CD for staging.
  - `main`: CI/CD for prod.
- **Manual Trigger**: `workflow_dispatch` allows manual deployment to any environment with chosen action (plan/apply/destroy).

## Usage
### 1. Prerequisites
- Azure Service Principal with Contributor access to the target subscription.
- Store the following secrets in your GitHub repository:
  - `ARM_CLIENT_ID`
  - `ARM_CLIENT_SECRET`
  - `ARM_SUBSCRIPTION_ID`
  - `ARM_TENANT_ID`

### 2. Directory Structure
```
024-GithubActionTerraformAzureFunctionStorageCICD/
  ├── .github/workflows/terraform-azure-cicd.yml
  ├── terraform/
      ├── main.tf
      ├── variables.tf
      └── ...
```

### 3. Workflow Triggers
- **Push to feature/**: Runs `terraform plan` for dev.
- **Push to develop**: Runs `terraform apply` for dev.
- **Push to release/**: Runs `terraform apply` for staging.
- **Push to main**: Runs `terraform apply` for prod.
- **Manual Dispatch**: Choose environment and action (plan/apply/destroy).

### 4. How to Use
- Push code to the appropriate branch to trigger the workflow automatically.
- Or, go to GitHub Actions tab, select the workflow, and click "Run workflow" to manually select environment and action.

### 5. Customization
- Edit the `terraform/` directory to define your Azure Function and Storage resources.
- Adjust environment variables and secrets as needed.

## Example: Manual Deployment
1. Go to the Actions tab in your GitHub repo.
2. Select the workflow: **Azure Function/Storage Terraform CICD**.
3. Click **Run workflow**.
4. Choose environment (dev/qa/staging/prod) and action (plan/apply/destroy).
5. Monitor the workflow for results.

---

## Diagram
```
+---------+        +-------------------+        +-------------------+
|  User   |  -->   | GitHub Actions    |  -->   | Azure (Terraform) |
+---------+        +-------------------+        +-------------------+
```

- User pushes code or triggers workflow
- GitHub Actions runs Terraform
- Azure resources are created/updated/destroyed

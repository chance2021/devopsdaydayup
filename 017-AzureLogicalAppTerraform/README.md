# Lab 17 — Azure Logic App + Key Vault Alerts with Terraform

Provision the infrastructure for a Logic App Standard that can process Key Vault secret-expiry events delivered via Event Grid and a Storage Queue. Terraform creates the resource group, storage accounts, App Service plan, and Logic App plumbing; you wire the workflow to your Key Vault and Event Grid subscription afterward.

> Use your own subscription IDs, tenant IDs, and unique resource names. Do not commit secrets.

## Prerequisites

- Azure subscription with permissions to create RG, Storage Account, App Service Plan, Logic App
- Azure CLI authenticated: `az login` and `az account set --subscription <SUBSCRIPTION_ID>`
- Terraform 1.x

## Steps

1) Clone and move into the Terraform code
```bash
git clone https://github.com/chance2021/devopsdaydayup.git
cd devopsdaydayup/017-AzureLogicalAppTerraform/terraform/dev
```

2) Configure variables
- Edit `main.auto.tfvars` with your subscription ID, tenant ID, resource group name, location, and naming values.
- Update locals for unique names as needed:
  - `storage_accounts.tf` (two storage accounts are declared)
  - `app-service-plan.tf` (App Service plan name/sku)
  - `logic-app-standard.tf` (Logic App name and storage account binding)

3) Initialize Terraform
```bash
terraform init
```

4) Plan the deployment
```bash
terraform plan -var-file=main.auto.tfvars
```

5) Apply the infrastructure
```bash
terraform apply -var-file=main.auto.tfvars
```

6) Wire Logic App to Key Vault events (portal)
- Create an Event Grid subscription on your Key Vault for secret expiration/near-expiry events that sends messages to the Storage Queue created above.
- In the Logic App Standard, add a trigger that watches the Storage Queue and a step to send notifications (email, Teams, etc.).

## Validation

- Portal shows the resource group with storage accounts, App Service plan, and Logic App.
- Logic App designer can access the Storage Queue and the trigger saves without errors.
- Create a test secret with a near-expiry date; Event Grid pushes to the queue and the Logic App processes the message.

## Cleanup

```bash
terraform destroy -var-file=main.auto.tfvars
```

## Troubleshooting

- **Name already taken**: Storage account and Logic App names must be globally unique.
- **Logic App cannot see queue**: Confirm the storage account name/access key values in `logic-app-standard.tf` match the deployed storage account.
- **Event Grid delivery fails**: Ensure the queue endpoint is reachable and the Event Grid system topic is enabled for Key Vault events.

## Reference
- Use Logic Apps to receive email about status changes of Key Vault secrets: https://learn.microsoft.com/en-us/azure/key-vault/general/event-grid-logicapps

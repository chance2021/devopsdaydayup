# Lab 16 — Azure Function Infrastructure with Terraform

Provision the Azure resources for a Function App (resource group, storage accounts, App Service plan, Function App) using Terraform, then optionally deploy the sample Python/Node function code under `app/`.

> Replace every subscription ID, tenant ID, storage account name, and access key with your own values. Do not commit real secrets.

## Prerequisites

- Azure subscription with owner/contributor rights
- Azure CLI (`az`) logged in: `az login` and `az account set --subscription <SUBSCRIPTION_ID>`
- Terraform 1.x
- (Optional) Azure Functions Core Tools if you want to publish the sample function code

## Steps

1) Clone and move into the lab
```bash
git clone https://github.com/chance2021/devopsdaydayup.git
cd devopsdaydayup/016-AzureFunctionTerraform/function-apps/dev-working
```

2) Update variables and locals
- Edit `main.auto.tfvars` with your subscription/tenant, resource group name, location, and naming values.
- In `storage_accounts.tf` and `function-apps.tf`, change the sample storage account names, Function App name, and `storage_account_access_key` to your own values. Use Azure Key Vault or environment variables instead of hardcoding keys in real environments.

3) Initialize Terraform
```bash
terraform init
```

4) Create a plan
```bash
terraform plan -var-file=main.auto.tfvars
```

5) Apply the infrastructure
```bash
terraform apply -var-file=main.auto.tfvars
```

6) (Optional) Deploy sample function code
- From `app/ChancePythonProject2`, install dependencies and publish to the Function App you created:
  ```bash
  cd ../../app/ChancePythonProject2
  python -m venv .venv && source .venv/bin/activate
  pip install -r requirements.txt
  func azure functionapp publish <YOUR_FUNCTION_APP_NAME> --python
  ```

## Validation

- `az functionapp show --name <YOUR_FUNCTION_APP_NAME> --resource-group <RG_NAME>` returns `state: Running`.
- `az storage account show --name <STORAGE_ACCOUNT_NAME> --resource-group <RG_NAME>` succeeds.
- Portal > Function App shows the app running and (if published) the sample function endpoint is reachable.

## Cleanup

Destroy the lab resources to avoid charges:
```bash
cd devopsdaydayup/016-AzureFunctionTerraform/function-apps/dev-working
terraform destroy -var-file=main.auto.tfvars
```

## Troubleshooting

- **Name already taken**: Storage account and Function App names must be globally unique; adjust locals before applying.
- **Auth errors**: Ensure `az login` succeeded and the configured subscription ID matches the one in `main.auto.tfvars`.
- **Function publish fails**: Confirm the Function App is on Linux (matches your runtime), and that `FUNCTIONS_EXTENSION_VERSION`/`FUNCTIONS_WORKER_RUNTIME` are set if you customize the code.

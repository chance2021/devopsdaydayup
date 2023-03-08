# Project Name: Upgrade AKS Version

## Project Goal
In this lab, you will experience how to upgrade AKS cluster version via Terraform script

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Project Steps](#project_steps)
3. [Post Project](#post_project)
4. [Troubleshooting](#troubleshooting)
5. [Reference](#reference)

## <a name="prerequisites">Prerequisites</a>
- Microsoft Account
- Ubuntu 20.04 OS (Minimum 2 core CPU/8GB RAM/30GB Disk)


## <a name="project_steps">Project Steps</a>

### 1. Export Env Variables for AKS Terraform Update
Export below env variables after logging your azure account (`az login`):
```
export TERRAFORM_STATE_KEY=
export STORAGE_ACCOUNT_NAME=
export CONTAINER_NAME=
export ACCOUNT_KEY=
export TF_VAR_client_id=
export TF_VAR_client_secret=
export TF_VAR_object_id=
export TF_VAR_prefix=
export TF_VAR_location=
export TF_VAR_network_watcher_name=
export TF_VAR_user_ip=
export TF_VAR_user_id=
export ARM_CLIENT_ID=
export ARM_CLIENT_SECRET=
export ARM_SUBSCRIPTION_ID=
export ARM_TENANT_ID=
```

### 2. Update AKS Version
Based on the Terraform script which created the AKS, update the corresponding variable (e.g. `k8s_version` in your **terraform.tfvars**)

### 3. Apply Changes
> Note: Before the update, you'd better scale down some applications' replicas (e.g. `vault`) to 0. Otherwise, it may prevent the worker nodes to be removed/restarted.
```
terraform init -backend-config=config/test/config.tf 
terraform plan -var-file=config/test/test.tfvars -out deploy.tfplan
terraform apply deploy.tfplan
```

## <a name="post_project">Post Project</a>
Delete the related resource groups in your Azure portal

## <a name="troubleshooting">Troubleshooting</a>

## <a name="reference">Reference</a>

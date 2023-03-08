# Velero Setup

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Project Steps](#project_steps)
3. [Post Project](#post_project)
4. [Troubleshooting](#troubleshooting)
5. [Reference](#reference)

## <a name="prerequisites">Prerequisites</a>
- Ubuntu 20.04 OS (Minimum 2 core CPU/8GB RAM/30GB Disk)
- Azure Storage Account
- Azure AKS

## <a name="project_steps">Project Steps</a>

### 1. Install Velero Binary
```
wget https://github.com/vmware-tanzu/velero/releases/download/v1.10.2-rc.2/velero-v1.10.2-rc.2-linux-amd64.tar.gz
tar -xvf velero-v1.10.2-rc.2-linux-amd64.tar.gz
sudo mv velero-v1.10.2-rc.2-linux-amd64/velero /usr/bin
```
> Note: You can download the most recent version in [https://github.com/vmware-tanzu/velero/releases](https://github.com/vmware-tanzu/velero/releases)

### 2. Deploy Velero into AKS
```
az login
AZURE_BACKUP_RESOURCE_GROUP=test-velero-backups
az group create -n $AZURE_BACKUP_RESOURCE_GROUP --location canadacentral
AZURE_STORAGE_ACCOUNT_ID="testvelero$(uuidgen | cut -d '-' -f5 | tr '[A-Z]' '[a-z]')"
az storage account create \
    --name $AZURE_STORAGE_ACCOUNT_ID \
    --resource-group $AZURE_BACKUP_RESOURCE_GROUP \
    --sku Standard_GRS \
    --encryption-services blob \
    --https-only true \
    --kind BlobStorage \
    --access-tier Hot
    
BLOB_CONTAINER=velero
az storage container create -n $BLOB_CONTAINER --public-access off --account-name $AZURE_STORAGE_ACCOUNT_ID

AZURE_SUBSCRIPTION_ID=`az account list --query '[?isDefault].id' -o tsv`
AZURE_TENANT_ID=`az account list --query '[?isDefault].tenantId' -o tsv`

AZURE_CLIENT_SECRET=`az ad sp create-for-rbac --name "dev-velero" --role "Contributor" --query 'password' -o tsv --scopes /subscriptions/$AZURE_SUBSCRIPTION_ID`
AZURE_CLIENT_ID=`az ad sp list --display-name "dev-velero" --query '[0].appId' -o tsv`

cat << EOF  > ./credentials-velero
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
AZURE_TENANT_ID=${AZURE_TENANT_ID}
AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
AZURE_RESOURCE_GROUP=${AZURE_BACKUP_RESOURCE_GROUP}
EOF

velero install \
    --provider azure \
    --plugins velero/velero-plugin-for-microsoft-azure:v1.0.0 \
    --bucket $BLOB_CONTAINER \
    --secret-file ./credentials-velero \
    --backup-location-config resourceGroup=$AZURE_BACKUP_RESOURCE_GROUP,storageAccount=$AZURE_STORAGE_ACCOUNT_ID \
    --snapshot-location-config apiTimeout=10m,resourceGroup=$AZURE_BACKUP_RESOURCE_GROUP
```

### 3. Run Backup
```
velero backup create <BACKUP_NAME> --include-namespaces <Namespace_Name>
```

### 4. Verification
```
velero backup describe  <BACKUP_NAME>
velero backup logs  <BACKUP_NAME>
```

### 5. Restore
```
velero restore create --from-backup  <BACKUP_NAME>
```

## <a name="post_project">Post Project</a>
Uninstall velero
```
velero uninstall
```
Remove the corresponding resource groups, as well as the service principal

## <a name="reference">Reference</a>

- [Velero Install](https://velero.io/docs/v1.1.0/azure-config/)
- [Deploy Velero in AKS](https://github.com/mutazn/Backup-and-Restore-AKS-cluster-using-Velero)
- [Backup AKS via Velero](https://learn.microsoft.com/en-us/azure/aks/hybrid/backup-workload-cluster)


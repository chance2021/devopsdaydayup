# Project Name: Upgrade Keycloak Helm Chart

## Project Goal
In this lab, we will guide you through the process of upgrading the Keycloak Bitnami Helm chart from version 6 (which uses Keycloak version 16) to version 13 (which uses Keycloak version 20).

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Project Steps](#project_steps)
3. [Roll Back](#post_project)
4. [Troubleshooting](#troubleshooting)
5. [Reference](#reference)

## <a name="prerequisites">Prerequisites</a>
- Ubuntu 20.04 OS (Minimum 2 core CPU/8GB RAM/30GB Disk)
- Docker(see installation guide [here](https://docs.docker.com/get-docker/))
- Docker Compose(see installation guide [here](https://docs.docker.com/compose/install/))
- Minikube (see installation guide [here](https://minikube.sigs.k8s.io/docs/start/))
- Helm (see installation guide [here](https://helm.sh/docs/intro/install/)


## <a name="project_steps">Project Steps</a>
### 1. Start Minikube
You can install the **Minikube** by following the instruction in the [Minikube official website](https://minikube.sigs.k8s.io/docs/start/). Once it is installed, start the minikube by running below command:
```
minikube start
minikube status
```
Once the Minikube starts, you can download the **kubectl** from [k8s official website](https://kubernetes.io/docs/tasks/tools/)
```
minikube kubectl
alias k="kubectl"
```
Then, when you run the command `kubectl get node` or `k get node`, you should see below output:
```
NAME       STATUS   ROLES           AGE     VERSION
minikube   Ready    control-plane   4m37s   v1.25.3
```
Update the minio username and password in `vault-backup-values.yaml`
```
MINIO_USERNAME=$(kubectl get secret -l app=minio -o=jsonpath="{.items[0].data.rootUser}"|base64 -d)
echo "MINIO_USERNAME is $MINIO_USERNAME"
MINIO_PASSWORD=$(kubectl get secret -l app=minio -o=jsonpath="{.items[0].data.rootPassword}"|base64 -d)
echo "MINIO_PASSWORD is $MINIO_PASSWORD"
```


### 2. Setup Keycloak v16
Run below commands to **deploy Keycloak v16**:
```
k create ns test-keycloak
helm repo add old-bitnami https://raw.githubusercontent.com/bitnami/charts/archive-full-index/bitnami
helm -n test-keycloak upgrade --install -f values-keycloak-16.yaml keycloak old-bitnami/keycloak --version v6.1.0
```
You can just **make some changes** in the Keycloak configuration (e.g. adding users/groups/clients) so that we can verify that later after upgrading.

### 3. Backup Keycloak
You can either backup the data from the postgres database as following steps:
```
PGPASSWORD=$(kubectl -n test-keycloak get secret --namespace "keycloak" keycloak-postgresql -o jsonpath="{.data.postgresql-password}" | base64 --decode)
echo $PGPASSWORD

k exec -n test-keycloak -it keycloak-postgresql-0 -- bash
PGUSER=postgres
PGPASSWORD=$PGPASSWORD
PGDATABASE=bitnami_keycloak
PGHOST=keycloak-postgresql.keycloak
BACKUP_NAME=keycloak-backupOn-`date +%Y%m%d%H%M`
PGPASSWORD=$PGPASSWORD pg_dump -U $PGUSER -h $PGHOST -p 5432 -d $PGDATABASE |gzip > /tmp/$BACKUP_NAME.gz
exit
kubectl cp  test-keycloak/keycloak-postgresql-0:/tmp/$BACKUP_NAME.gz  .

> Note: If the username is different, you need to update the owner in the backup sql
gzip -d $BACKUP_NAME.gz
sed -i 's/OWNER TO <previous_usrename>/OWNER TO bn_keycloak/g' $BACKUP_NAME
sed -i  's/Owner: <previous_usrename>/Owner: bn_keycloak/g' $BACKUP_NAME
```
Or you can use Velero to backup entire keycloak namespace (ref: [Velero Installation](https://github.com/chance2021/devopsdaydayup/tree/main/aks/backup-solution-velero#readme))
```
velero backup create keycloak-ns --include-namespaces test-keycloak
```

### 4. Deploy Postgresql V15
Since Keycloak v20 helm chart is combined with Postgresql v15, we will deploy the postgres helm chart separately:
```
helm -n test-keycloak install keycloak20-postgresql15 bitnami/postgresql  --version 12.2.2 -f values-postgres-15-for-keycloak-20.yaml
```

### 5. Restore Backup to Postgresql V15
We are going to restore the keycloak backup completed in previous step into the new Postgresql V15 instance:
```
export POSTGRES_PASSWORD=$(kubectl get secret --namespace keycloak keycloak20-postgresql15 -o jsonpath="{.data.password}" | base64 -d)
echo $POSTGRES_PASSWORD
k cp <BACKUP_NAME>.gz keycloak20-postgresql15-0:/tmp
k -n keycloak exec -it keycloak20-postgresql15-0 -- bash
psql --host 127.0.0.1 -U bn_keycloak -d postgres -p 5432
create database keycloak16;
GRANT ALL PRIVILEGES ON DATABASE keycloak16 TO bn_keycloak;
\q
cd /tmp
gzip -d <BACKUP_NAME>.gz
psql -U postgres -f /tmp/<BACKUP_NAME> -d keycloak16
```

### 6. Re-Deploy Keycloak Helm Chart to V20
Upgrade Keycloak Helm chart to the newer version, which will connect to the postgres v15 as **external database**
```
helm -n keycloak upgrade -f values-keycloak-20.yaml keycloak bitnami/keycloak --version 13.2.0 
```

### 7. Verification
Port forward the Keycloak service and verify if the website is up and running with the previous configuration:
```
kubectl -n test-keycloak port-forward svc/keycloak 8888:80
```
Open your local broswer and go to the [Keycloak website](http://localhost:8888). Check if all changes you made before the upgrading still exist.

## <a name="post_project">Roll Back</a>
If for any case you would like to roll back to previous Keycloak, you can just simply re-deploy the Keycloak with the previous values.yaml (e.g. `values-keycloak-16.yaml`)
```
helm -n test-keycloak upgrade -f values-keycloak-16.yaml keycloak old-bitnami/keycloak --version v6.1.0
```



## <a name="troubleshooting">Troubleshooting</a>

## <a name="reference">Reference</a>

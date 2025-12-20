# Lab 12 — Backup Vault to MinIO via Kubernetes CronJob (Minikube)

Deploy MinIO and Vault on Minikube, then schedule a CronJob to back up Vault data into a MinIO bucket.

> Use placeholders for secrets (e.g., `rootPassword`, Vault tokens). Do not commit real credentials.

## Prerequisites

- Ubuntu 20.04 host (>= 2 vCPU, 8 GB RAM)
- Docker, Docker Compose
- Minikube running
- Helm v3 installed

## Setup

1) Start Minikube and set kubectl alias
```bash
minikube start
alias k="kubectl"
```

2) Install Helm (if needed)
```bash
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```

3) Deploy MinIO (test/standalone)
```bash
helm repo add minio https://charts.min.io/
kubectl create ns minio
helm install --set resources.requests.memory=512Mi \
  --set replicas=1 \
  --set mode=standalone \
  --set rootUser=rootuser,rootPassword=Test1234! \
  --generate-name minio/minio -n minio
```
Get credentials if needed:
```bash
MINIO_USERNAME=$(kubectl get secret -n minio -l app=minio -o=jsonpath="{.items[0].data.rootUser}"|base64 -d)
MINIO_PASSWORD=$(kubectl get secret -n minio -l app=minio -o=jsonpath="{.items[0].data.rootPassword}"|base64 -d)
```

4) Create a MinIO bucket
```bash
kubectl -n minio port-forward svc/$(kubectl -n minio get svc|grep console|awk '{print $1}') 9001:9001
# login at http://localhost:9001 with the credentials above and create bucket "test"
```

5) Deploy Vault (lab settings)
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
kubectl create ns vault-test
cat > vault-values.yaml <<'EOF'
injector:
  enabled: "-"
  replicas: 1
  image:
    repository: "hashicorp/vault-k8s"
    tag: "1.1.0"
server:
  enabled: "-"
  image:
    repository: "hashicorp/vault"
    tag: "1.12.1"
EOF
helm -n vault-test install vault hashicorp/vault -f vault-values.yaml
```
Initialize and unseal:
```bash
kubectl -n vault-test exec vault-0 -- vault operator init
kubectl -n vault-test exec vault-0 -- vault operator unseal <UNSEAL_KEY1>
kubectl -n vault-test exec vault-0 -- vault operator unseal <UNSEAL_KEY2>
kubectl -n vault-test exec vault-0 -- vault operator unseal <UNSEAL_KEY3>
```
Enable kv and AppRole (example):
```bash
kubectl -n vault-test exec -it vault-0 -- sh -c '
vault login <ROOT_TOKEN>
vault secrets enable -version=2 kv-v2
vault kv put -mount=kv-v2 devops-secret username=root password=changeme
cat > /tmp/policy.hcl <<EOF
path "kv-v2/*" { capabilities = ["create","update","read"] }
EOF
vault policy write first-policy /tmp/policy.hcl
vault auth enable approle
vault write auth/approle/role/first-role secret_id_ttl=10000m token_num_uses=10 token_ttl=20000m token_max_ttl=30000m secret_id_num_uses=40 token_policies=first-policy
ROLE_ID=$(vault read -field=role_id auth/approle/role/first-role/role-id); echo ROLE_ID=$ROLE_ID
SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/first-role/secret-id); echo SECRET_ID=$SECRET_ID
'
```

6) Deploy the Vault backup CronJob
```bash
kubectl -n vault-test create configmap upload --from-file=upload.sh
helm -n vault-test upgrade --install vault-backup helm-chart -f vault-backup-values.yaml
kubectl -n vault-test create job vault-backup-test --from=cronjob/vault-backup-cronjob
```
Ensure `vault-backup-values.yaml` is updated with the MinIO service name and credentials.

## Validation

- In MinIO console (`http://localhost:9001`), open the `test` bucket and verify backup objects are present.
- `kubectl -n vault-test get cronjobs` shows the schedule and `kubectl -n vault-test get jobs` shows successful runs.

## Cleanup

```bash
helm uninstall vault-backup -n vault-test || true
helm uninstall vault -n vault-test || true
helm uninstall <minio-release-name> -n minio || true
kubectl delete ns vault-test minio
minikube stop
```

## Troubleshooting

- **CronJob fails to reach MinIO**: Verify `MINIO_ADDR` and credentials in `vault-backup-values.yaml`; ensure MinIO service name is correct.
- **Vault sealed errors**: Unseal before running backups; check `vault status` inside the pod.
- **No backups appear**: Check the Job logs: `kubectl -n vault-test logs job/vault-backup-test`.

## References

- https://github.com/minio/minio/tree/master/helm/minio
- https://www.vaultproject.io/docs/platform/k8s/helm

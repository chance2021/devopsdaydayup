# Lab 14 — Vault Agent Sidecar Injector on Minikube

Deploy Vault via Helm on Minikube and inject secrets into a pod using the Vault Agent sidecar.

> Keep unseal keys, root tokens, and passwords out of source control. Use placeholders where needed.

## Prerequisites

- Ubuntu 20.04 host (>= 2 vCPU, 8 GB RAM)
- Docker, Minikube, Helm v3

## Setup

1) Add the HashiCorp Helm repo and install Vault
```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm install vault hashicorp/vault -f values.yaml
```

2) Initialize and unseal Vault
```bash
kubectl exec -it vault-0 -- vault operator init          # save unseal keys/root token
kubectl exec -it vault-0 -- vault operator unseal <KEY1>
kubectl exec -it vault-0 -- vault operator unseal <KEY2>
kubectl exec -it vault-0 -- vault operator unseal <KEY3>
kubectl exec -it vault-0 -- vault login <ROOT_TOKEN>
```

3) Enable KV v2 and write a test secret
```bash
kubectl exec -it vault-0 -- sh -c '
vault secrets enable -path=internal-app kv-v2
vault kv put internal-app/database/config username=root password=changeme
'
```

4) Configure Kubernetes auth
```bash
kubectl exec -it vault-0 -- sh -c '
vault auth enable kubernetes
vault write auth/kubernetes/config kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"
vault policy write internal-app - <<EOF
path "internal-app/data/database/config" {
  capabilities = ["read"]
}
EOF
vault write auth/kubernetes/role/internal-app \
  bound_service_account_names=app-sa \
  bound_service_account_namespaces=default \
  policies=internal-app \
  ttl=24h
'
```

5) Deploy the sample app
```bash
kubectl apply -f app-deployment.yaml
kubectl wait pods -n default -l app=nginx --for condition=Ready --timeout=600s
```

6) Patch deployment for sidecar injection
```bash
kubectl patch deployment app-deployment --patch "$(cat patch-app-deployment.yaml)"
```

7) Verify secrets injected
```bash
kubectl exec $(kubectl get pod -l app=nginx -o jsonpath='{.items[0].metadata.name}') -- cat /vault/secrets/database-config.txt
```

## Validation

- Pod shows an injected Vault agent container.
- `/vault/secrets/database-config.txt` contains the secret from `internal-app/database/config`.

## Cleanup

```bash
minikube stop
```

## Troubleshooting

- **Pod pending**: Check storage/PVC requirements from the Helm chart; ensure Minikube has resources.
- **Auth failures**: Confirm Kubernetes auth config points to the correct API server and service account (`app-sa`) exists in `default`.
- **Secret path mismatch**: Policy uses `internal-app/data/...` for KV v2; ensure patch references the same path.

## References

- https://developer.hashicorp.com/vault/docs/platform/k8s/helm
- https://developer.hashicorp.com/vault/docs/platform/k8s/injector

# Lab 11 — Create a Read-Only Kubeconfig (kind)

Create a restricted kubeconfig using a service account, RBAC, and a manually generated token on a kind cluster.

> Do not reuse real cluster credentials from production. The token here is for lab use only.

## Prerequisites

- Ubuntu 20.04 host (>= 2 vCPU, 8 GB RAM)
- Docker, Docker Compose
- kind installed
- kubectl installed

## Setup

1) Install kind
```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.17.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

2) Create a kind cluster and test kubectl
```bash
kind create cluster
kubectl get nodes
kubectl -n default create deploy test --image=nginx
```

3) Create service account, token Secret, and RBAC

Create `readonly-manifest.yaml`:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: readonly
  namespace: default
---
apiVersion: v1
kind: Secret
metadata:
  name: readonly-token
  annotations:
    kubernetes.io/service-account.name: readonly
type: kubernetes.io/service-account-token
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: readonly-clusterrole
rules:
  - apiGroups: [""]
    resources: ["*"]
    verbs: ["get","list","watch"]
  - apiGroups: [""]
    resources: ["pods/exec","pods/portforward"]
    verbs: ["create"]
  - apiGroups: ["extensions","apps"]
    resources: ["*"]
    verbs: ["get","list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: readonly-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: readonly-clusterrole
subjects:
  - kind: ServiceAccount
    name: readonly
    namespace: default
```
Apply it:
```bash
kubectl apply -f readonly-manifest.yaml
```
> Kubernetes 1.24+ does not auto-create SA tokens; the Secret above is required.

4) Generate the read-only kubeconfig
```bash
server=$(kubectl config view --minify --output jsonpath='{.clusters[*].cluster.server}')
ca=$(kubectl get secret/readonly-token -n default -o jsonpath='{.data.ca\.crt}')
token=$(kubectl get secret/readonly-token -n default -o jsonpath='{.data.token}' | base64 --decode)

cat > readonly-kubeconfig.yml <<EOF
apiVersion: v1
kind: Config
clusters:
- name: kind-readonly
  cluster:
    certificate-authority-data: ${ca}
    server: ${server}
contexts:
- name: readonly
  context:
    cluster: kind-readonly
    namespace: default
    user: readonly-user
current-context: readonly
users:
- name: readonly-user
  user:
    token: ${token}
EOF

cp ~/.kube/config ~/.kube/config.$(date +%Y%m%d).bak
KUBECONFIG=~/.kube/config:readonly-kubeconfig.yml kubectl config view --flatten > /tmp/merged-config
mv /tmp/merged-config ~/.kube/config
```

## Validation

```bash
kubectl config use-context readonly
kubectl get nodes
kubectl -n default get pod --watch
kubectl exec -it $(kubectl get pod -n default -o jsonpath='{.items[0].metadata.name}') -- bash
```
Creating/deleting resources should fail; listing and exec should work.

## Cleanup

```bash
kubectl delete -f readonly-manifest.yaml
kind delete cluster
```

## Troubleshooting

- **Token missing**: Ensure the Secret of type `kubernetes.io/service-account-token` exists and is annotated with the SA name.
- **Context not switching**: Confirm the merged kubeconfig includes the `readonly` context and user.

## References

- https://kind.sigs.k8s.io/docs/user/quick-start/
- https://kubernetes.io/docs/concepts/configuration/secret/#service-account-token-secrets

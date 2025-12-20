# Lab 24 — Argo Events ➜ Workflows ➜ Argo CD ➜ Rollouts

Build a full GitOps chain that turns a GitHub push into a progressive Argo Rollout on Minikube. GitHub webhooks are relayed via Smee.io to Argo Events, an Argo Workflow builds and pushes an image, Helm values are committed back to GitHub, and Argo CD reconciles the change to multiple namespaces using an ApplicationSet and Argo Rollouts.

> Use placeholders for all secrets (for example `YOUR_GITHUB_TOKEN`, `YOUR_GHCR_REPO`). Do not commit real tokens or registry credentials. Store them as environment variables or in a secret manager.

## Architecture

```
GitHub push → Smee relay → Argo Events (EventSource + Sensor) → Argo Workflow
  → GHCR image + Git commit to Helm values → Argo CD ApplicationSet
  → Argo Rollout deployed to Minikube
```

## Prerequisites

- macOS/Linux shell with `kubectl`, `helm`, `minikube`, `docker` (or compatible runtime), and `jq`
- Argo CLIs: `argo` and `kubectl argo rollouts`
- GitHub:
  - Personal access token with `repo`, `workflow`, and `write:packages`
  - A fork of this repository so the workflow can push commits
  - A GHCR repository, e.g., `ghcr.io/${GITHUB_USER}/lab24-rollouts`
- Resources: Minikube with >= 4 CPUs and 8–12 GB RAM
- Network access to download Argo controller manifests

Recommended environment variables:

```bash
export GITHUB_USER="YOUR_GITHUB_USER"
export GITHUB_EMAIL="you@example.com"
export GITHUB_TOKEN="YOUR_GITHUB_TOKEN"
export GHCR_REPO="ghcr.io/${GITHUB_USER}/lab24-rollouts"
export SMEE_RELAY_IMAGE="ghcr.io/${GITHUB_USER}/smee-relay:latest"
export GIT_REMOTE="github.com/${GITHUB_USER}/lab24-argo-cicd.git"
```

## Setup and Steps

### 1) Start Minikube and install Argo controllers

```bash
minikube start --kubernetes-version=v1.29.0 --cpus=4 --memory=8192

kubectl create namespace argocd
kubectl create namespace argo-events
kubectl create namespace argo-rollouts
kubectl create namespace argo
kubectl create namespace cicd

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/latest/download/install.yaml
kubectl apply -n argo-events -f https://github.com/argoproj/argo-events/releases/latest/download/install.yaml
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

### 2) Create service accounts, roles, and secrets

Provision workflow permissions and registry/Git secrets:

```bash
kubectl apply -f argo-workflows/controller-namespace-rbac.yaml

kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: workflow-runner
  namespace: cicd
imagePullSecrets:
  - name: ghcr-creds
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workflow-role
  namespace: cicd
rules:
  - apiGroups: [""]
    resources: [pods, pods/log, pods/exec, persistentvolumeclaims, configmaps, secrets]
    verbs: [create, update, patch, delete, get, list, watch]
  - apiGroups: ["argoproj.io"]
    resources: [workflows, workflowtemplates, clusterworkflowtemplates, workflowtaskresults]
    verbs: [create, update, patch, delete, get, list, watch]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workflow-rolebinding
  namespace: cicd
subjects:
  - kind: ServiceAccount
    name: workflow-runner
    namespace: cicd
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: workflow-role
EOF
```

Add registry and Git credentials plus the shared webhook secret (replace placeholders):

```bash
kubectl create secret docker-registry ghcr-creds \
  --namespace cicd \
  --docker-server=ghcr.io \
  --docker-username="${GITHUB_USER}" \
  --docker-password="${GITHUB_TOKEN}"

kubectl create secret generic github-token \
  --namespace cicd \
  --from-literal=username="${GITHUB_USER}" \
  --from-literal=email="workflow@example.com" \
  --from-literal=token="${GITHUB_TOKEN}"

WEBHOOK_SECRET=$(openssl rand -hex 32)
kubectl create secret generic github-webhook-secret \
  --namespace argo-events \
  --from-literal=token="${WEBHOOK_SECRET}"
```

### 3) Install the WorkflowTemplate

Use the supplied template to build, push, and commit Helm value changes:

```bash
kubectl apply -f argo-workflows/workflow-template.yaml
```

> Do not run `envsubst` on this file; it relies on inline shell variables inside the `detectchanges` step.

### 4) Configure Argo Events and the in-cluster Smee relay

1. Create a new Smee channel at <https://smee.io> and copy the URL (e.g., `https://smee.io/abc123`).
2. Add a GitHub webhook on your fork (**Settings → Webhooks**) pointing to the Smee URL. Use the same secret stored in `github-webhook-secret`. Select the **push** event.
3. Store the Smee URL in-cluster:
   ```bash
   kubectl create secret generic smee-relay-url \
     --namespace argo-events \
     --from-literal=url="https://smee.io/abc123"
   ```
4. Build and push the relay image, then make the package public:
   ```bash
   docker build -t "${SMEE_RELAY_IMAGE}" apps/smee-relay
   docker push "${SMEE_RELAY_IMAGE}"
   ```
5. Update manifest values to point to your fork and images:
   - `argo-events/smee-relay-deployment.yaml`: set the relay image to `${SMEE_RELAY_IMAGE}`.
   - `argo-events/sensor.yaml`: set `gitrepo` to your fork (e.g., `https://github.com/${GITHUB_USER}/lab24-argo-cicd.git`) and `imagename` to `${GHCR_REPO}`.
6. Apply the Argo Events resources:
   ```bash
   kubectl apply -f argo-events/event-bus.yaml
   kubectl apply -f argo-events/event-source.yaml
   kubectl apply -f argo-events/smee-relay-deployment.yaml
   kubectl apply -f argo-events/workflow-trigger-rbac.yaml
   kubectl apply -f argo-events/sensor.yaml
   ```

### 5) Bootstrap Argo CD and the ApplicationSet

Point Argo CD at your fork:

```bash
# Update repoURL/targetRevision in argocd manifests if you use a branch other than main
kubectl apply -f argocd/root-app-appsets.yaml
```

The ApplicationSet in `argocd/applicationsets/my-service-applicationset.yaml` renders one Argo CD Application per environment (`dev`, `staging`, `prod`), each deploying the Helm chart with an Argo Rollout.

### 6) Trigger the pipeline

1. Commit a small change under `apps/my-service/app/` (for example, edit `index.html`) and push to `main` on your fork.
2. Watch Argo Events and the workflow:
   ```bash
   kubectl -n argo-events logs deploy/github-webhook-eventsource | tail
   kubectl -n argo-events logs deploy/smee-relay | tail
   argo -n cicd list
   argo -n cicd watch @latest
   ```
3. When the workflow finishes, Argo CD will detect the Helm values change and sync. Observe the rollout:
   ```bash
   kubectl argo rollouts get rollout my-service-dev-hello-world -n my-service-dev --watch
   kubectl argo rollouts promote my-service-dev-hello-world -n my-service-dev   # when paused
   ```
4. Port-forward to view the updated page:
   ```bash
   kubectl -n my-service-dev port-forward svc/my-service 8080:80
   ```
   Open `http://localhost:8080` to confirm the new version text.

## Validation

- `argo -n cicd list` shows the workflow succeeded and published a new image tag.
- `kubectl argo rollouts get rollout ...` shows the rollout progressing and completing.
- `kubectl -n my-service-dev get pods` shows pods running the new tag.
- GHCR repository contains the pushed image: `docker pull ${GHCR_REPO}:<tag>`.

## Cleanup

```bash
kubectl delete -f argo-events/sensor.yaml
kubectl delete -f argo-events/event-source.yaml
kubectl delete -f argo-events/workflow-trigger-rbac.yaml
kubectl delete -f argo-events/smee-relay-deployment.yaml
kubectl delete secret smee-relay-url -n argo-events
kubectl delete -f argo-workflows/controller-namespace-rbac.yaml
kubectl delete workflowtemplates.argoproj.io/git-build-push -n cicd
kubectl delete -f argocd/root-app-appsets.yaml
minikube delete
```

## Troubleshooting

- **Cannot push to GHCR**: Re-create `ghcr-creds`; ensure PAT has `write:packages`. Confirm the secret exists in `cicd`.
- **Workflow cannot push to GitHub**: Ensure `github-token` contains `username`, `email`, and `token` keys with `repo` scope.
- **Sensor not firing**: Check EventSource/Sensor pods (`kubectl -n argo-events get eventsources,sensors,pods`) and webhook delivery status in GitHub.
- **Workflow builds but skips image**: The `detectchanges` step skips if `apps/my-service/app/` did not change. Modify that path to exercise the full pipeline.
- **Script variables mangled**: Do not run `envsubst` on `argo-workflows/workflow-template.yaml`; it will replace internal shell variables used by the change-detection script.
- **Rollout stuck**: Use `kubectl argo rollouts get rollout ... -w` to see analysis/steps and promote manually with `kubectl argo rollouts promote`.

## References

- [Argo CD](https://argo-cd.readthedocs.io/)
- [Argo Workflows](https://argoproj.github.io/argo-workflows/)
- [Argo Events](https://argoproj.github.io/argo-events/)
- [Argo Rollouts](https://argo-rollouts.readthedocs.io/)
- [Kaniko](https://github.com/GoogleContainerTools/kaniko)

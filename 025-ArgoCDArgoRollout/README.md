# Lab 25 - Argo CD and Argo Rollouts on Minikube

This lab demonstrates three GitOps patterns with a very small NGINX demo application:

- Blue/green deployment with Argo Rollouts
- Canary deployment with manual pause steps
- App-of-apps bootstrap with an Argo CD `Application` and `ApplicationSet`

The manifests in this folder are intentionally simple so you can focus on how Argo CD and Argo Rollouts behave.

## Folder Layout

```text
025-ArgoCDArgoRollout/
|- argocd/
|  |- bluegreen-application.yaml
|  |- canary-application.yaml
|  |- root-application.yaml
|  \- bootstrap/
|     \- environments-applicationset.yaml
|- demo-app/
|  |- bluegreen/
|  |- canary/
|  \- environments/
\- terraform/
```

## What You Will Learn

- How Argo CD syncs plain YAML from Git
- How blue/green preview and promotion work
- How canary pause steps work
- The difference between `Resume` and `Promote-Full` in the Rollouts UI
- Why Argo CD auto-sync only works when the Git source is valid
- How a root `Application` can bootstrap child applications with an `ApplicationSet`

## Prerequisites

- Minikube
- `kubectl`
- `terraform`
- `helm`
- Optional but helpful: `argocd` CLI
- Optional but helpful: `kubectl argo rollouts`

Start Minikube if needed:

```bash
minikube start --kubernetes-version=v1.29.0 --cpus=4 --memory=8192
```

## 1. Install Argo CD and Argo Rollouts

This lab uses Terraform to install both controllers with Helm.

```bash
cd 025-ArgoCDArgoRollout/terraform
terraform init
terraform apply
```

What this creates:

- Argo CD in namespace `argocd`
- Argo Rollouts in namespace `argo-rollouts`

Verify:

```bash
kubectl get pods -n argocd
kubectl get pods -n argo-rollouts
kubectl get crd rollouts.argoproj.io
```

## 2. Open the Argo CD UI

Port-forward the Argo CD server:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Get the initial admin password:

```bash
argocd admin initial-password -n argocd
```

Open:

```text
https://localhost:8080
```

## 3. Blue/Green Demo

Apply the blue/green Argo CD application:

```bash
kubectl apply -f 025-ArgoCDArgoRollout/argocd/bluegreen-application.yaml
```

Verify:

```bash
kubectl get applications -n argocd
kubectl get rollout -n demo-bluegreen
kubectl argo rollouts get rollout demo-app -n demo-bluegreen
```

Open the active and preview services:

```bash
minikube service demo-active -n demo-bluegreen --url
minikube service demo-preview -n demo-bluegreen --url
```

### How the Current Blue/Green Manifest Works

`demo-app/bluegreen/rollout.yaml` currently uses:

- `replicas: 3`
- `activeService: demo-active`
- `previewService: demo-preview`
- `autoPromotionEnabled: false`
- `previewReplicaCount: 2`

This means:

- the new version is first exposed through `demo-preview`
- promotion does not happen automatically
- you promote it manually from the UI or CLI

### Trigger a New Blue/Green Revision

Edit `025-ArgoCDArgoRollout/demo-app/bluegreen/rollout.yaml` and switch the pod template between the two versions.

The simplest way is to change both of these fields:

- `spec.template.metadata.labels.version`
- `spec.template.spec.volumes[0].configMap.name`

Example toggle:

- from `version: v2` and `demo-html-v2`
- to `version: v1` and `demo-html-v1`

Then commit and push the change, or sync from the Argo CD UI if the branch already contains the update.

Observe the rollout:

```bash
kubectl argo rollouts get rollout demo-app -n demo-bluegreen --watch
```

Promote manually:

```bash
kubectl argo rollouts promote demo-app -n demo-bluegreen
```

## 4. Canary Demo

Apply the canary Argo CD application:

```bash
kubectl apply -f 025-ArgoCDArgoRollout/argocd/canary-application.yaml
```

Verify:

```bash
kubectl get applications -n argocd
kubectl get rollout -n demo-canary
kubectl argo rollouts get rollout demo-canary -n demo-canary
```

Open the service:

```bash
minikube service demo-canary -n demo-canary --url
```

### How the Current Canary Manifest Works

`demo-app/canary/rollout.yaml` currently uses these steps:

```yaml
steps:
  - setWeight: 10
  - pause: {}
  - setWeight: 30
  - pause: {}
  - setWeight: 50
  - pause: {}
  - setWeight: 100
```

Important detail: this rollout does not define `trafficRouting`, `stableService`, or `canaryService`.

So the weight is expressed by pod counts, not by a traffic router. With `replicas: 10`, the rollout roughly becomes:

- `10%` = 1 canary pod
- `30%` = 3 canary pods
- `50%` = 5 canary pods
- `100%` = 10 canary pods

### Trigger a New Canary Revision

Edit `025-ArgoCDArgoRollout/demo-app/canary/rollout.yaml` and switch the pod template to the other version.

Change:

- `spec.template.metadata.labels.version`
- `spec.template.spec.volumes[0].configMap.name`

Example toggle:

- from `version: v1` and `demo-html-v1`
- to `version: v2` and `demo-html-v2`

Then let Argo CD sync the change.

Watch the rollout:

```bash
kubectl argo rollouts get rollout demo-canary -n demo-canary --watch
```

### Resume vs Promote-Full

This is the most important learning point in this lab.

- `Resume` moves to the next pause step
- `Promote-Full` skips all remaining pause steps and finishes immediately

So if you want to observe each canary stage, use `Resume` repeatedly.

If you click `Promote-Full`, it is expected that the rollout jumps straight to `100%`.

CLI equivalents:

```bash
kubectl argo rollouts promote demo-canary -n demo-canary
kubectl argo rollouts promote --full demo-canary -n demo-canary
```

## 5. Root Application and ApplicationSet Demo

This lab also includes a root app pattern:

- `argocd/root-application.yaml`
- `argocd/bootstrap/environments-applicationset.yaml`

The root app points Argo CD at `argocd/bootstrap`, and that folder contains an `ApplicationSet` which creates three child apps:

- `demo-dev`
- `demo-intg`
- `demo-prod`

Each child app deploys the environment-specific config from:

- `demo-app/environments/dev`
- `demo-app/environments/intg`
- `demo-app/environments/prod`

### Important GitOps Rule

Argo CD reads from Git, not from your local files.

If you create or modify `root-application.yaml` or anything under `argocd/bootstrap/`, make sure those files are committed and pushed to the branch referenced by the `Application` before you apply the root app.

Otherwise you will get errors like:

```text
app path does not exist
```

### Apply the Root App

After the bootstrap files exist in Git:

```bash
kubectl apply -f 025-ArgoCDArgoRollout/argocd/root-application.yaml
```

Verify:

```bash
kubectl get applications -n argocd
kubectl get applicationsets -n argocd
kubectl get configmaps -n demo-dev
kubectl get configmaps -n demo-intg
kubectl get configmaps -n demo-prod
```

Note: the environment apps in this lab only create a simple `environment-config` `ConfigMap`. They are meant to demonstrate ApplicationSet fan-out, not a full workload deployment.

## 6. Suggested Learning Flow

Work through the lab in this order:

1. Install Argo CD and Argo Rollouts with Terraform.
2. Deploy `demo-bluegreen` and inspect active vs preview services.
3. Change the blue/green rollout from one version to the other and promote manually.
4. Deploy `demo-canary` and trigger a new revision.
5. Use `Resume` to move step-by-step through the canary pauses.
6. Use `Promote-Full` once so you can see how it skips the remaining pauses.
7. Apply the root app and inspect how the `ApplicationSet` creates `demo-dev`, `demo-intg`, and `demo-prod` automatically.

## 7. Troubleshooting

### Application shows `Unknown`

Usually this means Argo CD could not generate manifests from Git.

Check:

- `repoURL` is correct
- `path` exists in the remote branch
- the branch in `targetRevision` actually contains your new files

Useful commands:

```bash
kubectl get app -n argocd demo-canary -o yaml
kubectl describe app -n argocd demo-canary
```

### Auto-sync is enabled, but nothing deploys

Auto-sync only works after Argo CD can build the desired state successfully.

If the app has a `ComparisonError`, fix the Git source problem first.

### Root app says `app path does not exist`

The `argocd/bootstrap` folder is missing from the remote branch Argo CD is reading.

Commit and push the bootstrap files first.

### Canary jumped directly to full rollout

You used `Promote-Full`.

Use `Resume` instead if you want to stop at every pause step.

## 8. Cleanup

Delete the demo apps if you want:

```bash
kubectl delete -f 025-ArgoCDArgoRollout/argocd/bluegreen-application.yaml
kubectl delete -f 025-ArgoCDArgoRollout/argocd/canary-application.yaml
kubectl delete -f 025-ArgoCDArgoRollout/argocd/root-application.yaml
```

Destroy the control plane:

```bash
cd 025-ArgoCDArgoRollout/terraform
terraform destroy
```

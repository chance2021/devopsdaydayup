# Lab22: Deploy a GitHub Actions Runner Scale Set (ARC) on Kubernetes Using Minikube

This Learning Lab teaches you how to deploy **GitHub Actions self-hosted runners** using  
**Actions Runner Controller (ARC)** with **Runner Scale Sets** on a local Kubernetes cluster (Minikube).

The guide is fully hands-on and designed to follow open-source documentation best practices.

---

## 📘 Table of Contents

1. [Architecture Overview](#architecture-overview)  
2. [Prerequisites](#prerequisites)  
3. [Step 1 — Install ARC Scale Set Controller](#step-1--install-arc-scale-set-controller)  
4. [Step 2 — Create GitHub App Secret](#step-2--create-github-app-secret)  
5. [Step 3 — Deploy Runner Scale Set](#step-3--deploy-runner-scale-set)  
6. [Step 4 — Validate Setup](#step-4--validate-setup)  
7. [References](#references)

---

# Architecture Overview

Actions Runner Controller (ARC) allows you to run and scale GitHub Actions runners on Kubernetes.

Key components deployed in this guide:

| Component | Description |
|----------|-------------|
| ARC Controller | Watches GitHub Actions queue and manages runners |
| Runner Scale Set | Managed pool of ephemeral Kubernetes-based runners |
| GitHub App | Authenticates ARC with GitHub |
| Secret | Holds GitHub App credentials |
| Minikube | Local Kubernetes cluster for testing |

---

# Prerequisites

You need the following installed on your machine:

### ✔ Minikube  
Install guide: https://minikube.sigs.k8s.io/docs/start/

Start a cluster:

```bash
minikube start --cpus=4 --memory=8g
```

### Helm
Install guide: https://helm.sh/docs/intro/install/

### kubectl
Install guide: https://kubernetes.io/docs/tasks/tools/

### GitHub App
ARC requires a GitHub App.
Follow the official instructions to create one:
https://github.com/actions/actions-runner-controller/blob/master/docs/getting-started/gh-app.md

Record these values:
	•	App ID
	•	Installation ID
	•	Private Key (.pem file)

⸻

## Step 1 — Install ARC Scale Set Controller

Install the controller into its own namespace:
```bash
helm upgrade --install arc oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --namespace arc-systems \
  --create-namespace
```
Verify pods:
```bash
kubectl get pods -n arc-systems
```
Expected output (example):
```bash
arc-gha-runner-scale-set-controller-xxxxx   Running
````

⸻

## Step 2 — Create GitHub App Secret

Update these variables with your own values:
```bash
INSTALLATION_NAME="arc-runner-set"
```
### Replace with your repo
GITHUB_CONFIG_URL="https://github.com/<your-org-or-user>/<your-repo>"

### Replace placeholders below
GITHUB_APP_ID="<YOUR_GITHUB_APP_ID>"
GITHUB_APP_INSTALLATION_ID="<YOUR_INSTALLATION_ID>"
GITHUB_APP_PRIVATE_KEY_PATH="/path/to/your/private-key.pem"

NAMESPACE="arc-runners"
SECRET_NAME="github-app-secret"

### Create the namespace
```bash
kubectl create namespace ${NAMESPACE}
```
### Create the secret
```bash
kubectl create secret generic ${SECRET_NAME} \
  --namespace=${NAMESPACE} \
  --from-literal=github_app_id=${GITHUB_APP_ID} \
  --from-literal=github_app_installation_id=${GITHUB_APP_INSTALLATION_ID} \
  --from-file=github_app_private_key=${GITHUB_APP_PRIVATE_KEY_PATH}
```
Verify:
```bash
kubectl get secret ${SECRET_NAME} -n ${NAMESPACE}
```

⸻

## Step 3 — Deploy Runner Scale Set

Deploy the scale set into the namespace:
```bash
helm upgrade --install "${INSTALLATION_NAME}" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --set githubConfigUrl="${GITHUB_CONFIG_URL}" \
  --set githubConfigSecret="${SECRET_NAME}"
```
Check pods:
```bash
kubectl get pods -n ${NAMESPACE}
```
You should see something like:
```bash
arc-runner-set-xxxxx
```

⸻

## Step 4 — Validate Setup

1. Validate ARC connected to GitHub

Navigate to:

GitHub → Repository Settings → Actions → Runners

You should see your Runner Scale Set registered.

⸻

2. Trigger a Workflow

Create a workflow:

.github/workflows/test.yml
```yaml
name: Test Runner
on:
  workflow_dispatch:

jobs:
  build:
    runs-on: self-hosted
    steps:
      - run: echo "Runner is working!"
```
Dispatch the workflow in GitHub → Actions.

ARC will:
- Create a Kubernetes runner pod
- Run the job
- Delete the pod after completion

Watch live:
```bash
kubectl get pods -n ${NAMESPACE} -w
```

⸻

## References
- ARC Documentation
https://github.com/actions/actions-runner-controller
- GitHub App for ARC
https://github.com/actions/actions-runner-controller/blob/master/docs/getting-started/gh-app.md
- Runner Scale Set Concepts
https://docs.github.com/en/actions/hosting-your-own-runners/runner-scale-sets

⸻

🎉 You have successfully deployed GitHub Actions Runner Scale Sets on Kubernetes with ARC and Minikube!

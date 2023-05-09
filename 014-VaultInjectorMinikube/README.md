Project Name: Deploy and Use Vault As Agent Sidecar Injector
---

## Project Goal
This lab will guide you through the process of **deploying a Vault Helm chart** in a Kubernetes cluster running on **Minikube**. Once you have the Vault instance up and running, you will create a **deployment** that utilizes **Vault as a sidecar** to **inject secrets** into the pod as a file. This approach ensures that the application running in the pod has access to the necessary secrets without compromising their security by storing them in plain text within the container.

## Table of Contents
- [Project Name: Deploy and Use Vault As Agent Sidecar Injector](#project-name-deploy-and-use-vault-as-agent-sidecar-injector)
- [Project Goal](#project-goal)
- [Table of Contents](#table-of-contents)
- [Prerequisites](#prerequisites)
- [Project Steps](#project-steps)
  - [1. Add Helm Repo](#1-add-helm-repo)
  - [2. Deploy Vault Helm Chart](#2-deploy-vault-helm-chart)
  - [3. Setup Vault](#3-setup-vault)
  - [4. Enable Vault KV Secrets Engine Version 2 and Create a Secret](#4-enable-vault-kv-secrets-engine-version-2-and-create-a-secret)
  - [5. Configure Kubernetes authentication](#5-configure-kubernetes-authentication)
  - [6. Launch an Application](#6-launch-an-application)
  - [7. Update the deployment to Enable the Vault Injection](#7-update-the-deployment-to-enable-the-vault-injection)
- [Post Project](#post-project)
- [Troubleshooting](#troubleshooting)
- [Reference](#reference)

## <a name="prerequisites">Prerequisites</a>
- Ubuntu 20.04 OS (Minimum 2 core CPU/8GB RAM/30GB Disk)
- Docker(see installation guide [here](https://docs.docker.com/get-docker/))
- Minikube (see installation guide [here](https://minikube.sigs.k8s.io/docs/start/))
- Helm (see installation guide [here](https://helm.sh/docs/intro/install/)


## <a name="project_steps">Project Steps</a>

### 1. Add Helm Repo
To use the Helm chart, **add the Hashicorp helm repository** and check that you have access to the chart:
```
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update
helm search repo hashicorp/vault
```
### 2. Deploy Vault Helm Chart
**Install** the latest release of the Vault Helm chart with below command:
```
helm install vault hashicorp/vault -f values.yaml
```

### 3. Setup Vault
a. **Initiate** vault
```
vault operator init
```
**Note:** Make a note of the output. This is the only time ever you see those **unseal keys** and **root token**. If you lose it, you won't be able to seal vault any more.

b. **Unsealing** the vault </br>
Type `vault operator unseal <unseal key>`. The unseal keys are from previous output. You will need at lease **3 keys** to unseal the vault. </br>

When the value of  `Sealed` changes to **false**, the Vault is unsealed. You should see below similar output once it is unsealed

```
Unseal Key (will be hidden): 
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            5
Threshold               3
Version                 1.12.1
Build Date              2022-10-27T12:32:05Z
Storage Type            raft
Cluster Name            vault-cluster-403fc7a0
Cluster ID              772cef22-77d2-11bb-f16b-7ef69d85ac0e
HA Enabled              true
HA Cluster              n/a
HA Mode                 standby
Active Node Address     <none>
Raft Committed Index    31
Raft Applied Index      31
```
c. Sign in to Vault with **root** user </br>
Type `vault login` and enter the `<Initial Root Token>` retrieving from previous output
```
/ # vault login
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                hvs.KtwbjaZwYBV4BPohe6Vi48BH
token_accessor       aVZzcPF3oCCIqGLzqoxvgLLC
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
```
### 4. Enable Vault KV Secrets Engine Version 2 and Create a Secret
> Refer to <https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2>
```
vault secrets enable -path=internal-app kv-v2
vault kv put internal-app/database/config username=root password=changeme
```
You can **read** the data by running this:
```
vault kv get internal-app/database/config
```
Then you should be able to see below output
```
====== Data ======
Key         Value
---         -----
password    changeme
username    root
```
### 5. Configure Kubernetes authentication
Stay on the Vault pod and configure the kuberentes authentication </br>
a. **Enable** the Kuberetes atuh in the Vault
```
vault auth enable kubernetes
```
b. Create a **role** for the service account which is used by the deployment
```
vault write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"

vault policy write internal-app - <<EOF
path "internal-app/data/database/config" {
  capabilities = ["read"]
}
EOF
```
> Note: Since version 2 kv has prefixed `data/`, your secret path will be `internal-app/data/database/config`, instead of `internal-app/database/config`
c. Associate the role created above to the **service account**
```
 vault write auth/kubernetes/role/internal-app \
    bound_service_account_names=app-sa \
    bound_service_account_namespaces=default \
    policies=internal-app \
    ttl=24h
```   
### 6. Launch an Application
Apply the `app-deployment.yaml` to deploy a deployment:
```
kubectl apply -f app-deployment.yaml
```
Wait for the pods are **ready**
```
kubectl wait pods -n default -l app=nginx --for condition=Ready --timeout=1000s
```

### 7. Update the deployment to Enable the Vault Injection
To enable the vault to inject secrets into a deployment's pods, you need to patch the  code in `patch-app-deployment.yaml` into the **annotation** section of the deployment file:
```
kubectl patch deployment app-deployment --patch "$(cat patch-app-deployment.yaml)"
```
Once the vault sidecar is successfully injected into the app deployment's pod, you should be able to verify its presence by inspecting the pod's configuration. 

```
kubectl exec $(kubectl get pod|grep app-deployment|awk '{print $1}') -- cat /vault/secrets/database-config.txt
```

## <a name="post_project">Post Project</a>
**Delete** Minikube
```
minikube stop
```

## <a name="troubleshooting">Troubleshooting</a>

## <a name="reference">Reference</a>
- [Vault Deployment via Helm Chart](https://developer.hashicorp.com/vault/docs/platform/k8s/helm)
- [Agent Sidecar Injector](https://developer.hashicorp.com/vault/docs/platform/k8s/injector)
- [K8s Sidecar Tutorial](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-sidecar)
- [Vault Kubernetes Auth Method](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
# Project Name: Vault Jenkins Pipeline 

# Project Goal

# Table of Contents
1. [Prerequisites](#prerequisites)
2. [Project Steps](#project_steps)
3. [Post Project](#post_project)
4. [Troubleshooting](#troubleshooting)
5. [Reference](#reference)

# <a name="prerequisites">Prerequisites</a>
- Ubuntu 20.04 OS (Minimum 2 core CPU/8GB RAM/30GB Disk)
- Docker(see installation guide [here](https://docs.docker.com/get-docker/))
- Docker Compose(see installation guide [here](https://docs.docker.com/compose/install/))

# <a name="project_steps">Project Steps</a>

## 1. Initiate Vault
### a. Login to Vault container
```bash
docker exec -it $(docker ps -f name=vault_1 -q) sh
```
### b. Create a `config.hcl` file
> Refer to https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-deploy
```
cat > config.hcl <<EOF
storage "raft" {
  path    = "./vault/data"
  node_id = "node1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = "true"
  #tls_cert_file = "/vault/vault.crt"
  #tls_key_file  = "/vault/vault.key"
  #tls_client_ca_file = "/vault/vault.ca"
}

api_addr = "http://127.0.0.1:8200"
cluster_addr = "https://127.0.0.1:8201"
ui = true
disable_mlock = true
max_lease_ttl = "8784h"
default_lease_ttl = "8784h"

EOF
```

### c. Starting the server
```
mkdir -p ./vault/data
vault server -config=config.hcl
```

### d. Initializing the Vault
Open another terminal and login to the vault docker container again
```
docker exec -it $(docker ps -f name=vault_1 -q) sh
export VAULT_ADDR='http://127.0.0.1:8200'
vault operator init
```
Make a note of the output. This is the only time ever you see those unseal keys and root token. If you lose it, you won't be able to seal vault any more.

### e. Unsealing the vault
Type `vault operator unseal` and pick 3 unseal keys from above output to unseal the vault.

When the value for Sealed changes to 'false', the Vault is unsealed.

For example:
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
### f. Login to vault with root 
Type `vault login` and enter the `Initial Root Token` from previous output
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

## 2. Enable Vault KV Secrets Engine Version 2
> Refer to https://developer.hashicorp.com/vault/docs/secrets/kv/kv-v2
```
vault secrets enable -version=2 kv-v2

vault kv put -mount=kv-v2 devops-secret username=root password=changeme

```
You can read the data by running this:
```
vault kv get -mount=kv-v2 devops-secret
```
Then you should be able to see below output
```
====== Data ======
Key         Value
---         -----
password    changeme
username    root

```
> Note: Since version 2 kv has prefixed `data/`, your secret path will be `kv-v2/data/devops-secret`, instead of `kv-v2/devops-secret`



## 3. Write a Vault Policy and create a token
```
cat > policy.hcl  <<EOF
path "kv-v2/data/devops-secret/*" {
  capabilities = ["create", "update","read"]
}
EOF
vault policy write first-policy policy.hcl
vault policy list
vault policy read first-policy
export VAULT_TOKEN="$(vault token create -field token -policy=first-policy)"
echo $VAULT_TOKEN
vault token lookup | grep policies

# Write a secret with the new token
vault kv put -mount=kv-v2 devops-secret/team-1 username2=root2 password2=changemeagain
vault kv get -mount=kv-v2 devops-secret/team-1

# Enable approle
vault auth enable approle
vault write auth/approle/role/first-role \
    secret_id_ttl=10000m \
    token_num_uses=10 \
    token_ttl=20000m \
    token_max_ttl=30000m \
    secret_id_num_uses=40 \
    token_policies=first-policy

# Check the role id
vault read -field=role_id auth/approle/role/my-role/role-id
export ROLE_ID="$(vault read -field=role_id auth/approle/role/first-role/role-id)"
echo $ROLE_ID

# Check the secret id
export SECRET_ID="$(vault write -f -field=secret_id auth/approle/role/first-role/secret-id)"
echo $SECRET_ID

# Authenticate to AppRole
vault write auth/approle/login role_id="$ROLE_ID" secret_id="$SECRET_ID"

# You should be able to see the token in `token` field
```

## 4. Install necessary Jenkins pluglin
Login to your Jenkins website and go to **"Manage Jenkins"** -> **"Plugin Manager"** and head to "Available" tab. Install following plugins:
- credentials
- HashiCorp Vault
- Hashicorp Vault Pipeline
- pipeline
- git
## 5. Add the role id/secret id in Jenkins
> Refer to https://plugins.jenkins.io/hashicorp-vault-plugin/#plugin-content-vault-app-role-credential
Login to your Jenkins website and go to **"Manage Jenkins"** -> **"Manage Credentials"** ->  **"System"** -> **"Global credentials (unrestricted)"** -> Click **"Add Credentials"** and you should fill out the page below below selection:
**Kind:** Vault App Role Credential
**Scope:** Global (Jenkins,nodes,items,all child items,etc)
**Role ID:** <ROLE_ID from previous step>
**Secret ID:** <SECRET_ID from previous step>
**Path:** approle
**Namespace:** <Leave it blank>
**ID:** <the credential id you will refer within Jenkins Pipeline. i.g. vault-appi-role>
**Description:** Vault: AppRole Authentication

## 6. Add github credential in Jenkins
Login to your Jenkins website and go to **"Manage Jenkins"** -> **"Manage Credentials"** ->  **"System"** -> **"Global credentials (unrestricted)"** -> Click **"Add Credentials"** and you should fill out the page below below selection:

# <a name="post_project">Post Project</a>

# <a name="troubleshooting">Troubleshooting</a>
## Issue 1: Access denied to Vault Secrets at 'kv-v2/devops-secret/team-1'
**Solution:**
If you see an information in the log like `[INFO]  expiration: revoked lease`, that means your secret is expired and you may need to renew it by running below command:
```
vault write -f -field=secret_id auth/approle/role/first-role/secret-id
```
Then, you can update your new secret in corresponding Jenkins credential.

Sometime this may be a general error which indicates something wrong in your Jenkinsfile configuration. One thing worth to mention is that, in the Jenkinsfile, `secrets` should use `engineVersion:2`, while `configuration` should use engineVersion:1`. This is because `engineVersion:2` in `secrets` is referring to kv version, which is version 2 in our lab. However the `engineVersion` in `configuration` is referringto the API version, which should be version 1. You can tell this in below API call:
```
curl  --header "X-Vault-Token: hvs.CAESI..."     http://vault:8200/v1/kv-v2/devops-secret/team-1
```

You can see `http://vault:8200/v1` which means the API version is `1`. This is referring to the `engineVersion` in `configuration`. Also, my secret actual path is `kv-v2/data/devops-secret/team-1`, `/data` is just prefix for kv 2 secret path, so that is why `engineVersion` is `2` in `secret` as it is reffering to the kv version, not API version. 


# <a name="reference">Reference</a>
[Vault Getting Started Deploy](https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-deploy)
[Vault Store The Google API Key](https://developer.hashicorp.com/vault/tutorials/secrets-management/static-secrets#store-the-google-api-key)

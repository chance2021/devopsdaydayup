# Lab 5 — Jenkins Pipeline with HashiCorp Vault (AppRole)

Integrate Vault secrets into a Jenkins pipeline using the Vault AppRole auth method. You will initialize and unseal Vault, create an AppRole with a policy-scoped token, register it in Jenkins, and consume secrets inside a pipeline.

> Use placeholders for all secrets (e.g., `YOUR_VAULT_ROLE_ID`, `YOUR_GITHUB_TOKEN`). Never commit unseal keys or root tokens.

## Prerequisites

- Ubuntu 20.04 host (>= 2 vCPU, 8 GB RAM)
- Docker and Docker Compose
- Jenkins accessible at `http://localhost:8080` (from this lab’s docker-compose)

## Setup

1) Start Vault and Jenkins

```bash
docker-compose up -d
```

2) Initialize and unseal Vault

```bash
docker exec -it $(docker ps -f name=vault_1 -q) sh
export VAULT_ADDR='http://127.0.0.1:8200'
vault operator init          # record unseal keys and root token securely
vault operator unseal <KEY1>
vault operator unseal <KEY2>
vault operator unseal <KEY3>
vault login <ROOT_TOKEN>
```

3) Enable KV v2 and create a sample secret

```bash
vault secrets enable -version=2 kv-v2
vault kv put -mount=kv-v2 devops-secret username=root password=changeme
```

4) Create policy + AppRole and fetch credentials

```bash
cat > policy.hcl <<'EOF'
path "kv-v2/data/devops-secret/*" {
  capabilities = ["create","update","read"]
}
EOF
vault policy write first-policy policy.hcl
vault auth enable approle
vault write auth/approle/role/first-role \
  secret_id_ttl=10000m \
  token_num_uses=10 \
  token_ttl=20000m \
  token_max_ttl=30000m \
  secret_id_num_uses=40 \
  token_policies=first-policy

ROLE_ID=$(vault read -field=role_id auth/approle/role/first-role/role-id)
SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/first-role/secret-id)
echo "ROLE_ID=${ROLE_ID}"
echo "SECRET_ID=${SECRET_ID}"
exit
```

5) Configure Jenkins credentials

- Go to **Manage Jenkins → Manage Credentials → System → Global credentials**.
- Add **Vault App Role Credential**:
  - Kind: Vault App Role Credential
  - Scope: Global
  - Role ID: `ROLE_ID`
  - Secret ID: `SECRET_ID`
  - Path: `approle`
  - ID: `vault-app-role`
- Add **Username with password** for GitHub:
  - Username: your GitHub username
  - Password: your GitHub personal access token
  - ID: `github-token`

6) Run the pipeline

- Open the Jenkins job that uses `005-VaultJenkinsCICD/Jenkinsfile` (configure SCM path and credentials similar to Lab 2).
- Build the job. It should authenticate to Vault via AppRole and read secrets from `kv-v2/devops-secret`.

## Validation

- Jenkins build succeeds and logs show Vault secrets retrieved via AppRole.
- `vault kv get -mount=kv-v2 devops-secret` returns the stored values.

## Cleanup

```bash
docker-compose down -v
```

## Troubleshooting

- **Unseal required**: Ensure Vault is unsealed before running the pipeline.
- **Permission denied**: Confirm the policy path matches `kv-v2/data/devops-secret/*` and that the AppRole uses that policy.
- **Jenkins cannot reach Vault**: Check `VAULT_ADDR` in Jenkins global config (if using the Vault plugin) and network reachability from the Jenkins container to Vault (`curl http://vault:8200/v1/sys/health`).

## References

- https://developer.hashicorp.com/vault/docs/auth/approle
- https://plugins.jenkins.io/hashicorp-vault-plugin/

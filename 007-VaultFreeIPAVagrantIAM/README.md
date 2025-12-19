# Lab 7 — Vault SSH Certificates with FreeIPA Users and Vagrant

Issue short-lived SSH certificates from Vault for FreeIPA users to log into specific accounts on a Vagrant VM. FreeIPA provides LDAP identities; Vault signs SSH certs; the VM trusts Vault’s CA.

> Replace any credentials (`bindpass`, hostnames) with your own safe values. Do not commit unseal keys, root tokens, or bind passwords.

## Prerequisites

- Ubuntu 20.04 host (>= 2 vCPU, 8 GB RAM)
- Docker and Docker Compose
- Vagrant and VirtualBox with VT-x/AMD-V enabled
- A FreeIPA instance reachable at `ipa.devopsdaydayup.org` (adjust if different)

## Architecture

- Vault issues SSH user certificates via the `ssh-client-signer` secrets engine.
- Vault authenticates users against FreeIPA via LDAP.
- Vagrant VM SSH daemon trusts Vault’s SSH CA and maps principals to system accounts.

## Setup

1) Start Vault

```bash
docker-compose up -d
docker exec -it $(docker ps -f name=vault_1 -q) sh
export VAULT_ADDR='http://127.0.0.1:8200'
vault operator init         # record unseal keys and root token securely
vault operator unseal <KEY1>
vault operator unseal <KEY2>
vault operator unseal <KEY3>
vault login <ROOT_TOKEN>
```

2) Enable SSH client signer and generate CA key

```bash
vault secrets enable -path=ssh-client-signer ssh
vault write ssh-client-signer/config/ca generate_signing_key=true
```

Copy the **SSH CA public key** from the output; you’ll add it to the Vagrant VM later.

3) Create roles and policies for admin/user

```bash
vault write ssh-client-signer/roles/admin-role -<<'EOH'
{
 "allow_user_certificates": true,
 "allowed_users": "admin",
 "default_extensions": [{ "permit-pty": "" }],
 "key_type": "ca",
 "default_user": "admin",
 "ttl": "3m0s"
}
EOH

vault write ssh-client-signer/roles/user-role -<<'EOH'
{
 "allow_user_certificates": true,
 "allowed_users": "user",
 "default_extensions": [{ "permit-pty": "" }],
 "key_type": "ca",
 "default_user": "user",
 "ttl": "3m0s"
}
EOH

vault policy write admin-policy - <<'EOF'
path "ssh-client-signer/roles/*" {
  capabilities = ["list"]
}
path "ssh-client-signer/sign/admin-role" {
  capabilities = ["create","update"]
}
EOF

vault policy write user-policy - <<'EOF'
path "ssh-client-signer/roles/*" {
  capabilities = ["list"]
}
path "ssh-client-signer/sign/user-role" {
  capabilities = ["create","update"]
}
EOF
```

4) Enable LDAP auth (FreeIPA) and map policies

```bash
vault auth enable ldap

vault write auth/ldap/config \
  url="ldaps://ipa.devopsdaydayup.org" \
  userattr="uid" \
  userdn="cn=users,cn=accounts,dc=devopsdaydayup,dc=org" \
  groupdn="cn=groups,cn=accounts,dc=devopsdaydayup,dc=org" \
  binddn="uid=admin,cn=users,cn=accounts,dc=devopsdaydayup,dc=org" \
  bindpass="admin123" \ 
  insecure_tls=true \
  discoverdn=true

vault write auth/ldap/users/devops policies=admin-policy
vault write auth/ldap/users/bob policies=user-policy
```

5) Configure SSH on the Vagrant VM to trust the CA

```bash
vagrant up
vagrant ssh
echo 'ssh-rsa <PASTE_SSH_CA_PUBLIC_KEY>' | sudo tee /etc/ssh/trusted-CA.pem

sudo mkdir -p /etc/ssh/auth_principals
echo 'admin' | sudo tee /etc/ssh/auth_principals/admin
echo 'user' | sudo tee /etc/ssh/auth_principals/app-user

sudo tee -a /etc/ssh/ssh_config > /dev/null <<'EOF'
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
ChallengeResponseAuthentication no
PasswordAuthentication no
TrustedUserCAKeys /etc/ssh/trusted-CA.pem
EOF

sudo service ssh restart
```

## Validation

- Authenticate with LDAP and sign an SSH key:
  ```bash
  vault login -method=ldap username=devops password=<DEVOPS_PASSWORD>
  ssh-keygen -t rsa -f /tmp/devops -N ""
  vault write -field=signed_key ssh-client-signer/sign/admin-role public_key=@/tmp/devops.pub > /tmp/devops-cert.pub
  ssh -i /tmp/devops -o "CertificateFile=/tmp/devops-cert.pub" admin@<VM_IP> hostname
  ```
- Repeat for `bob` using `user-role` and verify login as `app-user`.

## Cleanup

```bash
docker-compose down -v
vagrant destroy -f
```

## Troubleshooting

- **LDAP bind fails**: Verify `binddn`/`bindpass` and reachability to FreeIPA over LDAPS.
- **SSH login denied**: Ensure `TrustedUserCAKeys` is set and principals files match `admin`/`app-user`.
- **Cert expired**: TTL is 3 minutes; reissue the certificate before retrying SSH.

## References

- https://developer.hashicorp.com/vault/docs/secrets/ssh/signed-ssh-certificates
- https://developer.hashicorp.com/vault/docs/auth/ldap

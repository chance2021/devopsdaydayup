# Project Name: Managing SSH Access with Vault

# Project Goal
In this article, you will experince how to get a **signed SSH certificate** from **Vault** for a **LDAP** user in order to login a Vagrant VM via SSH.

# Project Scenario
You have a running **FreeIPA** system which has two users: `devops` and `bob`. `devops` is a system admin and should have all administrator priviliages (i.g. `sudo` group), while `bob` is just a regular user. In your **Vagrant** VM, there are two accounts. One is `admin`, which is `sudo` user, and another one is `app-user`, which is regular user. The goal is that the `devops` user in FreeIPA should be able to login the Vagrant VM in `admin` account, and `bob` user in FreeIPA should login as `app-user` in Vagrant VM. The SSH certificates should only last for 3 mins.

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
- Vagrant(see installation guide [here](https://developer.hashicorp.com/vagrant/downloads))
- Vbox(see installation guide [here](https://www.virtualbox.org/wiki/Linux_Downloads))

# <a name="project_steps">Project Steps</a>

## 1. Initiate Vault
a. **Initializing** the Vault
```bash
docker-compose up -d
docker exec -it $(docker ps -f name=vault_1 -q) sh
export VAULT_ADDR='http://127.0.0.1:8200'
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
## 2. Enable **ssh-client-signer** Engine in Vault
```bash
vault secrets enable -path=ssh-client-signer ssh
vault write ssh-client-signer/config/ca generate_signing_key=true
```
You should get **a SSH CA public key** in the output, which will be used later on the Vagrant VM host configurations. **Make a note of the key**.

## 3. Create Vault **roles** for signing client SSH keys
You are going to create two roles in Vault. One is `admin-role` and another one is `user-role`. </br>
**admin-role**
```
vault write ssh-client-signer/roles/admin-role -<<EOH
{
 "allow_user_certificates": true,
 "allowed_users": "admin",
 "allowed_extensions": "",
 "default_extensions": [
 {
 "permit-pty": ""
 }
 ],
 "key_type": "ca",
 "default_user": "admin",
 "ttl": "3m0s"
}
EOH
```
**user-role**
```
vault write ssh-client-signer/roles/user-role -<<EOH
{
 "allow_user_certificates": true,
 "allowed_users": "user",
 "allowed_extensions": "",
 "default_extensions": [
 {
 "permit-pty": ""
 }
 ],
 "key_type": "ca",
 "default_user": "user",
 "ttl": "3m0s"
}
EOH
```

## 4. Create Vault **Policies**
You are going to create policies for cooresponding roles created above.</br>
**admin-policy**
```
vault policy write admin-policy - << EOF
# List available SSH roles
path "ssh-client-signer/roles/*" {
 capabilities = ["list"]
}
# Allow access to SSH role
path "ssh-client-signer/sign/admin-role" {
 capabilities = ["create","update"]
}
EOF
```
**user-policy**
```
vault policy write user-policy - << EOF
# List available SSH roles
path "ssh-client-signer/roles/*" {
 capabilities = ["list"]
}
# Allow access to SSH role
path "ssh-client-signer/sign/user-role" {
 capabilities = ["create","update"]
}
EOF
```

## 5. Enable **LDAP Engine** and configure the FreeLDAP setting in Vault
```
vault auth enable ldap

vault write auth/ldap/config \
    url="ldaps://ipa.devopsdaydayup.org" \
    userattr="uid" \
    userdn="cn=users,cn=accounts,dc=devopsdaydayup,dc=org" \
    groupdn="cn=groups,cn=accounts,dc=devopsdaydayup,dc=org" \
    groupfilter="" \
    binddn="uid=admin,cn=users,cn=accounts,dc=devopsdaydayup,dc=org" \
    bindpass="admin123" \ <--- This is the password for FreeIPA admin user
    insecure_tls=true \
    certificate="" \
    starttls=false \
    upndomain="" \
    discoverdn=true

# Attach the policies to the roles
vault write auth/ldap/users/devops  policies=admin-policy
vault write auth/ldap/users/bob  policies=user-policy
```
## 6. Configure the SSH Setting in the **Vagrant VM** Host

```bash
vagrant up
vagrant ssh 
echo 'ssh-rsa <TRUSTED CA Key>' |sudo tee /etc/ssh/trusted-CA.pem
> Note: The trusted CA key was generated in previous step 2

cd /etc/ssh
sudo mkdir auth_principals/
cd auth_principals/

sudo echo 'admin' |sudo tee admin
sudo echo 'user' |sudo tee app-user

sudo tee -a /etc/ssh/ssh_config > /dev/null <<EOF
    AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u
    ChallengeResponseAuthentication no
    PasswordAuthentication no
    TrustedUserCAKeys /etc/ssh/trusted-CA.pem
EOF

sudo service ssh restart
```

## 7. Create LDAP users in **FreeIPA**
a. In your **local host**, update `/etc/hosts` by adding this entry: `0.0.0.0 ipa.devopsdaydayup.org` </br>
b. Open the **browser** and go to The **FreeIPA portal** (https://ipa.devopsdaydayup.org). Type the username as `admin` and the password as `admin123` (**Note**: they are defined in `.env` file)</br>
c. Click **"Add"** in **"Users"** page and enter below info:</br>
**User login:** devops </br>
**First Name:** devops</br>
**Last Name:** devops</br>
**New Password:** *(Type any password you want,i.g. admin123)*</br>
**Verify Password:** *(Type any password you want)*</br>
d. Click **"Add and Add Another"** to create another user `user`:
**User login:** bob </br>
**First Name:** bob</br>
**Last Name:** li</br>
**New Password:** *(Type any password you want, i.g. user123)*</br>
**Verify Password:** *(Type any password you want)*</br>
Click **"Add"** to finish the creation. You should be able to see two users appearing in the **"Active users"** page.

## 8. Client Configurations to login as admin user
Now you are all set in server's end. In order to have a user to login to the Vagrant Host, the user needs to **create an SSH key pair** and then send the SSH **public key** to **Vault** to be **signed** by its SSH CA. The **signed SSH certificate** will then be used to connect to the target host.

Let's go through what that may look like for FreeIPA user `devops`, who is a system administrator.

a. In your **local host**, create a SSH key pair
```
ssh-keygen -b 2048 -t rsa -f ~/.ssh/admin-key
> Note: Just leave it blank and press Enter
ssh-add ~/.ssh/admin-key
```
b. Login to **Vault** via **LDAP** credential by posting to vault's API
```
# Note: This is the password for `admin` user in the Vagrant VM
cat > payload.json<<EOF
{
  "password": "admin123"  
}
EOF

sudo apt install jq -y
VAULT_ADDRESS=0.0.0.0
VAULT_TOKEN=$(curl -s \
    --request POST \
    --data @payload.json \
    http://$VAULT_ADDRESS:8200/v1/auth/ldap/login/devops |jq .auth.client_token|tr -d '"')
> Note: You can see the token in `client_token` field

echo $VAULT_TOKEN


cat > public-key.json <<EOF
{
  "public_key": "$(cat ~/.ssh/admin-key.pub)",
  "valid_principals": "admin"
}
EOF
> Note: You can retrieve the public key by running the following command: `cat ~/.ssh/admin-key.pub`

SIGNED_KEY=$(curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @public-key.json \
    http://$VAULT_ADDRESS:8200/v1/ssh-client-signer/sign/admin-role | jq .data.signed_key|tr -d '"'|tr -d '\n')
echo $SIGNED_KEY
SIGNED_KEY=${SIGNED_KEY::-2}
echo $SIGNED_KEY > admin-signed-key.pub

ssh -i admin-signed-key.pub  admin@192.168.33.10

# Wait for 3 mins and try again, you will see `Permission denied` error, as the certificate has expired
```

> Note: If you are in Vault container trying to login the Vagrant VM, you can use below `vault` commands as well: 
```
vault login -method=ldap username=devops
vault write -field=signed_key ssh-client-signer/sign/admin-role \
    public_key=@$HOME/.ssh/admin-key.pub valid_principals=admin > ~/.ssh/admin-signed-key.pub
ssh-keygen -Lf admin-signed-key.pub
ssh -i ~/.ssh/admin-signed-key.pub admin@192.168.33.10
```
You can now ssh to the Vagrant VM via the signed ssh key. You can type `whoami` to see which user account you are logging with.</br>
`exit` the Vagrant host and wait for 3 mins, and then you can try to login again with the same command above, you will find the permission is denied, as the SSH cert is expired
```
$ ssh -i admin-signed-key.pub -o IdentitiesOnly=yes admin@192.168.33.10
admin@192.168.33.10: Permission denied (publickey).

```

## 9. Client Configurations to login as non-admin user
Now we are going to login as non-admin user. In FreeIPA, it is `bob`. And in the Vagrant VM, it is `app-user`. We will be authenticated as `bob` from FreeIPA in Vault and then create a signed ssh key to login the Vagrant VM as `app-user`.
a. In your **local host**, create a SSH key pair
```
ssh-keygen -b 2048 -t rsa -f ~/.ssh/bob-key
> Note: Just leave it blank and press Enter
ssh-add ~/.ssh/bob-key
```
b. Login to **Vault** via **LDAP** credential by posting to vault's API
```
# Note: Below is the password for `user` user in the Vagrant VM
cat > payload.json<<EOF
{
  "password": "user123"
}
EOF

sudo apt install jq -y
VAULT_ADDRESS=0.0.0.0
VAULT_TOKEN=$(curl -s \
    --request POST \
    --data @payload.json \
    http://$VAULT_ADDRESS:8200/v1/auth/ldap/login/bob |jq .auth.client_token|tr -d '"')
> Note: You can see the token in `client_token` field

echo $VAULT_TOKEN


cat > public-key.json <<EOF
{
  "public_key": "$(cat ~/.ssh/bob-key.pub)",
  "valid_principals": "user"
}
EOF
> Note: You can retrieve the public key by running the following command: `cat ~/.ssh/bob-key.pub`

SIGNED_KEY=$(curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @public-key.json \
    http://$VAULT_ADDRESS:8200/v1/ssh-client-signer/sign/user-role | jq .data.signed_key|tr -d '"'|tr -d '\n')
echo $SIGNED_KEY
SIGNED_KEY=${SIGNED_KEY::-2}
echo $SIGNED_KEY > bob-signed-key.pub

ssh -i bob-signed-key.pub -i ~/.ssh/bob-key  app-user@192.168.33.10

# Wait for 3 mins and try again, you will see `Permission denied` error, as the certificate has expired
```

> Note: If you are in Vault container trying to login the Vagrant VM, you can use below `vault` commands as well: 
```
vault login -method=ldap username=bob
vault write -field=signed_key ssh-client-signer/sign/user-role \
    public_key=@$HOME/.ssh/user-key.pub valid_principals=user > ~/.ssh/user-signed-key.pub
ssh-keygen -Lf user-signed-key.pub
ssh -i ~/.ssh/user-signed-key.pub user@192.168.33.10
```
You can now ssh to the Vagrant VM via the signed ssh key. You can type `whoami` to see which user account you are logging with.
# <a name="post_project">Post Project</a>
Stop docker-compose
```
docker-compose down -v
```
Stop Vagrant
```
vagrant destroy
```

# <a name="troubleshooting">Troubleshooting</a>
## Issue 1: Port 53 error


**Solution:**
Run below commands to stop `systemd-resolved`
```
sudo systemctl disable systemd-resolved
sudo systemctl stop systemd-resolved
```
Add below entry to `/etc/resolv.conf`
```
nameserver 8.8.8.8 
nameserver 8.8.4.4
```
## Issue 2: Could not open a connection to your authentication agent
When running `ssh-add ~/.ssh/id_rsa.pub`, showing below error:
```
Could not open a connection to your authentication agent.
```
**Solution:**
Run the command:
```
apk add openssh
eval `ssh-agent -s`
ssh-add
```
ref: https://stackoverflow.com/questions/17846529/could-not-open-a-connection-to-your-authentication-agent

## Issue 3: SSH Too Many Authentication Failures
While trying to connect to remote systems via SSH, encountering the error "Received disconnect from x.x.x.x port 22:2: Too many authentication failures"

**Solution:**
To fix this issue, you just need to add `IdentitiesOnly` with a value of yes.
```
ssh -i user-signed-key.pub  -o IdentitiesOnly=yes user@192.168.33.10
```
ref: https://www.tecmint.com/fix-ssh-too-many-authentication-failures-error/

# <a name="reference">Reference</a>
[LDAP Integrate into Vault](https://developer.hashicorp.com/vault/docs/auth/ldap)
[(Official)Managing SSH Access At Scale With Hashicorp Vault](https://www.hashicorp.com/blog/managing-ssh-access-at-scale-with-hashicorp-vault)
[Manaing SSH Access with Harhicorp Vault](https://www.civo.com/learn/managing-ssh-access-with-hashicorp-vault)
[Signed SSH Certificates](https://developer.hashicorp.com/vault/docs/secrets/ssh/signed-ssh-certificates)
[SSH API](https://developer.hashicorp.com/vault/api-docs/secret/ssh)
[FreeIPA Docker Hub](https://hub.docker.com/r/freeipa/freeipa-server/)

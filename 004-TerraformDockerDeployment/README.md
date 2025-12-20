# Lab 4 — Deploy Docker Container with Terraform

Use Terraform to build and run a Docker container while storing state remotely in a self-hosted GitLab instance.

> Replace domains, tokens, and passwords with your own (for example `gitlab.example.com`, `YOUR_GITLAB_TOKEN`). Never commit real secrets.

## Prerequisites

- Ubuntu 20.04 host (>= 2 vCPU, 8 GB RAM)
- Docker, Docker Compose
- Terraform CLI
- Hostnames mapped in `/etc/hosts` for GitLab (e.g., `gitlab.example.com`, `registry.gitlab.example.com`)

## Architecture

- Docker Compose starts GitLab (with registry) to host Terraform state.
- Terraform uses the HTTP backend pointing at the GitLab project state endpoint.
- Terraform builds and runs a sample Docker container locally.

## Setup

1) Start GitLab (state backend)

```bash
git clone https://github.com/chance2021/devopsdaydayup.git
cd devopsdaydayup/004-TerraformDockerDeployment
docker-compose up -d
```

Retrieve the initial root password if needed:
```bash
sudo docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

2) Map hostnames

Add to `/etc/hosts` (replace with your IP/domain):
```
<HOST_IP> gitlab.example.com registry.gitlab.example.com
```

3) Regenerate GitLab certificates (server + registry)

```bash
docker exec -it gitlab bash
mkdir -p /etc/gitlab/ssl_backup
mv /etc/gitlab/ssl/* /etc/gitlab/ssl_backup
cd /etc/gitlab/ssl
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 365 -key ca.key -subj "/C=US/ST=CA/L=SF/O=Example/CN=Example Root CA" -out ca.crt

export YOUR_GITLAB_DOMAIN=example20221106.com
openssl req -newkey rsa:2048 -nodes -keyout gitlab.$YOUR_GITLAB_DOMAIN.key \
  -subj "/C=US/ST=CA/L=SF/O=Example/CN=*.$YOUR_GITLAB_DOMAIN" \
  -out gitlab.$YOUR_GITLAB_DOMAIN.csr
openssl x509 -req -extfile <(printf "subjectAltName=DNS:$YOUR_GITLAB_DOMAIN,DNS:gitlab.$YOUR_GITLAB_DOMAIN") \
  -days 365 -in gitlab.$YOUR_GITLAB_DOMAIN.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out gitlab.$YOUR_GITLAB_DOMAIN.crt

openssl req -newkey rsa:2048 -nodes -keyout registry.gitlab.$YOUR_GITLAB_DOMAIN.key \
  -subj "/C=US/ST=CA/L=SF/O=Example/CN=*.$YOUR_GITLAB_DOMAIN" \
  -out registry.gitlab.$YOUR_GITLAB_DOMAIN.csr
openssl x509 -req -extfile <(printf "subjectAltName=DNS:$YOUR_GITLAB_DOMAIN,DNS:gitlab.$YOUR_GITLAB_DOMAIN,DNS:registry.gitlab.$YOUR_GITLAB_DOMAIN") \
  -days 365 -in registry.gitlab.$YOUR_GITLAB_DOMAIN.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out registry.gitlab.$YOUR_GITLAB_DOMAIN.crt

gitlab-ctl reconfigure
gitlab-ctl restart
exit
```

4) Trust the GitLab certificate on your host

```bash
export YOUR_GITLAB_DOMAIN=example20221106.com
sudo docker cp gitlab:/etc/gitlab/ssl/gitlab.$YOUR_GITLAB_DOMAIN.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

5) Create a GitLab project and token

- In GitLab, **New project → Create blank project** (Public is fine for the lab).
- Generate a Personal Access Token with scopes `api`, `read_api`, `read_repository`, `write_repository`.
- Note the **Project ID** (Settings → General) and the token.

6) Configure Terraform backend

Edit `config/test/config.tfbackend` with your values:
- `PROJECT_ID`: from GitLab project
- `TF_USERNAME`: e.g., `root`
- `TF_PASSWORD`: your GitLab personal access token
- `TF_ADDRESS`: `https://gitlab.example.com/api/v4/projects/<PROJECT_ID>/terraform/state/<STATE_NAME>`

7) Run Terraform

```bash
terraform init -backend-config=config/test/config.tfbackend
terraform plan -var-file=config/test/test.tfvars -out deploy.tfplan
terraform apply deploy.tfplan
```

## Validation

- Terraform apply completes successfully.
- `docker ps` shows the container `terraform-docker-example` running.
- Browse to `http://0.0.0.0:8080` and see the sample page.

## Cleanup

```bash
terraform destroy -var-file=config/test/test.tfvars
docker-compose down -v
docker rm -f terraform-docker-example || true
```

## Troubleshooting

- **GitLab SSL errors**: Recreate certificates with correct `subjectAltName`; re-run `gitlab-ctl reconfigure`.
- **Backend authentication fails**: Ensure PAT scopes include `api` and that `TF_ADDRESS` points to the correct project and state name.
- **Container not reachable**: Confirm port 8080 is free and container is running (`docker logs terraform-docker-example`).

## References

- https://developer.hashicorp.com/terraform/tutorials/docker-get-started/docker-build
- https://docs.gitlab.com/ee/user/infrastructure/iac/terraform_state.html
- https://developer.hashicorp.com/terraform/language/settings/backends/http

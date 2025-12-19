# Lab 3 — GitLab CI/CD with Container Registry

Run GitLab locally with Docker Compose, secure it with self-signed certificates, enable the built-in container registry, register a runner, and execute a pipeline that builds and pushes an image from your project.

> Replace all secrets/domains with your own (for example `gitlab.example.com`, `YOUR_GITLAB_TOKEN`). Store tokens in GitLab CI/CD variables or runners, not in source control.

## Prerequisites

- Ubuntu 20.04 host (>= 2 vCPU, 8 GB RAM, 30 GB disk)
- Docker and Docker Compose
- A domain or hostnames mapped in `/etc/hosts` for GitLab and the registry (e.g., `gitlab.example.com`, `registry.gitlab.example.com`)

## Architecture

- Docker Compose launches GitLab and a GitLab Runner.
- GitLab registry is enabled on `registry.gitlab.<domain>:5005`.
- A self-signed CA secures GitLab and registry endpoints; certificates are trusted by Docker and the runner.

## Setup

1) Start GitLab and Runner

```bash
git clone https://github.com/chance2021/devopsdaydayup.git
cd devopsdaydayup/003-GitlabCICD
docker-compose up -d
```

2) Map hostnames

Add entries to `/etc/hosts` on your workstation (replace with your IP/domain):
```
<HOST_IP> gitlab.example.com registry.gitlab.example.com
```
If using `localhost`, map the Docker bridge IP instead (e.g., `172.17.0.1 gitlab.localhost registry.gitlab.localhost`).

3) Log in to GitLab

- Wait ~5 minutes for startup.
- Visit `https://gitlab.example.com` and sign in as `root` with `GITLAB_ROOT_PASSWORD` from `docker-compose.yaml`.
- Create a new project (**Public** is fine for the lab).
- In **Settings → CI/CD → Runners**, copy the **URL** and **Registration token** for later.

4) Regenerate TLS certificates (GitLab & registry)

```bash
docker exec -it $(docker ps -f name=web -q) bash
mkdir -p /etc/gitlab/ssl_backup
mv /etc/gitlab/ssl/* /etc/gitlab/ssl_backup
cd /etc/gitlab/ssl
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 365 -key ca.key -subj "/C=US/ST=CA/L=SF/O=Example/CN=Example Root CA" -out ca.crt

export YOUR_GITLAB_DOMAIN=gitlab.example.com
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

5) Enable the container registry

```bash
docker exec -it $(docker ps -f name=web -q) bash
export YOUR_GITLAB_DOMAIN=gitlab.example.com
cat >> /etc/gitlab/gitlab.rb <<EOF
registry_external_url 'https://registry.gitlab.$YOUR_GITLAB_DOMAIN:5005'
gitlab_rails['registry_enabled'] = true
gitlab_rails['registry_host'] = "registry.gitlab.$YOUR_GITLAB_DOMAIN"
gitlab_rails['registry_port'] = "5005"
gitlab_rails['registry_path'] = "/var/opt/gitlab/gitlab-rails/shared/registry"
gitlab_rails['registry_api_url'] = "http://127.0.0.1:5000"
gitlab_rails['registry_key_path'] = "/var/opt/gitlab/gitlab-rails/certificate.key"
registry['enable'] = true
registry['registry_http_addr'] = "127.0.0.1:5000"
registry['rootcertbundle'] = "/var/opt/gitlab/registry/gitlab-registry.crt"
nginx['ssl_certificate'] = "/etc/gitlab/ssl/registry.gitlab.$YOUR_GITLAB_DOMAIN.crt"
nginx['ssl_certificate_key'] = "/etc/gitlab/ssl/registry.gitlab.$YOUR_GITLAB_DOMAIN.key"
registry_nginx['enable'] = true
registry_nginx['listen_port'] = 5005
EOF
gitlab-ctl reconfigure
gitlab-ctl restart
exit
```

6) Trust certificates for Docker client

```bash
export YOUR_GITLAB_DOMAIN=gitlab.example.com
sudo mkdir -p /etc/docker/certs.d/registry.gitlab.$YOUR_GITLAB_DOMAIN:5005
sudo docker cp $(docker ps -f name=web -q):/etc/gitlab/ssl/registry.gitlab.$YOUR_GITLAB_DOMAIN.crt /etc/docker/certs.d/registry.gitlab.$YOUR_GITLAB_DOMAIN:5005/
docker login registry.gitlab.$YOUR_GITLAB_DOMAIN:5005   # use root password
```

7) Register the GitLab Runner

```bash
export YOUR_GITLAB_DOMAIN=gitlab.example.com
docker exec $(docker ps -f name=web -q) cat /etc/gitlab/ssl/gitlab.$YOUR_GITLAB_DOMAIN.crt
docker exec $(docker ps -f name=web -q) cat /etc/gitlab/ssl/registry.gitlab.$YOUR_GITLAB_DOMAIN.crt
docker exec -it $(docker ps -f name=gitlab-runner -q) bash
cat > /usr/local/share/ca-certificates/gitlab-server.crt <<'EOF'
# paste gitlab server certificate
EOF
cat > /usr/local/share/ca-certificates/registry.gitlab-server.crt <<'EOF'
# paste gitlab registry certificate
EOF
update-ca-certificates
gitlab-runner register
# URL: https://gitlab.example.com
# Token: <registration token from step 3>
# Tags: test            # must match .gitlab-ci.yml
# Executor: shell
```

8) Add lab files to your GitLab project and push

```bash
git clone <YOUR_GITLAB_PROJECT_URL>
cd <project-folder>
cp /path/to/devopsdaydayup/003-GitlabCICD/{app.py,Dockerfile,requirements.txt,.gitlab-ci.yaml,.gitlab-ci.yml} .
git add .
git commit -am "First commit"
git push
```

## Validation

- GitLab UI shows a green pipeline for your project.
- `docker login` to `registry.gitlab.<domain>:5005` succeeds.
- The project’s **Packages & Registries → Container Registry** lists your built image.
- Runner appears active under **Settings → CI/CD → Runners**.

## Cleanup

```bash
docker-compose down -v
sudo rm -rf /etc/docker/certs.d/registry.gitlab.*
```

## Troubleshooting

- **Runner not registering**: Confirm URL/token from **Settings → CI/CD → Runners** and that certificates are trusted inside the runner.
- **Docker login fails**: Ensure the registry cert is in `/etc/docker/certs.d/registry.gitlab.<domain>:5005/`.
- **Pipeline cannot push image**: Verify registry URL in `.gitlab-ci.yml`, and that runner tags match the job tags.
- **SSL errors**: Recreate certificates with correct `subjectAltName` for GitLab and registry hostnames, then reconfigure GitLab.

## References

- https://docs.gitlab.com/ee/install/docker/
- https://docs.gitlab.com/ee/ci/docker/using_docker_build.html
- https://docs.gitlab.com/ee/user/packages/container_registry/

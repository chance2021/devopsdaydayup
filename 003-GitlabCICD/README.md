# Project Name: Gitlab CICD Pipeline
This project will setup a Gitlab CICD pipeline, which will build the source code to a docker image and push to container registory in Gitlab and then re-deploy the docker container with the latest image in your local host.

# Project Goal
Understand how to setup/configure Gitlab as CICD pipeline. Familarize with gitlab pipeline.

# Table of Contents
1. [Prerequisites](#prerequisites)
2. [Project Steps](#project_steps)
3. [Troubleshooting](#troubleshooting)
4. [Reference](#reference)

# Prerequisites  <a name="prerequisites"></a>
- Ubuntu 20.04 OS
- Docker
- Docker Compose

# Project Steps <a name="project_steps"></a>
1. Run the docker container with docker-compose
```bash
git clone https://github.com/chance2021/devopsdaydayup.git
cd devopsdaydayup/003-GitlabCICD
docker-compose up -d
```

2. Open your browser and go to https://<your_gitlab_host_IP> (If you deploy it in your local, you can click [here](https://0.0.0.0))

3. Login to the Gitlab with username `root` and the password defined in your `docker-compose.yaml`. Click "New project" to create your first project.

4. Since the initial Gitlab CA certificate is missing some info and cannot be used by gitlab runner, we may have to regenerate/configure a new one. Run below commands:
```bash
docker exec -it <gitlab_web_containerID> bash
mkdir /etc/gitlab/ssl_backup
mv /etc/gitlab/ssl/* /etc/gitlab/ssl_backup
cd /etc/gitlab/ssl
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 365 -key ca.key -subj "/C=CN/ST=GD/L=SZ/O=Acme, Inc./CN=Acme Root CA" -out ca.crt
openssl req -newkey rsa:2048 -nodes -keyout gitlab.<YOUR_GITLAB_DOMAIN>.key -subj "/C=CN/ST=GD/L=SZ/O=Acme, Inc./CN=*.<YOUR_GITLAB_DOMAIN>.com" -out gitlab.<YOUR_GITLAB_DOMAIN>.com.csr
openssl x509 -req -extfile <(printf "subjectAltName=DNS:<YOUR_GITLAB_DOMAIN>.com,DNS:gitlab.<YOUR_GITLAB_DOMAIN>.com") -days 365 -in gitlab.<YOUR_GITLAB_DOMAIN>.com.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out gitlab.<YOUR_GITLAB_DOMAIN>.com.crt

# For example
#openssl req -newkey rsa:2048 -nodes -keyout gitlab.chance20221011.com.key -subj "/C=CN/ST=GD/L=SZ/O=Acme, Inc./CN=*.chance20221011.com" -out gitlab.chance20221011.com.csr
#openssl x509 -req -extfile <(printf "subjectAltName=DNS:chance20221011.com,DNS:gitlab.chance20221011.com") -days 365 -in gitlab.chance20221011.com.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out gitlab.chance20221011.com.crt

# Reconfigure the gitlab to apply above change
gitlab-cli reconfigure
gitlab-cli restart
cat /etc/gitlab/ssl/gitlab.<YOUR_GITLAB_DOMAIN>.com.crt
# For example: cat /etc/gitlab/ssl/gitlab.chance20221011.com.crt
exit
docker exec <gitlab runner container> -it bash
vi /usr/local/share/ca-certificates/gitlab.<YOUR_GITLAB_DOMAIN>.com.crt
# Paste above certificate content copied from gitlab server
update-ca-certificates
gitlab-runner register 
# Enter the GitLab instance URL (for example, https://<YOUR_GITLAB_DOMAIN>(i.g. https://gitlab.chance20221011.com)
Enter the registration token:
GR1348941Pjv5QzazEy4-32MPsArC
Enter a description for the runner:
[bad518d25b44]: tests
Enter tags for the runner (comma-separated):
test
Enter optional maintenance note for the runner:
test
Registering runner... succeeded                     runner=GR1348941Pjv5Qzaz
Enter an executor: ssh, docker+machine, docker-ssh, docker, parallels, shell, virtualbox, docker-ssh+machine, kubernetes, custom:
shell
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!
 
Configuration (with the authentication token) was saved in "/etc/gitlab-runner/config.toml" 
root@bad518d25b44:/usr/local/share/ca-certificates# cat /etc/gitlab-runner/config.toml 


Issue 1:
Letencrypt DNS issue
Soluton:
Chnage hostname to .com and wait for 1 hour

Reference
https://docs.gitlab.com/ee/install/docker.html#install-gitlab-using-docker-compose
[Runner Cannot Register with error: x509: certificate relies on legacy Common Name field, use SANs instead](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/28841)

# Lab 2 — Jenkins CI/CD Pipeline

Spin up Jenkins with Docker Compose, install pipeline plugins, and run a pipeline that builds and redeploys a container from a GitHub repository.

> Use placeholders for credentials (for example `YOUR_GITHUB_TOKEN`). Store secrets in Jenkins credentials, not in source control.

## Prerequisites

- Ubuntu 20.04 host with Docker and Docker Compose
- GitHub personal access token with `repo` scope for pulling Jenkinsfile sources

## Setup

1) Start Jenkins with Docker Compose

```bash
git clone https://github.com/chance2021/devopsdaydayup.git
cd devopsdaydayup/002-JenkinsCICD
docker-compose up -d
```

2) Install required plugins

- Open `http://<JenkinsHostIP>:8080` (or `http://0.0.0.0:8080` locally) and log in with the credentials defined in `docker-compose.yaml`.
- Go to **Manage Jenkins → Manage Plugins → Available** and install:
  - **Pipeline**
  - **Git**
  - **Docker Pipeline**
Restart Jenkins if prompted.

3) Create the pipeline job

- From the Jenkins home page, click **New Item** → name your project → select **Pipeline** → **OK**.
- In the **Pipeline** section configure:
  - **Definition**: Pipeline script from SCM
  - **SCM**: Git
  - **Repository URL**: your fork URL (e.g., `https://github.com/<YOUR_USER>/devopsdaydayup`)
  - **Credentials**: add a **Username with password** credential using your GitHub username and token; set Scope to **Global**; give it an ID (e.g., `github-token`).
  - **Branch Specifier**: `*/main` (or your branch)
  - **Script Path**: `002-JenkinsCICD/Jenkinsfile`
  - Uncheck **Lightweight checkout**

Save the job.

4) Pre-build the sample container (used by the pipeline)

```bash
docker build -t color-web:init .
docker run -d -p 8080:8080 --name color-web color-web:init
```

5) Run the pipeline

- Click **Build Now** on the job page.
- If Docker socket permissions fail inside the Jenkins container, run:
  ```bash
  docker exec <jenkins-container-id> chmod 777 /var/run/docker.sock
  ```

6) Verify the app

- Browse to `http://localhost:8080` to see the “Hello world” page.
- Edit `app.py` (for example change the text), commit/push to your repo, and build again to see the update deployed.

## Validation

- Jenkins job succeeds and shows green in build history.
- `docker ps` shows the `color-web` container running with the updated image.
- Visiting `http://localhost:8080` shows your edited text.

## Cleanup

```bash
docker-compose down -v
docker rm -f color-web
docker image rm color-web:init || true
```

## Troubleshooting

- **No such property: docker**: Ensure the **Docker Pipeline** plugin is installed.
- **No such container: color-web**: Start the container before the pipeline or adjust the pipeline logic; `docker run -p 8080:8080 --name color-web color-web:init`.
- **Docker permission denied inside Jenkins**: Grant access to the Docker socket for the Jenkins container: `docker exec <jenkins-container-id> chmod 777 /var/run/docker.sock`.

## References

- https://www.jenkins.io/doc/pipeline/tour/hello-world/
- https://plugins.jenkins.io/docker-workflow/

# Lab 23 – Secure CI with GitHub Actions, ARC, Vault, Artifactory & SonarQube

This lab walks you through building a **local DevSecOps CI environment** on top of:

- GitHub Actions + Actions Runner Controller (ARC) with **DinD runners**
- HashiCorp Vault with **GitHub Actions OIDC (JWT) auth**
- JFrog Artifactory OSS as **Maven repository**
- SonarQube as **code quality & security scan** service

All steps are designed to follow **GitHub open source documentation best practices**:

- No real secrets or private keys are committed  
- Sensitive values are represented as **placeholders**  
- Commands are split into **clear, reproducible steps**

> ⚠️ **Important:**  
> Replace all `<PLACEHOLDER>` values with your own **test credentials**.  
> Never commit real tokens, passwords, unseal keys, or private keys to a public repo.

---

## Table of Contents

1. [Prerequisites](#prerequisites)  
2. [Part 0 – Prepare Minikube Cluster](#part-0--prepare-minikube-cluster)  
3. [Part 1 – Install Actions Runner Controller](#part-1--install-actions-runner-controller)  
4. [Part 2 – Create a Runner Scale Set (DinD mode)](#part-2--create-a-runner-scale-set-dind-mode)  
5. [Part 3 – Install Vault](#part-3--install-vault)  
6. [Part 4 – Initialize & Unseal Vault](#part-4--initialize--unseal-vault)  
7. [Part 5 – Configure Vault for GitHub OIDC & CI Secrets](#part-5--configure-vault-for-github-oidc--ci-secrets)  
8. [Part 6 – Install Artifactory OSS](#part-6--install-artifactory-oss)  
9. [Part 7 – Install SonarQube](#part-7--install-sonarqube)  
10. [Part 8 – Setup CI Workflow](#part-8--setup-ci-workflow)  
11. [References](#references)  

---

## Prerequisites

- A GitHub account and repository (example used: `chance2021/devopsdaydayup`)
- A GitHub App installed on your org/repo (for ARC authentication)
- Local tools:
  - `kubectl`
  - `helm`
  - `minikube`
  - `jq`
  - `docker`
- A machine with enough resources (e.g. >= 16 GB RAM recommended for Minikube)

---
## Part 0 – Prepare Minikube Cluster

Install Minikube by following the instruction: https://minikube.sigs.k8s.io/docs/start/?arch=%2Fmacos%2Farm64%2Fstable%2Fbinary+download

Once installed, increase Minikube memory to avoid `OOMKill` issues when running multiple components (Vault, Artifactory, SonarQube, runners).

```bash
# Increase default memory and restart Minikube
minikube config set memory 15360
minikube delete && minikube start
```

> Note: For **Part 1** and **Part 2**, you can refer to Lab 22. The only difference is that Part 2 will enable DinD mode, which is needed when building image.

## Part 1 – Install Actions Runner Controller

Install the ARC controller into a dedicated namespace:
```bash
helm upgrade --install arc \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --namespace arc-systems \
  --create-namespace
```

## Part 2 – Create a Runner Scale Set (DinD mode)

This section configures ARC to manage a runner scale set for your GitHub repo, in DinD (Docker-in-Docker) mode.

### 2.1 Define variables

ℹ️ Replace the values in angle brackets (<...>) with your own.

```bash
INSTALLATION_NAME="arc-runner-set"
GITHUB_CONFIG_URL="https://github.com/chance2021/devopsdaydayup"

# From your GitHub App configuration
GITHUB_APP_ID="<YOUR_GITHUB_APP_ID>"
GITHUB_APP_INSTALLATION_ID="<YOUR_GITHUB_APP_INSTALLATION_ID>"
GITHUB_APP_PRIVATE_KEY_PATH="<PATH_TO_YOUR_GITHUB_APP_PRIVATE_KEY_PEM>"

NAMESPACE="arc-runners"
SECRET_NAME="pre-defined-secret"
```

### 2.2 Create the namespace

```bash
kubectl create namespace "${NAMESPACE}"
```

### 2.3 Store GitHub App credentials as a Kubernetes Secret

>  ⚠️ Never commit your real app ID, installation ID, or private key file.
They should live only in your local environment or secure secret manager.

```bash
kubectl create secret generic "${SECRET_NAME}" \
  --namespace="${NAMESPACE}" \
  --from-literal=github_app_id="${GITHUB_APP_ID}" \
  --from-literal=github_app_installation_id="${GITHUB_APP_INSTALLATION_ID}" \
  --from-file=github_app_private_key="${GITHUB_APP_PRIVATE_KEY_PATH}"
```

You can verify the secret keys:

```bash
kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" -o jsonpath='{.data}' | jq keys
```

### 2.4 Create a values-dind-custom.yaml for the runner scale set

```bash
cat > values-dind-custom.yaml <<EOF
githubConfigUrl: "${GITHUB_CONFIG_URL}"
githubConfigSecret: "${SECRET_NAME}"
runnerScaleSetName: "${INSTALLATION_NAME}"

containerMode:
  type: "dind"
EOF
```

> 💡 For real projects, you may also configure labels, GitHub org-level scope, and extra environment variables in this values file.

### 2.5 Install the runner scale set

```bash
helm upgrade --install "${INSTALLATION_NAME}" \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  -f values-dind-custom.yaml
```

At this point, ARC should spin up GitHub self-hosted runners in DinD mode when your GitHub Actions workflow requests them.

## Part 3 – Install Vault

Add the HashiCorp Helm repo and install Vault in server mode:

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Install with non-TLS mode for local lab purposes (do not use this in production):
helm upgrade --install vault hashicorp/vault \
  --namespace vault \
  --set 'server.extraArgs=-tls-disable=true' \
  --set server.extraEnvironmentVars.VAULT_API_ADDR=http://0.0.0.0:8200 \
  --set server.extraEnvironmentVars.VAULT_CLUSTER_ADDR=http://0.0.0.0:8201
```
## Part 4 – Initialize & Unseal Vault

### 4.1 Initialize Vault

```bash
kubectl -n vault exec -ti vault-0 -- vault operator init
```

The output will include:
- Multiple unseal keys
- An initial root token

> ⚠️ Do not commit these values.
Store them securely (for example in a password manager) and rotate after testing.

### 4.2 Unseal Vault (lab example)

Use three of the unseal keys until the key threshold is reached (default: 3):

```bash
# Example – replace with your own unseal keys
kubectl -n vault exec -ti vault-0 -- vault operator unseal <UNSEAL_KEY_1>
kubectl -n vault exec -ti vault-0 -- vault operator unseal <UNSEAL_KEY_2>
kubectl -n vault exec -ti vault-0 -- vault operator unseal <UNSEAL_KEY_3>
```
## Part 5 – Configure Vault for GitHub OIDC & CI Secrets

### 5.1 Login to Vault pod

```bash
kubectl -n vault exec -ti vault-0 -- sh
```
Inside the pod:
```bash
vault login <VAULT_ROOT_TOKEN>
```

### 5.2 Enable JWT auth method for GitHub Actions OIDC

```bash
vault auth enable jwt

vault write auth/jwt/config \
  bound_issuer="https://token.actions.githubusercontent.com" \
  oidc_discovery_url="https://token.actions.githubusercontent.com"
```

### 5.3 Enable KV v2 for CI secrets
```bash
vault secrets enable -path=kv -version=2 kv
```

### 5.4 Store CI-related secrets

> ⚠️ Use test credentials only and never commit real passwords or tokens.

#### 5.4.1 Artifactory credentials

```bash
vault kv put kv/ci/artifactory \
  username="<ARTIFACTORY_USERNAME>" \
  password="<ARTIFACTORY_PASSWORD>" \
  url_public="http://artifactory-oss-artifactory-nginx.artifactory-oss.svc/artifactory/maven-remote/"
```

### 5.4.2 GitHub / container registry credentials
Example for GHCR:
```bash
vault kv put kv/ci/github \
  username="<GITHUB_USERNAME>" \
  password="<GHCR_PERSONAL_ACCESS_TOKEN>" \
  docker_registry="ghcr.io/<GITHUB_USERNAME>"
```
You can later retrieve and debug secrets with:
```bash
vault kv get -format=json kv/ci/artifactory
vault kv get -format=json kv/ci/github
```

### 5.5 Create Vault policy for CI

```bash
vault policy write myproject-ci - <<EOF
# Read-only permission on 'kv/data/ci/*' path
path "kv/data/ci/*" {
  capabilities = [ "read" ]
}
EOF
```

### 5.6 Create a JWT role bound to your GitHub repo

Bind the role to your repository and GitHub audience:

```bash
vault write auth/jwt/role/myproject-ci -<<EOF
{
  "role_type": "jwt",
  "user_claim": "actor",
  "bound_claims": {
    "repository": "chance2021/devopsdaydayup"
  },
  "bound_audiences": "https://github.com/chance2021",
  "policies": ["myproject-ci"],
  "ttl": "10m"
}
EOF
```
Exit the pod shell when done:
```
exit
```

## Part 6 – Install Artifactory OSS

Add and update the JFrog Helm repo:
```bash
helm repo add jfrog https://charts.jfrog.io
helm repo update
```
Install Artifactory OSS (lab values):
```bash
helm upgrade --install artifactory-oss \
  --set artifactory.postgresql.auth.password="<ARTIFACTORY_DB_PASSWORD>" \
  --set nginx.https.enabled=true \
  --set nginx.tlsSecretName=artifactory-tls \
  --namespace artifactory-oss \
  --create-namespace \
  jfrog/artifactory-oss
```
Port-forward to access the UI locally:
```bash
kubectl --namespace artifactory-oss \
  port-forward svc/artifactory-oss-artifactory-nginx 8080:80
```
Then open browser with the address:
- http://127.0.0.1:8080￼

From the UI:
1. Log in with the default admin account (change password immediately).
2. Create a remote Maven repository named maven-remote.
3.	Create a test user and grant permissions to maven-remote.

Use those test credentials in Vault (kv/ci/artifactory).

## Part 7 – Install SonarQube

> Example tested on macOS with Apple M2, but the commands are generic.

Add the SonarQube Helm repo:
```bash
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update
```
Set a monitoring passcode:
```bash
export MONITORING_PASSCODE="yourPasscode123"
```
Install SonarQube (Community edition, embedded Postgres):
```bash
helm upgrade --install -n sonarqube sonarqube sonarqube/sonarqube \
  --create-namespace \
  --set edition=developer,monitoringPasscode=$MONITORING_PASSCODE \
  --set postgresql.enabled=true \
  --set postgresql.image.tag=17.4.0
```
Get the Pod name:
```bash
export POD_NAME=$(kubectl get pods --namespace sonarqube \
  -l "app=sonarqube,release=sonarqube" \
  -o jsonpath="{.items[0].metadata.name}")
```
Port-forward:
```bash
echo "Visit http://127.0.0.1:8081 to use SonarQube"
kubectl port-forward $POD_NAME 8081:9000 -n sonarqube
```
Open http://127.0.0.1:8081￼ and log in (default admin / admin in a fresh install; you’ll be asked to change it).

### 7.1 Import GitHub repo into SonarQube
1.	Configure a GitHub App / OAuth integration (App ID, client ID, client secret).
2.	Import the GitHub repository chance2021/devopsdaydayup as a project.
3.	Generate a project analysis token for that project.

### 7.2 Store SonarQube config in Vault
```bash
vault kv put kv/ci/sonarqube \
  token="<SONARQUBE_PROJECT_TOKEN>" \
  host_url="http://sonarqube-sonarqube.sonarqube:9000" \
  project_key="devopsdaydayup-local" \
  project_name="devopsdaydayup"
```

## Part 8 - Setup CI Workflow
Create a `ci.yaml` file under `.github/workflow` folder in your repo. Paste the following in the file:
```yaml
name: ci-java-with-vault-nexus-sonar-security

on:
  push:
    branches: [ <YOUR_FEATURE_BRANCH_NAME> ]

permissions:
  contents: read
  id-token: write   # often needed for auth to cloud / secrets backends
  security-events: write

env:
  APP_NAME: my-java-app
  DOCKER_IMAGE_NAME: my-java-app
  MAVEN_SETTINGS_PATH: .maven/settings.xml  # you’ll create this
  # Use Nexus as Maven repo & Docker registry
  NEXUS_MAVEN_REPO_URL: https://nexus.example.com/repository/maven-releases/
  NEXUS_DOCKER_REGISTRY: nexus.example.com
  SONAR_PROJECT_KEY: my-org_my-java-app
  SONAR_PROJECT_NAME: my-java-app

jobs:
  build-and-scan:
    runs-on: arc-runner-set

    steps:
      # 1. Checkout
      - name: Checkout
        uses: actions/checkout@v4

      - name: Debug GitHub OIDC token audience
        run: |
            echo "Requesting GitHub OIDC token..."
            TOKEN_RESPONSE=$(curl -sSL \
            -H "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
            "${ACTIONS_ID_TOKEN_REQUEST_URL}?audience=https://token.actions.githubusercontent.com")

            TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r .value)

            echo "===== RAW JWT ====="
            echo "$TOKEN"

            echo ""
            echo "===== DECODED PAYLOAD ====="
            echo "$TOKEN" | cut -d '.' -f2 | base64 --decode 2>/dev/null | jq .


      # 2. Pull secrets from Vault
      # Assumes HashiCorp Vault is accessible and GitHub runner has auth (GitHub OIDC / token / etc.)
      - name: Import secrets from Vault
        id: vault
        uses: hashicorp/vault-action@v3
        with:
          url: http://vault.vault:8200
          method: jwt
          role: "myproject-ci"
          # Example: Nexus & Sonar credentials stored in Vault
          secrets: |
            kv/data/ci/artifactory username | ARTIFACTORY_USERNAME ;
            kv/data/ci/artifactory password | ARTIFACTORY_PASSWORD ;
            kv/data/ci/artifactory url_public | ARTIFACTORY_URL_PUBLIC;
            kv/data/ci/github username | GITHUB_USERNAME ;
            kv/data/ci/github password | GITHUB_PASSWORD ;
            kv/data/ci/github docker_registry | GITHUB_DOCKER_REGISTRY ;
            kv/data/ci/sonarqube token   | SONAR_TOKEN;
            kv/data/ci/sonarqube host_url | SONAR_HOST_URL;
            kv/data/ci/sonarqube project_key | SONAR_PROJECT_KEY;
            kv/data/ci/sonarqube project_name | SONAR_PROJECT_NAME;

      - name: Debug Vault secrets
        run: |
            echo $ARTIFACTORY_USERNAME
            echo $ARTIFACTORY_PASSWORD
            echo $SONAR_TOKEN

      # 3. Setup Java (Maven)
      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
          cache: maven

      # 4. Generate Maven settings.xml to use Artifactory
      - name: Generate Maven settings.xml (force Artifactory))
        run: |
          sudo apt-get update && sudo apt-get install -y maven
          mkdir -p ~/.m2

          cat > ~/.m2/settings.xml <<EOF
          <settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
                    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                    xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
                                        https://maven.apache.org/xsd/settings-1.0.0.xsd">
            <servers>
              <server>
                <id>artifactory</id>
                <username>${ARTIFACTORY_USERNAME}</username>
                <password>${ARTIFACTORY_PASSWORD}</password>
              </server>
              <server>
                <id>artifactory-releases</id>
                <username>${ARTIFACTORY_USERNAME}</username>
                <password>${ARTIFACTORY_PASSWORD}</password>
              </server>
              <server>
                <id>artifactory-snapshots</id>
                <username>${ARTIFACTORY_USERNAME}</username>
                <password>${ARTIFACTORY_PASSWORD}</password>
              </server>
              <server>
                <id>artifactory-mirror</id>
                <username>${ARTIFACTORY_USERNAME}</username>
                <password>${ARTIFACTORY_PASSWORD}</password>
              </server>
              </servers>

            <mirrors>
              <mirror>
                <id>artifactory-mirror</id>
                <name>artifactory mirror</name>
                <mirrorOf>*,!sonar-plugins</mirrorOf>
                <url>${ARTIFACTORY_URL_PUBLIC}</url>
              </mirror>
            </mirrors>

            <profiles>
              <profile>
                <id>artifactory</id>
                <repositories>
                  <repository>
                    <id>central</id>
                    <name>Central via Artifactory</name>
                    <url>${ARTIFACTORY_URL_PUBLIC}</url>
                    <releases><enabled>true</enabled></releases>
                    <snapshots><enabled>true</enabled></snapshots>
                  </repository>
                </repositories>
                <pluginRepositories>
                  <pluginRepository>
                    <id>central</id>
                    <name>Central Plugins via Artifactory</name>
                    <url>${ARTIFACTORY_URL_PUBLIC}</url>
                    <releases><enabled>true</enabled></releases>
                    <snapshots><enabled>true</enabled></snapshots>
                  </pluginRepository>
                </pluginRepositories>
              </profile>
            </profiles>

            <activeProfiles>
              <activeProfile>artifactory</activeProfile>
            </activeProfiles>
          </settings>
          EOF

          echo "Generated ~/.m2/settings.xml:"
          cat ~/.m2/settings.xml

      # 5. Maven build (dependencies pulled via Artifactory)
      - name: Build with Maven
        run: cd 025-GithubActionCI && mvn -s ~/.m2/settings.xml -B clean deploy 

      # 6. SonarQube scan (assumes sonar-project.properties or config via CLI args)
      - name: SonarQube scan
        env:
          SONAR_TOKEN: ${{ env.SONAR_TOKEN }}
        run: |
          cd 025-GithubActionCI && mvn -B -s ~/.m2/settings.xml \
            sonar:sonar \
            -Dsonar.host.url=${SONAR_HOST_URL} \
            -Dsonar.login=${SONAR_TOKEN} \
            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
            -Dsonar.projectName=${SONAR_PROJECT_NAME} \
            -Dsonar.branch.name="${GITHUB_HEAD_REF}"

      # 8. Build container image
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Docker registry
        uses: docker/login-action@v3
        with:
          registry: ${{ steps.vault.outputs.GITHUB_DOCKER_REGISTRY }}
          username: ${{ steps.vault.outputs.GITHUB_USERNAME }}
          password: ${{ steps.vault.outputs.GITHUB_PASSWORD }}
  
      - name: Build Docker image
        id: build-image
        run: |
          DOCKER_IMAGE_NAME="java-with-vault-nexus-sonar-security"
          IMAGE_TAG=${GITHUB_SHA::7}
          echo "DOCKER_ADDRESS=${GITHUB_DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:${IMAGE_TAG}" >> $GITHUB_OUTPUT
          echo "DOCKER_IMAGE_NAME=${DOCKER_IMAGE_NAME}" >> $GITHUB_OUTPUT
          echo "IMAGE_TAG=${IMAGE_TAG}" >> $GITHUB_OUTPUT
          cd 025-GithubActionCI
          docker build \
            -t ${GITHUB_DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:${IMAGE_TAG} \
            -t ${GITHUB_DOCKER_REGISTRY}/${DOCKER_IMAGE_NAME}:latest .

      - name: Show Docker images
        run: docker images

      # 9. Image scan (example: Trivy)
      - name: Scan Docker image with Trivy
        uses: aquasecurity/trivy-action@0.28.0
        continue-on-error: true
        with:
          image-ref: ${{ steps.build-image.outputs.DOCKER_ADDRESS }}
          format: 'table'
          exit-code: '1'   # fail pipeline on HIGH/CRITICAL if you like—configurable
          vuln-type: 'os,library'
          severity: 'CRITICAL,HIGH'

      # 10. Push Docker image to GitHub Container Registry
      - name: Push Docker image to Nexus
        run: |
          IMAGE_TAG=${GITHUB_SHA::7}
          docker push ${{ steps.build-image.outputs.DOCKER_ADDRESS }}
          docker push ${{ steps.vault.outputs.GITHUB_DOCKER_REGISTRY }}/${{ steps.build-image.outputs.DOCKER_IMAGE_NAME }}:latest
```
Update `YOUR_FEATURE_BRANCH_NAME` to your branch. Once it is pushed to the remote, a build will be triggered based on this CI workflow.

## References
- GitHub Docs – OIDC with HashiCorp Vault
https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-hashicorp-vault￼
- Artifactory OSS Helm chart on Artifact Hub
https://artifacthub.io/packages/helm/jfrog/artifactory-oss￼


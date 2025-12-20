# Lab 23 – Secure CI with GitHub Actions, ARC, Vault, Artifactory, and SonarQube

Stand up a local DevSecOps toolchain on Minikube: Actions Runner Controller (ARC) hosts DinD runners for GitHub Actions, Vault issues short-lived secrets via GitHub OIDC, Artifactory OSS serves Maven artifacts, and SonarQube performs code-quality scans. The workflow builds a sample Java app, pulls secrets from Vault, publishes to Artifactory/GHCR, and runs a scan.

> Use placeholders only (for example `YOUR_GITHUB_TOKEN`, `YOUR_SONAR_TOKEN`). Never commit real tokens, private keys, or unseal keys. Store secrets in environment variables or a secret manager.

## Architecture

- GitHub Actions workflow uses ARC-managed self-hosted runners (`arc-runner-set`) in DinD mode.
- Vault authenticates runners with GitHub OIDC (`auth/jwt`) and returns CI secrets from `kv/ci/*`.
- Artifactory OSS hosts a remote Maven repository for build dependencies.
- SonarQube Developer Edition (example) performs static analysis with a project token.
- Docker images are pushed to GHCR (or your preferred registry).

## Prerequisites

- GitHub repository and GitHub App for ARC authentication (App ID, installation ID, private key path)
- Tools: `kubectl`, `helm`, `minikube`, `jq`, `docker`, `openssl`
- Resources: Minikube with >= 4 CPUs and 12–16 GB RAM (Vault, Artifactory, SonarQube, runners)
- Personal access token for GHCR with `write:packages`
- Test credentials for Artifactory and SonarQube (created during the lab)

Suggested environment variables:

```bash
export GITHUB_USER="YOUR_GITHUB_USER"
export GITHUB_REPO="YOUR_GITHUB_USER/devopsdaydayup"
export GITHUB_APP_ID="YOUR_GITHUB_APP_ID"
export GITHUB_APP_INSTALLATION_ID="YOUR_INSTALLATION_ID"
export GITHUB_APP_PRIVATE_KEY_PATH="PATH/TO/APP_PRIVATE_KEY.pem"
export GHCR_REGISTRY="ghcr.io/${GITHUB_USER}"
```

## Steps

### 1) Prepare Minikube

```bash
minikube config set memory 15360
minikube start
```

### 2) Install Actions Runner Controller

```bash
helm upgrade --install arc \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
  --namespace arc-systems \
  --create-namespace
```

### 3) Create a DinD runner scale set

```bash
cat > values-dind-custom.yaml <<EOF
githubConfigUrl: "https://github.com/${GITHUB_REPO}"
githubConfigSecret: "arc-github-app"
runnerScaleSetName: "arc-runner-set"
containerMode:
  type: "dind"
EOF

kubectl create namespace arc-runners

kubectl create secret generic arc-github-app \
  --namespace arc-runners \
  --from-literal=github_app_id="${GITHUB_APP_ID}" \
  --from-literal=github_app_installation_id="${GITHUB_APP_INSTALLATION_ID}" \
  --from-file=github_app_private_key="${GITHUB_APP_PRIVATE_KEY_PATH}"

helm upgrade --install arc-runner-set \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --namespace arc-runners \
  --create-namespace \
  -f values-dind-custom.yaml
```

Verify a runner pod appears when a job is queued: `kubectl -n arc-runners get pods`.

### 4) Install Vault (lab settings)

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

helm upgrade --install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  --set 'server.extraArgs=-tls-disable=true' \
  --set server.extraEnvironmentVars.VAULT_API_ADDR=http://0.0.0.0:8200 \
  --set server.extraEnvironmentVars.VAULT_CLUSTER_ADDR=http://0.0.0.0:8201
```

Initialize and unseal (store keys securely; do not commit):

```bash
kubectl -n vault exec -ti vault-0 -- vault operator init
kubectl -n vault exec -ti vault-0 -- vault operator unseal YOUR_UNSEAL_KEY_1
kubectl -n vault exec -ti vault-0 -- vault operator unseal YOUR_UNSEAL_KEY_2
kubectl -n vault exec -ti vault-0 -- vault operator unseal YOUR_UNSEAL_KEY_3
```

Configure auth and secrets inside the pod:

```bash
kubectl -n vault exec -ti vault-0 -- sh

vault login YOUR_VAULT_ROOT_TOKEN
vault auth enable jwt
vault write auth/jwt/config \
  bound_issuer="https://token.actions.githubusercontent.com" \
  oidc_discovery_url="https://token.actions.githubusercontent.com"

vault secrets enable -path=kv -version=2 kv

vault kv put kv/ci/artifactory \
  username="YOUR_ARTIFACTORY_USER" \
  password="YOUR_ARTIFACTORY_PASSWORD" \
  url_public="http://artifactory-oss-artifactory-nginx.artifactory-oss.svc/artifactory/maven-remote/"

vault kv put kv/ci/github \
  username="${GITHUB_USER}" \
  password="YOUR_GHCR_TOKEN" \
  docker_registry="${GHCR_REGISTRY}"

vault kv put kv/ci/sonarqube \
  token="YOUR_SONARQUBE_PROJECT_TOKEN" \
  host_url="http://sonarqube-sonarqube.sonarqube:9000" \
  project_key="devopsdaydayup-local" \
  project_name="devopsdaydayup"

vault policy write myproject-ci - <<EOF
path "kv/data/ci/*" {
  capabilities = ["read"]
}
EOF

vault write auth/jwt/role/myproject-ci -<<EOF
{
  "role_type": "jwt",
  "user_claim": "actor",
  "bound_claims": {
    "repository": "${GITHUB_REPO}"
  },
  "bound_audiences": "https://github.com/${GITHUB_USER}",
  "policies": ["myproject-ci"],
  "ttl": "10m"
}
EOF
exit
```

### 5) Install Artifactory OSS

```bash
helm repo add jfrog https://charts.jfrog.io
helm repo update

helm upgrade --install artifactory-oss jfrog/artifactory-oss \
  --namespace artifactory-oss \
  --create-namespace \
  --set artifactory.postgresql.auth.password="YOUR_ARTIFACTORY_DB_PASSWORD" \
  --set nginx.https.enabled=true \
  --set nginx.tlsSecretName=artifactory-tls

kubectl -n artifactory-oss port-forward svc/artifactory-oss-artifactory-nginx 8080:80
```

In the UI (`http://127.0.0.1:8080`):

1. Sign in with the default admin user and change the password.
2. Create a remote Maven repository named `maven-remote`.
3. Create a test user with access to `maven-remote`. Store those credentials in Vault (`kv/ci/artifactory`).

### 6) Install SonarQube

```bash
helm repo add sonarqube https://SonarSource.github.io/helm-chart-sonarqube
helm repo update

export MONITORING_PASSCODE="YOUR_MONITORING_PASSCODE"

helm upgrade --install sonarqube sonarqube/sonarqube \
  --namespace sonarqube \
  --create-namespace \
  --set edition=developer \
  --set monitoringPasscode=${MONITORING_PASSCODE} \
  --set postgresql.enabled=true \
  --set postgresql.image.tag=17.4.0

export SONAR_POD=$(kubectl -n sonarqube get pods -l "app=sonarqube,release=sonarqube" -o jsonpath="{.items[0].metadata.name}")
kubectl -n sonarqube port-forward "$SONAR_POD" 8081:9000
```

Open `http://127.0.0.1:8081`, log in (default admin/admin), change the password, create a project from your GitHub repo, and generate a project token. Store the token in Vault (`kv/ci/sonarqube`).

### 7) Configure the GitHub Actions workflow

Create `.github/workflows/ci.yaml` in your fork:

```yaml
name: ci-java-with-vault-artifactory-sonar

on:
  push:
    branches: [ main ]

permissions:
  contents: read
  id-token: write
  security-events: write

jobs:
  build-and-scan:
    runs-on: arc-runner-set
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Pull secrets from Vault (GitHub OIDC)
        id: vault
        uses: hashicorp/vault-action@v3
        with:
          url: http://vault.vault:8200
          method: jwt
          role: "myproject-ci"
          secrets: |
            kv/data/ci/artifactory username | ARTIFACTORY_USERNAME ;
            kv/data/ci/artifactory password | ARTIFACTORY_PASSWORD ;
            kv/data/ci/artifactory url_public | ARTIFACTORY_URL_PUBLIC ;
            kv/data/ci/github username | GITHUB_USERNAME ;
            kv/data/ci/github password | GITHUB_PASSWORD ;
            kv/data/ci/github docker_registry | GITHUB_DOCKER_REGISTRY ;
            kv/data/ci/sonarqube token | SONAR_TOKEN ;
            kv/data/ci/sonarqube host_url | SONAR_HOST_URL ;
            kv/data/ci/sonarqube project_key | SONAR_PROJECT_KEY ;
            kv/data/ci/sonarqube project_name | SONAR_PROJECT_NAME ;

      - name: Set up JDK
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
          cache: maven

      - name: Generate Maven settings.xml for Artifactory
        run: |
          mkdir -p ~/.m2
          cat > ~/.m2/settings.xml <<'EOF'
          <settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
                    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                    xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd">
            <servers>
              <server>
                <id>artifactory</id>
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
                    <url>${ARTIFACTORY_URL_PUBLIC}</url>
                  </repository>
                </repositories>
              </profile>
            </profiles>
            <activeProfiles>
              <activeProfile>artifactory</activeProfile>
            </activeProfiles>
          </settings>
          EOF

      - name: Build with Maven
        run: cd 025-GithubActionCI && mvn -s ~/.m2/settings.xml -B clean verify

      - name: SonarQube scan
        env:
          SONAR_TOKEN: ${{ steps.vault.outputs.SONAR_TOKEN }}
        run: |
          cd 025-GithubActionCI
          mvn -s ~/.m2/settings.xml -B sonar:sonar \
            -Dsonar.host.url=${{ steps.vault.outputs.SONAR_HOST_URL }} \
            -Dsonar.login=${{ steps.vault.outputs.SONAR_TOKEN }} \
            -Dsonar.projectKey=${{ steps.vault.outputs.SONAR_PROJECT_KEY }} \
            -Dsonar.projectName=${{ steps.vault.outputs.SONAR_PROJECT_NAME }} \
            -Dsonar.branch.name="${GITHUB_REF_NAME}"

      - name: Build Docker image
        id: build-image
        run: |
          IMAGE_TAG=${GITHUB_SHA::7}
          IMAGE_NAME=${{ steps.vault.outputs.GITHUB_DOCKER_REGISTRY }}/java-with-vault-nexus-sonar-security
          echo "IMAGE=${IMAGE_NAME}:${IMAGE_TAG}" >> "$GITHUB_OUTPUT"
          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest 025-GithubActionCI

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ steps.vault.outputs.GITHUB_DOCKER_REGISTRY }}
          username: ${{ steps.vault.outputs.GITHUB_USERNAME }}
          password: ${{ steps.vault.outputs.GITHUB_PASSWORD }}

      - name: Push image
        run: |
          docker push ${{ steps.build-image.outputs.IMAGE }}
          docker push ${{ steps.vault.outputs.GITHUB_DOCKER_REGISTRY }}/java-with-vault-nexus-sonar-security:latest

      - name: Scan image with Trivy (optional)
        uses: aquasecurity/trivy-action@0.28.0
        continue-on-error: true
        with:
          image-ref: ${{ steps.build-image.outputs.IMAGE }}
          severity: 'CRITICAL,HIGH'
```

Commit the workflow to your fork to trigger a run on `main`. Adjust branches, registry, and project names as needed.

## Validation

- `kubectl -n arc-runners get pods` shows a runner when a workflow starts.
- `vault kv get kv/ci/artifactory` (inside the pod) returns stored secrets.
- Artifactory UI lists the `maven-remote` repo and accepts your test user credentials.
- SonarQube shows a completed analysis for your project.
- GHCR (or your registry) contains the built image tag.

## Cleanup

```bash
helm uninstall arc -n arc-systems
helm uninstall arc-runner-set -n arc-runners
helm uninstall vault -n vault
helm uninstall artifactory-oss -n artifactory-oss
helm uninstall sonarqube -n sonarqube
kubectl delete namespace arc-systems arc-runners vault artifactory-oss sonarqube
minikube delete
```

## Troubleshooting

- **Runner never starts**: Confirm ARC controller is healthy (`kubectl -n arc-systems get pods`) and your GitHub App credentials in `arc-github-app` are correct.
- **Vault auth fails**: Ensure the role `myproject-ci` has the correct `repository` and `bound_audiences` values for your fork. Check the OIDC token audience in workflow logs.
- **Artifactory 401**: Verify the test user/password and that the repo URL in Vault matches the Helm release service name.
- **SonarQube auth fails**: Rotate the project token and update Vault. Confirm the host URL uses the in-cluster service when the runner executes inside Kubernetes.
- **Image push denied**: PAT must have `write:packages` and the GHCR repository should be accessible (public for easiest local pulls).

## References

- [GitHub Actions OIDC with HashiCorp Vault](https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect#example-using-hashicorp-vault)
- [Actions Runner Controller](https://github.com/actions/actions-runner-controller)
- [Artifactory OSS Helm chart](https://artifacthub.io/packages/helm/jfrog/artifactory-oss)
- [SonarQube Helm chart](https://github.com/SonarSource/helm-chart-sonarqube)

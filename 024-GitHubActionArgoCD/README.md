# Lab 24 — Argo Events ➜ Workflows ➜ Argo CD ➜ Rollouts Lab

This repository contains everything you need to practice wiring a full Argo stack: a GitHub push is forwarded through Smee.io to Argo Events, a sensor starts an Argo Workflow that builds and publishes an image, the workflow updates the Helm chart, and Argo CD reconciles the change by deploying an Argo Rollout onto Minikube.

```
GitHub push → Smee webhook relay → Argo EventSource → Sensor → Argo Workflow
        → GHCR image + Git commit → Argo CD ApplicationSet → Argo Rollout on Minikube
```

## Learning goals

- Configure Argo Events to receive GitHub pushes via Smee.io.
- Author a Workflow that builds an image (Kaniko), pushes it to GitHub Container Registry (GHCR), and commits a Helm values update.
- Use Argo CD + ApplicationSet to continuously deliver the chart as an Argo Rollout to multiple namespaces.
- Observe progressive delivery behavior with the Argo Rollouts controller.

## Repository map

| Path | Description |
| --- | --- |
| `apps/my-service/Dockerfile` | Minimal NGINX-based image that serves `app/index.html`. |
| `apps/my-service/helm/` | Helm chart that renders an `argoproj.io/v1alpha1` Rollout plus Service. |
| `argocd/` | Root Application and ApplicationSet manifests for Argo CD. |
| `argo-events/event-source.yaml` | GitHub webhook EventSource that listens for repo push events. |
| `argo-events/sensor.yaml` | Sensor that triggers the workflow template from push events. |
| `argo-events/smee-relay-deployment.yaml` | Smee relay deployment that forwards GitHub webhooks into the EventSource service. |
| `argo-events/workflow-trigger-rbac.yaml` | RBAC letting the Argo Events service account submit workflows in `cicd`. |
| `argo-workflows/controller-namespace-rbac.yaml` | RBAC so the Argo Workflows controller in `argo` can manage resources in `cicd`. |
| `apps/smee-relay/Dockerfile` | Build context for the lightweight Smee relay container image. |

The Helm chart already ships with a canary Rollout (`apps/my-service/helm/templates/rollout.yaml`). Argo CD points at `apps/my-service/helm` and uses the correct environment specific `values-*.yaml` files.

---

## Prerequisites

- macOS/Linux shell with `kubectl`, `helm`, `minikube`, `docker` (or another container runtime), and `jq`.
- `argo` CLI (`brew install argo`; verify with `argo version`).
- `kubectl argo rollouts` plugin (`brew install argoproj/tap/kubectl-argo-rollouts`; verify with `kubectl argo rollouts version`).
- GitHub personal access token (PAT) with `repo`, `workflow`, and `write:packages` scopes.
- GitHub Container Registry (GHCR) repository such as `${GHCR_REPO}`.
- Permission to build and push the Smee relay image defined in `apps/smee-relay/Dockerfile` (publishing to GHCR keeps everything in one registry).
- Fork of this repo so the workflow can push commits.

> All commands assume the repo is cloned to `~/github/lab24-argo-cicd`, Minikube is the current kube-context, and you have network access to download controller manifests. Adjust paths and versions to your environment.

### Helper environment variables

Export the variables below once per shell so you do not have to edit every command:

```bash
export GITHUB_USER="<github-user>"
export GITHUB_EMAIL="<user@example.com>"
export GITHUB_TOKEN="<github-personal-access-token>"
export GHCR_REPO="ghcr.io/${GITHUB_USER}/lab24-rollouts"
export SMEE_RELAY_IMAGE="ghcr.io/${GITHUB_USER}/smee-relay:latest"
export GIT_REMOTE="github.com/${GITHUB_USER}/lab24-argo-cicd.git"
```
---

## 1. Boot Minikube and install the Argo controllers

```bash
minikube start --kubernetes-version=v1.29.0 --cpus=4 --memory=8192

# Namespaces
kubectl create namespace argocd
kubectl create namespace argo-events
kubectl create namespace argo-rollouts
kubectl create namespace argo
kubectl create namespace cicd        # workflows live here
```

Install the controllers (pin the versions appropriate for your cluster):

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -n argo -f https://github.com/argoproj/argo-workflows/releases/latest/download/install.yaml
kubectl apply -n argo-events -f https://github.com/argoproj/argo-events/releases/latest/download/install.yaml
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

> Tip: install the `kubectl argo rollouts` plugin so you can inspect rollout status easily:
> ```bash
> brew install argoproj/tap/kubectl-argo-rollouts
> kubectl argo rollouts version
> ```

---

## 2. Prepare service accounts, roles, and secrets

### 2.1 Service account for workflows

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: workflow-runner
  namespace: cicd
imagePullSecrets:
  - name: ghcr-creds
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: workflow-role
  namespace: cicd
rules:
  - apiGroups: [""]
    resources: [pods, pods/log, pods/exec, persistentvolumeclaims, configmaps, secrets]
    verbs: [create, update, patch, delete, get, list, watch]
  - apiGroups: ["argoproj.io"]
    resources: [workflows, workflowtemplates, clusterworkflowtemplates, workflowtaskresults]
    verbs: [create, update, patch, delete, get, list, watch]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: workflow-rolebinding
  namespace: cicd
subjects:
  - kind: ServiceAccount
    name: workflow-runner
    namespace: cicd
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: workflow-role
EOF
```

### 2.2 Registry and Git secrets

```bash
# Docker config for GHCR (fills pull secrets for Kaniko)
kubectl create secret docker-registry ghcr-creds \
  --namespace cicd \
  --docker-server=ghcr.io \
  --docker-username="$GITHUB_USER" \
  --docker-password="$GITHUB_TOKEN"

# Git identity for committing values.yaml changes
kubectl create secret generic github-token \
  --namespace cicd \
  --from-literal=username="$GITHUB_USER" \
  --from-literal=email="workflow@example.com" \
  --from-literal=token="$GITHUB_TOKEN"

# Shared secret used by GitHub webhook + Argo Events (generate once and reuse)
WEBHOOK_SECRET=$(openssl rand -hex 32)
kubectl create secret generic github-webhook-secret \
  --namespace argo-events \
  --from-literal=token="$WEBHOOK_SECRET"
```

> Keep the Git automation email at `workflow@example.com` so workflow-authored commits are easy to recognize (and can be filtered later if you choose). The workflow still labels its commits with a `[workflow]` prefix, but change detection happens inside the workflow by diffing `apps/my-service/app/`.

### 2.3 Allow the Argo Workflows controller to operate in `cicd`

```bash
kubectl apply -f argo-workflows/controller-namespace-rbac.yaml
```

This grants the `argo-workflow-controller` service account (used by the controller running in the `argo` namespace) permission to read secrets and manage workflow pods in `cicd`. If you renamed the controller service account, update the manifest accordingly.

---

## 3. Author the WorkflowTemplate

The template below uses Kaniko to build/push the container image straight from the Git repo and then patches `apps/my-service/helm/values.yaml` to reflect the new image tag before committing back to `main`.

Save as `argo-workflows/workflow-template.yaml` and apply it directly (do **not** run `envsubst`; the script section intentionally contains shell variables such as `$RESULT_FILE` that would be wiped out by premature substitution):

```bash
kubectl apply -f argo-workflows/workflow-template.yaml
```

```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: git-build-push
  namespace: cicd
spec:
  serviceAccountName: workflow-runner
  entrypoint: main
  templates:
    - name: main
      steps:
        - - name: detectchanges
            template: detectchanges
            arguments:
              parameters:
                - name: gitrepo
                  value: "{{workflow.parameters.gitrepo}}"
                - name: gitrevision
                  value: "{{workflow.parameters.gitrevision}}"
                - name: gitbefore
                  value: "{{workflow.parameters.gitbefore}}"
                - name: watchpath
                  value: "{{workflow.parameters.watchpath}}"
        - - name: build_image
            template: build_image
            when: "{{steps.detectchanges.outputs.parameters.should_build}} == 'true'"
        - - name: update_values
            template: update_values
            when: "{{steps.detectchanges.outputs.parameters.should_build}} == 'true'"
    - name: detectchanges
      inputs:
        parameters:
          - name: gitrepo
          - name: gitrevision
          - name: gitbefore
          - name: watchpath
      script:
        image: alpine:3.19
        command: [sh]
        source: |
          set -euo pipefail
          apk add --no-cache git
          git clone "{{inputs.parameters.gitrepo}}" repo >&2
          cd repo
          ZERO_SHA="0000000000000000000000000000000000000000"
          TARGET="$(printf %s \"{{inputs.parameters.gitrevision}}\" | tr -d '\r')"
          BEFORE="$(printf %s \"{{inputs.parameters.gitbefore}}\" | tr -d '\r')"
          watchpath="{{inputs.parameters.watchpath}}"
          git fetch origin --tags >&2 || true
          if [ -z "$TARGET" ] || [ "$TARGET" = "$ZERO_SHA" ]; then
            TARGET="$(git rev-parse origin/HEAD)"
          else
            git fetch origin "$TARGET" >&2 || true
          fi
          git checkout "$TARGET" >&2 || true
          if [ -z "$BEFORE" ] || [ "$BEFORE" = "$ZERO_SHA" ]; then
            if git rev-parse "${TARGET}^" >/dev/null 2>&1; then
              BEFORE="$(git rev-parse "${TARGET}^")"
            else
              printf true
              exit 0
            fi
          fi
          if git diff --name-only "$BEFORE" "$TARGET" -- "$watchpath" | grep -q .; then
            printf true > /tmp/should-build
          else
            printf false > /tmp/should-build
          fi
      outputs:
        parameters:
          - name: should_build
            valueFrom:
              path: /tmp/should-build
    - name: build_image
      inputs:
        parameters:
          - name: gitrepo
          - name: gitrevision
          - name: imagename
          - name: imagetag
        artifacts:
          - name: source
            path: /workspace/src
            git:
              repo: "{{inputs.parameters.gitrepo}}"
              revision: "{{inputs.parameters.gitrevision}}"
      container:
        image: gcr.io/kaniko-project/executor:v1.16.0
        args:
          - "--context=dir:///workspace/src/apps/my-service"
          - "--destination={{inputs.parameters.imagename}}:{{inputs.parameters.imagetag}}"
          - "--dockerfile=Dockerfile"
          - "--snapshotMode=redo"
          - "--cleanup"
        volumeMounts:
          - name: docker-config
            mountPath: /kaniko/.docker
      volumes:
        - name: docker-config
          secret:
            secretName: ghcr-creds
            items:
              - key: .dockerconfigjson
                path: config.json
    - name: update_values
      inputs:
        parameters:
          - name: gitrepo
          - name: gitrevision
          - name: imagename
          - name: imagetag
      script:
        image: alpine:3.19
        command: [sh]
        env:
          - name: GITHUB_USER
            valueFrom:
              secretKeyRef:
                name: github-token
                key: username
          - name: GITHUB_TOKEN
            valueFrom:
              secretKeyRef:
                name: github-token
                key: token
        source: |
          set -euo pipefail
          apk add --no-cache git yq
          git clone "{{inputs.parameters.gitrepo}}" repo
          cd repo
          git checkout "{{inputs.parameters.gitrevision}}"
          yq -i ".image.repository = \"{{inputs.parameters.imagename}}\"" apps/my-service/helm/values.yaml
          yq -i ".image.tag = \"{{inputs.parameters.imagetag}}\"" apps/my-service/helm/values.yaml
          # Ensure git identity is always set even if secrets are blank
          git config user.name "${GITHUB_USER}"
          git config user.email "workflow@example.com"
          git commit -am "[workflow] update rollout image to {{inputs.parameters.imagetag}}"
          REMOTE_URL="{{inputs.parameters.gitrepo}}"
          REMOTE_HOST_PATH="${REMOTE_URL#https://}"
          git remote set-url origin "https://${GITHUB_USER}:${GITHUB_TOKEN}@${REMOTE_HOST_PATH}"
          git push origin HEAD:main
```

> The template assumes you always push to `main`. Use Workflow parameters if you need branch-specific behavior, and keep automation credentials exclusively in Kubernetes secrets (the workflow never needs pre-rendered `${...}` placeholders).

---

## 4. Configure Argo Events + in-cluster Smee relay

The repo now includes `argo-events/event-source.yaml`, `argo-events/smee-relay-deployment.yaml`, and `argo-events/sensor.yaml`. The Smee relay runs as its own deployment in the `argo-events` namespace and forwards GitHub webhook traffic into the EventSource service—no manual port-forwarding required.

1. Browse to [https://smee.io](https://smee.io) and click **Start a new channel**. Copy the unique HTTPS URL (e.g. `https://smee.io/abc123`).
2. In your GitHub fork open **Settings → Webhooks** and add a webhook:
   - Payload URL: `https://smee.io/abc123`
   - Content type: `application/json`
   - Secret: the same value stored in `github-webhook-secret`.
   - Select **Just the push event**.
   - After saving the webhook, store the relay URL in the cluster so the relay deployment can read it:
     ```bash
     kubectl create secret generic smee-relay-url \
       --namespace argo-events \
       --from-literal=url=https://smee.io/abc123
     ```
3. Build and push the relay image:
   ```bash
   export SMEE_RELAY_IMAGE="ghcr.io/${GITHUB_USER}/smee-relay:latest"
   docker build -t "$SMEE_RELAY_IMAGE" apps/smee-relay
   docker push "$SMEE_RELAY_IMAGE"
   ```
   > Publish the repository (e.g., `ghcr.io/chance2021/smee-relay:latest`) as **public** in GitHub Packages so your cluster can pull it without extra credentials and your local builds can `docker pull` it for verification.
4. Edit `argo-events/smee-relay-deployment.yaml` so the image reference matches `$SMEE_RELAY_IMAGE` (and adjust the secret name if needed). Update `argo-events/sensor.yaml` so the hard-coded `gitrepo` parameter points at your fork (e.g., `https://github.com/${GITHUB_USER}/lab24-argo-cicd.git`) and the `imagename` parameter matches your `$GHCR_REPO` value if it still points at the example repo.
5. Grant the Argo Events service account permission to submit workflows in `cicd`:
   ```bash
   kubectl apply -f argo-events/workflow-trigger-rbac.yaml
   ```
6. Apply the remaining manifests (including the default EventBus and relay deployment the EventSource expects):
   ```bash
   kubectl apply -f argo-events/event-bus.yaml
   kubectl apply -f argo-events/event-source.yaml
   kubectl apply -f argo-events/smee-relay-deployment.yaml
   kubectl apply -f argo-events/sensor.yaml
   ```

> The Smee relay deployment reads the channel URL from the `smee-relay-url` secret and proxies to `http://github-webhook-eventsource.argo-events.svc.cluster.local:12000/payload`, which is the EventSource service inside the cluster. If you change the EventSource port or endpoint, update the `SMEE_TARGET` env var in `apps/smee-relay/Dockerfile` and `argo-events/smee-relay-deployment.yaml` accordingly. Update `serviceAccountName` in the manifests if you already have dedicated accounts inside `argo-events`, and tweak the Sprig `substr` call in the sensor if you prefer full commit SHAs.
>
> The sensor now forwards every GitHub push; the workflow decides whether to proceed via the `detect-changes` step (it diffs the previous commit against the current one and short-circuits the build if `apps/my-service/app/` didn’t change). Update `argo-events/sensor.yaml` and the workflow template together if you want different filtering behavior.

---

## 5. Bootstrap Argo CD and the ApplicationSet

Update `argocd/root-app-appsets.yaml` and `argocd/applicationsets/my-service-applicationset.yaml` so `repoURL` points to **your fork** (and adjust `targetRevision` if needed).

```bash
kubectl apply -f argocd/root-app-appsets.yaml
```

Argo CD now renders the ApplicationSet, which creates one Application per environment (`dev`, `staging`, `prod`) and deploys the Helm chart. Because the chart renders an Argo Rollout, you can watch the progressive update when a new image tag is committed.

---

## 6. Run the lab

1. Commit and push a change to your fork (anything—`README` tweaks work) so GitHub fires a push event.
2. Confirm the webhook is delivered by watching the EventSource pod logs (and optionally the standalone `smee-relay` deployment). The sensor should immediately submit a workflow:
   ```bash
   kubectl -n argo-events logs deploy/github-webhook-eventsource | tail
   kubectl -n argo-events logs deploy/smee-relay | tail
   argo -n cicd list
   argo -n cicd get <workflow-name>
   ```
3. When the workflow finishes, Argo CD detects the changed `values.yaml` (new `image.tag`) and performs an automated sync.
4. Watch the rollout (ApplicationSet renders rollouts named `my-service-<env>-hello-world`):
   ```bash
   kubectl argo rollouts get rollout my-service-dev-hello-world -n my-service-dev --watch
   ```
   When the rollout pauses (due to the canary steps), approve the promotion to continue:
   ```bash
   kubectl argo rollouts promote my-service-dev-hello-world -n my-service-dev
   ```
5. Port-forward to the service to see the HTML page served by the updated image.
   The landing page includes a `Current version` banner plus a reminder to edit something under `apps/my-service/app/` (for example, `index.html`)—change that text, push to GitHub, and watch a new rollout happen end-to-end. If your push doesn’t touch that directory the workflow’s change-detection step will exit early and skip the build.

If anything fails, inspect the workflow pod logs (`argo -n cicd logs -w <workflow-name> -s build_image`), and double-check that your secrets and template parameters match your fork and GHCR repository.

---

## 7. Cleanup

```bash
kubectl delete -f argo-events/sensor.yaml
kubectl delete -f argo-events/event-source.yaml
kubectl delete -f argo-events/workflow-trigger-rbac.yaml
kubectl delete -f argo-events/smee-relay-deployment.yaml
kubectl delete secret smee-relay-url -n argo-events
kubectl delete -f argo-workflows/controller-namespace-rbac.yaml
kubectl delete -f argocd/root-app-appsets.yaml
kubectl delete workflowtemplates.argoproj.io/git-build-push -n cicd
minikube delete
```

---

## 8. Verify end-to-end deployment

1. Make a simple change under `apps/my-service/app/` (for example, edit `apps/my-service/app/index.html` so the page text clearly differs) and push it to your fork's `main` branch. The workflow inspects the diff and skips builds if that directory didn’t change, so modify something there to see the full pipeline.
2. Watch the workflow that the GitHub push triggers and ensure the new image tag reaches GHCR:
   ```bash
   argo -n cicd list
   argo -n cicd watch @latest
   ```
3. After the workflow completes, confirm Argo CD synced the change and that the Rollout in Minikube switched to the freshly built image:
   ```bash
   kubectl argo rollouts get rollout my-service-dev-hello-world -n my-service-dev --watch
   ```
   Approve the rollout when it pauses per the canary steps:
   ```bash
   kubectl argo rollouts promote my-service-dev-hello-world -n my-service-dev
   ```
4. Port-forward the service (`kubectl -n my-service-dev port-forward svc/my-service 8080:80`) and browse `http://localhost:8080` to see the updated page being served from the new container image.
   The page shows the current version string; when your change deploys you’ll see the new text immediately.

This verification round-trip proves the webhook, EventSource, Workflow, Argo CD, and Rollout all work together to deploy new code onto Minikube automatically.

---

## Troubleshooting tips

- **Workflow cannot push to GHCR**: re-create `ghcr-creds` secret; confirm PAT has `write:packages`. Use `kubectl get secret ghcr-creds -n cicd -o yaml` to verify base64 data exists.
- **Workflow fails to push to GitHub**: ensure `github-token` secret contains `username`, `email`, and `token` keys. Token must allow `repo` scope.
- **Workflow keeps recreating**: the sensor now forwards every push, so expect a lightweight workflow to run for automation commits too (it exits before `build_image` because the diff has no app changes). If you want to drop these entirely, add a filter back in `argo-events/sensor.yaml` (e.g., ignore `workflow@example.com`) or adjust the `detect-changes` step.
- **Workflow fails to build context**: confirm the git artifact is mounted and the Kaniko context points to the service directory (`dir:///workspace/src/apps/my-service`). See `argo-workflows/workflow-template.yaml`.
- **WorkflowTemplate script variables become empty**: avoid running `envsubst` on `workflow-template.yaml`—it will replace script-internal variables such as `$RESULT_FILE`, `$TARGET`, etc., causing the detect-changes step to malfunction. Apply the manifest directly and rely on Kubernetes secrets/parameters for sensitive data.
- **Workflow cannot create workflowtaskresults**: verify the `workflow-runner` Role in `cicd` includes the `workflowtaskresults` resource under the `argoproj.io` API group.
- **Sensor does not trigger**: check `kubectl -n argo-events get eventsources,sensors,pods`. Describe the sensor to see last event.
- **Rollout stuck**: use `kubectl argo rollouts analyze ...` or check pods in the target namespace. Remember Argo Rollouts requires the CRD installed cluster-wide.

Enjoy experimenting with the full Argo toolchain!

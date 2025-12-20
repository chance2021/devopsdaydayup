# Lab 9 — Deploy Jenkins on Minikube with Helm (plus packaging your own chart)

Deploy the official Jenkins Helm chart onto Minikube, then package and host your own chart via GitHub Pages.

> Use placeholders for any credentials. Do not commit real passwords.

## Prerequisites

- Ubuntu 20.04 host (>= 2 vCPU, 8 GB RAM)
- Docker, Docker Compose
- Minikube installed and running
- Helm v3 installed

## Part A: Deploy Jenkins with Helm

1) Start Minikube and set kubectl alias
```bash
minikube start
minikube status
alias k="kubectl"
```

2) Install Helm (if needed)
```bash
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```

3) Add the Jenkins chart repo
```bash
helm repo add jenkins https://charts.jenkins.io
helm repo update
```

4) Install the Jenkins chart
```bash
helm install jenkins jenkins/jenkins
```

5) Access Jenkins
```bash
k get pod
kubectl --namespace default port-forward svc/jenkins 8080:8080
```
Open `http://127.0.0.1:8080` and fetch the admin password:
```bash
kubectl exec --namespace default -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo
```

## Part B: Package and host your own Helm chart

1) Create a repo and a chart
```bash
mkdir helm-charts
cd helm-charts
helm create test-service
```

2) Package the chart
```bash
helm package test-service
```

3) Create an index and move artifacts to `docs/`
```bash
helm repo index --url https://<YOUR_GITHUB_USER>.github.io/<REPO_NAME> ./
mkdir -p ../docs
mv index.yaml test-service-0.1.0.tgz ../docs
```

4) Commit and push to GitHub
```bash
cd ..
git add docs helm-charts
git commit -m "Add test-service helm chart"
git push
```

5) Enable GitHub Pages

- In the repo settings, set **Pages** to serve from branch `main`, folder `/docs`.

6) Install your chart from GitHub Pages
```bash
helm repo add myrepo https://<YOUR_GITHUB_USER>.github.io/<REPO_NAME>
helm repo update
helm install test-service myrepo/test-service
```

## Validation

- `k get pods` shows Jenkins running; port-forwarding opens Jenkins UI.
- `helm list` shows `jenkins` and `test-service` releases deployed.
- `helm repo list` includes your GitHub Pages repo and `helm show chart myrepo/test-service` works.

## Cleanup

```bash
minikube delete
```

## Troubleshooting

- **Pod not running**: Check `kubectl describe pod <pod>` for image pull or PVC issues.
- **Port-forward fails**: Ensure the service name matches and port 8080 is free locally.
- **GitHub Pages 404**: Confirm `docs/index.yaml` and chart tarball are committed, and Pages is enabled on `/docs`.

## References

- https://minikube.sigs.k8s.io/docs/start/
- https://helm.sh/docs/intro/install/
- https://charts.jenkins.io

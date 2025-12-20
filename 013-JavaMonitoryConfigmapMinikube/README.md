# Lab 13 — Java App Monitoring ConfigMap Changes on Minikube

Build and run a Java app that watches a ConfigMap-mounted file (symlink) in Kubernetes and logs when content changes.

## Prerequisites

- Ubuntu 20.04 host (>= 2 vCPU, 8 GB RAM)
- Docker, Docker Compose
- Minikube running
- JDK/Maven (for building) or Docker to build the image

## Setup

1) Start Minikube and set kubectl alias
```bash
minikube start
alias k="kubectl"
```

2) Build the image inside Minikube’s Docker daemon
```bash
git clone https://github.com/chance2021/devopsdaydayup.git
cd devopsdaydayup/013-JavaMonitoryConfigmapMinikube
eval $(minikube docker-env)
docker build -t java-monitor-file:v2.0 .
```

3) Deploy ConfigMap and Pod
```bash
kubectl apply -f configmap.yaml
kubectl apply -f pod.yaml
```

4) Validate change detection

- Stream logs:
  ```bash
  kubectl logs -f configmap-demo-pod
  ```
- In another terminal, edit the ConfigMap:
  ```bash
  kubectl edit cm game-demo
  ```
  Modify `data.game.properties` and save. Within ~1 minute logs show:
  ```
  Content has changed!
  ```

> The app reads the symlinked file path created by the ConfigMap mount. Adjust `spec.containers.args` in `pod.yaml` to watch a different path if needed.

## Cleanup

```bash
minikube stop
```

## Troubleshooting

- **No change detected**: Ensure you edit the ConfigMap data, not the mounted file inside the pod. Wait for the ConfigMap update to propagate (typically under a minute).
- **Image not found**: Verify `eval $(minikube docker-env)` was run before `docker build`, or push the image to a registry Minikube can access.

## References

- https://kubernetes.io/docs/concepts/configuration/configmap/
- https://minikube.sigs.k8s.io/docs/handbook/pushing/

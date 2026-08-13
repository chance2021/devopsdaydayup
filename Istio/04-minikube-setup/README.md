# Module 04: Minikube Setup

> **Why this matters**: You need a local Kubernetes cluster to practice all Istio labs. Minikube is the simplest way to get one running on macOS.

## Table of Contents
- [Install Minikube](#install-minikube)
- [Configure Minikube for Istio](#configure-minikube-for-istio)
- [Verify the Cluster](#verify-the-cluster)
- [Useful Minikube Commands](#useful-minikube-commands)
- [Troubleshooting](#troubleshooting)

---

## Install Minikube

### macOS
```bash
# Install using Homebrew
brew install minikube

# Also install kubectl if not already
brew install kubectl

# Verify installation
minikube version
kubectl version --client
```

### Linux
```bash
# Download minikube binary
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Verify
minikube version
```

---

## Configure Minikube for Istio

Istio requires more resources than a default Minikube cluster. Here's the recommended setup:

```bash
#!/bin/bash
# setup-minikube.sh — Set up Minikube for Istio labs

echo "=== Setting Up Minikube for Istio ==="

# Step 1: Delete any existing cluster
minikube delete 2>/dev/null

# Step 2: Start with recommended resources
# - 4 CPUs: Istio control plane + sample apps
# - 8GB RAM: istiod + Envoy sidecars + observability stack
# - docker driver: Best for macOS (no hypervisor needed)
# - kubernetes v1.28+: Required for latest Istio
echo "[Step 1] Starting Minikube..."
minikube start \
  --cpus=4 \
  --memory=8192 \
  --driver=docker \
  --kubernetes-version=v1.28.0 \
  --addons=metrics-server,dashboard

# Step 3: Verify the cluster
echo "[Step 2] Verifying cluster..."
kubectl cluster-info
kubectl get nodes -o wide

# Step 4: Enable metrics-server (needed for HPA labs)
echo "[Step 3] Enabling addons..."
minikube addons enable metrics-server

# Step 5: Verify networking
echo "[Step 4] Verifying networking..."
kubectl run test-pod --image=busybox:1.36 --restart=Never --rm -it -- \
  sh -c 'echo "Pod networking works!"; wget -qO- https://kubernetes.default.svc/api --no-check-certificate 2>/dev/null | head -1 || echo "API reachable"' 2>/dev/null

echo ""
echo "=== Minikube is Ready for Istio! ==="
echo "Cluster IP: $(minikube ip)"
echo "Dashboard:  minikube dashboard"
echo ""
echo "Next step: Install Istio (Module 05)"
```

### Multi-Node Cluster (for advanced labs)

For multi-cluster and locality-aware routing labs, you may need multiple nodes:

```bash
# Start minikube with 3 nodes
minikube start \
  --cpus=4 \
  --memory=8192 \
  --driver=docker \
  --nodes=3

# Label nodes with topology zones (for Module 13)
kubectl label node minikube topology.kubernetes.io/zone=us-east-1a
kubectl label node minikube-m02 topology.kubernetes.io/zone=us-east-1b
kubectl label node minikube-m03 topology.kubernetes.io/zone=us-east-1c
```

---

## Verify the Cluster

```bash
# Check node status
kubectl get nodes

# Check system pods
kubectl get pods -n kube-system

# Check DNS is working
kubectl run dns-check --image=busybox:1.36 --restart=Never --rm -it -- nslookup kubernetes

# Check dashboard (opens in browser)
minikube dashboard
```

---

## Useful Minikube Commands

```bash
# Get cluster IP
minikube ip

# SSH into the minikube VM/container
minikube ssh

# Access a LoadBalancer service (creates a tunnel)
minikube tunnel

# Pause/unpause cluster (saves resources)
minikube pause
minikube unpause

# Stop/start (preserves state)
minikube stop
minikube start

# Delete cluster completely
minikube delete

# Check minikube status
minikube status

# View minikube logs (for debugging)
minikube logs

# Access a NodePort service
minikube service <service-name>

# Mount local directory into minikube
minikube mount /local/path:/minikube/path
```

---

## Troubleshooting

### Not Enough Resources
```
Error: Exiting due to RSRC_INSUFFICIENT_MEMORY

Fix: Increase Docker Desktop memory allocation:
  Docker Desktop → Settings → Resources → Memory → 10GB+
```

### Docker Driver Issues
```
Error: docker is not running

Fix:
  1. Start Docker Desktop
  2. Wait for it to fully initialize
  3. Verify: docker ps
```

### DNS Not Working
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Restart CoreDNS
kubectl rollout restart deployment coredns -n kube-system
```

### Clean Restart
```bash
# Nuclear option — delete everything and start fresh
minikube delete --all --purge
minikube start --cpus=4 --memory=8192 --driver=docker
```

---

## Next Module

Continue to [Module 05: Istio Installation & Architecture →](../05-istio-installation-architecture/)

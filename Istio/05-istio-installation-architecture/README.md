# Module 05: Istio Installation & Architecture

> **Why this matters**: Before you can operate Istio at scale, you must understand the architecture. Every component has a role, and at 1M pods, each component becomes a potential bottleneck. This module covers what each component does, how they interact, and how to install Istio properly.

## Table of Contents
- [Theory: Istio Architecture](#theory-istio-architecture)
- [Theory: Control Plane Deep Dive (istiod)](#theory-control-plane-deep-dive-istiod)
- [Theory: Data Plane (Envoy Sidecar)](#theory-data-plane-envoy-sidecar)
- [Theory: Installation Methods](#theory-installation-methods)
- [Theory: Profiles](#theory-profiles)
- [Theory: Sidecar Injection](#theory-sidecar-injection)
- [Lab: Install Istio](#lab-install-istio)
- [Lab: Deploy Bookinfo](#lab-deploy-bookinfo)

---

## Theory: Istio Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                        CONTROL PLANE                                  │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │                         istiod                                  │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐  │  │
│  │  │  Pilot    │  │ Citadel   │  │  Galley   │  │  Sidecar     │  │  │
│  │  │ (xDS)     │  │ (CA/certs)│  │ (config   │  │  Injector    │  │  │
│  │  │           │  │           │  │  validate) │  │  (webhook)   │  │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────────┘  │  │
│  └────────────────────────┬───────────────────────────────────────┘  │
│                           │  xDS (gRPC)                              │
├───────────────────────────┼──────────────────────────────────────────┤
│                     DATA PLANE                                        │
│                           │                                           │
│  ┌─────────────────┐  ┌──┴──────────────┐  ┌──────────────────┐    │
│  │ Pod A            │  │ Pod B            │  │ Pod C             │   │
│  │ ┌─────┐┌──────┐ │  │ ┌─────┐┌──────┐ │  │ ┌─────┐┌──────┐  │   │
│  │ │ App ││Envoy │ │  │ │ App ││Envoy │ │  │ │ App ││Envoy │  │   │
│  │ └─────┘└──────┘ │  │ └─────┘└──────┘ │  │ └─────┘└──────┘  │   │
│  └─────────────────┘  └─────────────────┘  └──────────────────┘    │
│                                                                       │
│  All Envoy sidecars receive config from istiod via xDS                │
│  All traffic between pods goes through the Envoy sidecars             │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Theory: Control Plane Deep Dive (istiod)

**istiod** is a single binary that combines what used to be 3 separate components (Pilot, Citadel, Galley). Understanding each function is crucial.

### Pilot (Service Discovery & Configuration)
**What it does**: Converts Istio configuration (VirtualService, DestinationRule, etc.) into Envoy-native configuration and pushes it to all sidecars via xDS.

```
Kubernetes API → Pilot watches for:
  - Services / Endpoints (service discovery)
  - VirtualService (routing rules)
  - DestinationRule (load balancing, circuit breaking)
  - Gateway (ingress configuration)
  - ServiceEntry (external service registration)
  - Sidecar (egress scope limits)
  - AuthorizationPolicy, PeerAuthentication, etc.

Pilot converts these to:
  - LDS (Listeners) — what ports to listen on
  - RDS (Routes) — how to route requests
  - CDS (Clusters) — upstream service definitions
  - EDS (Endpoints) — actual pod IP:port lists
  - SDS (Secrets) — TLS certificates

Pilot pushes via xDS (gRPC) to every connected Envoy
```

**Scale concern**: At 1M pods, Pilot must push config to 1M Envoy instances. Config size per proxy matters enormously — this is why the `Sidecar` resource exists (Module 15).

### Citadel (Certificate Authority)
**What it does**: Issues and rotates mTLS certificates for every workload in the mesh.

```
Pod starts → Envoy sends CSR via SDS
  → istiod validates identity (K8s TokenReview API)
    → istiod signs certificate (SPIFFE format)
      → Returns cert + key via SDS gRPC stream
        → Envoy uses cert for mTLS
          → Auto-rotated before expiry (default 24h TTL)
```

**Scale concern**: At 1M pods, Citadel handles 1M certificate issuances at startup + continuous rotation. High CSR rate during rolling deployments.

### Galley (Configuration Validation)
**What it does**: Validates Istio custom resources before they're applied. Runs as a Kubernetes ValidatingWebhookConfiguration.

```
kubectl apply -f virtual-service.yaml
  → K8s API server calls Galley webhook
    → Galley validates the config
      → Accept or reject with error message
```

### Sidecar Injector (Mutating Webhook)
**What it does**: Automatically injects Envoy sidecar containers into pods.

```
kubectl apply -f deployment.yaml (in a namespace with istio-injection=enabled)
  → K8s API server calls sidecar injector webhook
    → Injector adds two containers to the pod spec:
      1. istio-init (init container) — sets up iptables rules
      2. istio-proxy (sidecar) — the Envoy proxy
    → Modified pod spec is stored in etcd
      → Pod starts with sidecar
```

---

## Theory: Data Plane (Envoy Sidecar)

Every pod in the mesh gets two additional containers:

### 1. `istio-init` (Init Container)
- Runs BEFORE the application container
- Sets up iptables rules to intercept all inbound/outbound traffic
- Requires `NET_ADMIN` capability (or use Istio CNI to avoid this)
- Exits after setup (not a long-running container)

### 2. `istio-proxy` (Sidecar Container)
- The Envoy proxy itself
- Runs alongside the application container
- Shares the pod's network namespace
- Listens on several ports:
  - `15001` — Outbound traffic listener
  - `15006` — Inbound traffic listener
  - `15090` — Prometheus metrics endpoint
  - `15021` — Health check endpoint
  - `15000` — Envoy admin interface

```
┌───────────────────────────────────────┐
│              Pod Spec                  │
│                                        │
│  initContainers:                       │
│  - name: istio-init                    │
│    image: istio/proxyv2:1.20           │
│    args: ["istio-iptables", ...]       │
│    securityContext:                     │
│      capabilities:                     │
│        add: ["NET_ADMIN", "NET_RAW"]   │
│                                        │
│  containers:                           │
│  - name: my-app        ← Your app     │
│    image: my-app:v1                    │
│    ports:                              │
│    - containerPort: 8080               │
│                                        │
│  - name: istio-proxy   ← Envoy        │
│    image: istio/proxyv2:1.20           │
│    ports:                              │
│    - containerPort: 15001              │
│    - containerPort: 15006              │
│    - containerPort: 15090              │
│    - containerPort: 15021              │
│    env:                                │
│    - name: ISTIO_META_CLUSTER_ID       │
│      value: "Kubernetes"               │
│    volumeMounts:                       │
│    - name: istio-token                 │
│      mountPath: /var/run/secrets/...   │
└───────────────────────────────────────┘
```

---

## Theory: Installation Methods

### Method 1: `istioctl install` (Recommended for Learning)
```bash
# Install with a profile
istioctl install --set profile=demo -y

# Customize with IstioOperator spec
istioctl install -f my-config.yaml -y
```

### Method 2: Helm (Recommended for Production/GitOps)
```bash
# Add Istio repo
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# Install in order: base → istiod → gateway
helm install istio-base istio/base -n istio-system --create-namespace
helm install istiod istio/istiod -n istio-system --wait
helm install istio-ingress istio/gateway -n istio-ingress --create-namespace
```

### Method 3: Istio Operator (Declarative)
```yaml
# istio-operator.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: istio-control-plane
  namespace: istio-system
spec:
  profile: default
  meshConfig:
    accessLogFile: /dev/stdout
    defaultConfig:
      holdApplicationUntilProxyStarts: true
  components:
    pilot:
      k8s:
        resources:
          requests:
            cpu: 500m
            memory: 2Gi
        hpaSpec:
          minReplicas: 2
          maxReplicas: 10
```

---

## Theory: Profiles

Istio ships with pre-configured profiles for different use cases:

| Profile | istiod | Ingress GW | Egress GW | Use Case |
|---------|--------|-----------|-----------|----------|
| `default` | ✅ | ✅ | ❌ | Production |
| `demo` | ✅ | ✅ | ✅ | Learning (all features) |
| `minimal` | ✅ | ❌ | ❌ | Control plane only |
| `ambient` | ✅ | ✅ | ❌ | Ambient mesh (no sidecar) |
| `empty` | ❌ | ❌ | ❌ | Base for custom config |

```bash
# See what a profile contains
istioctl profile dump demo

# Diff two profiles
istioctl profile diff default demo
```

---

## Theory: Sidecar Injection

### Automatic Injection (Recommended)
```bash
# Label a namespace
kubectl label namespace default istio-injection=enabled

# ALL new pods in this namespace will automatically get sidecars
kubectl apply -f deployment.yaml  # Sidecar auto-injected!
```

### Per-Pod Override
```yaml
# Disable injection for a specific pod
metadata:
  annotations:
    sidecar.istio.io/inject: "false"
```

### Manual Injection
```bash
# Inject into a YAML file manually
istioctl kube-inject -f deployment.yaml | kubectl apply -f -
```

### Revision-Based Injection (for upgrades)
```bash
# Use a specific Istio revision
kubectl label namespace default istio.io/rev=1-20
```

---

## Lab: Install Istio

```bash
#!/bin/bash
# install-istio.sh — Install Istio on Minikube

echo "=== Installing Istio ==="

# Step 1: Install istioctl
echo "[Step 1] Installing istioctl..."
brew install istioctl 2>/dev/null || \
  curl -L https://istio.io/downloadIstio | sh -

# Step 2: Verify istioctl
echo "[Step 2] Verifying istioctl..."
istioctl version --remote=false

# Step 3: Pre-check the cluster
echo "[Step 3] Pre-flight check..."
istioctl x precheck

# Step 4: Install with demo profile
echo "[Step 4] Installing Istio (demo profile)..."
istioctl install --set profile=demo -y

# Step 5: Verify installation
echo "[Step 5] Verifying installation..."
kubectl get pods -n istio-system
kubectl get svc -n istio-system

# Step 6: Enable sidecar injection for default namespace
echo "[Step 6] Enabling sidecar injection..."
kubectl label namespace default istio-injection=enabled --overwrite

# Step 7: Verify injection is enabled
echo "[Step 7] Checking namespace labels..."
kubectl get namespace default --show-labels

# Step 8: Install observability addons
echo "[Step 8] Installing addons (Kiali, Jaeger, Prometheus, Grafana)..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

echo "Waiting for addons to be ready..."
kubectl rollout status deployment/kiali -n istio-system --timeout=120s

echo ""
echo "=== Istio Installation Complete! ==="
echo ""
echo "Components installed:"
kubectl get pods -n istio-system
echo ""
echo "Access dashboards:"
echo "  Kiali:      istioctl dashboard kiali"
echo "  Grafana:    istioctl dashboard grafana"
echo "  Jaeger:     istioctl dashboard jaeger"
echo "  Prometheus: istioctl dashboard prometheus"
```

---

## Lab: Deploy Bookinfo

The Bookinfo sample app is Istio's canonical demo. It has 4 microservices with multiple versions — perfect for testing traffic management.

```
┌──────────┐      ┌───────────┐      ┌──────────┐
│          │      │           │      │ Reviews  │
│ Product  │─────→│  Reviews  │─────→│ v1: no   │
│  Page    │      │           │      │    stars  │
│          │      │     ┌─────┤      │ v2: black │
└──────────┘      │     │     │      │    stars  │
                  │     │ Det │      │ v3: red   │
                  │     │ ails│      │    stars  │
                  │     └─────┤      └──────────┘
                  └───────────┘
                        │
                  ┌─────┴─────┐
                  │  Ratings   │
                  │  Service   │
                  └───────────┘
```

```bash
#!/bin/bash
# deploy-bookinfo.sh — Deploy the Bookinfo sample application

echo "=== Deploying Bookinfo ==="

# Step 1: Deploy the application
echo "[Step 1] Deploying Bookinfo..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/platform/kube/bookinfo.yaml

# Step 2: Wait for pods
echo "[Step 2] Waiting for pods..."
kubectl wait --for=condition=ready pod -l app=productpage --timeout=120s
kubectl wait --for=condition=ready pod -l app=reviews --timeout=120s
kubectl wait --for=condition=ready pod -l app=ratings --timeout=120s
kubectl wait --for=condition=ready pod -l app=details --timeout=120s

# Step 3: Verify sidecars are injected (should see 2/2 containers)
echo "[Step 3] Verifying sidecars (expect 2/2 READY):"
kubectl get pods

# Step 4: Verify the app works
echo "[Step 4] Testing the app..."
kubectl exec "$(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}')" \
  -c ratings -- curl -s productpage:9080/productpage | grep -o "<title>.*</title>"

# Step 5: Create the Istio Gateway and VirtualService
echo "[Step 5] Creating Gateway..."
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/bookinfo/networking/bookinfo-gateway.yaml

# Step 6: Get the ingress URL
echo "[Step 6] Getting ingress URL..."
INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')

if [ -z "$INGRESS_HOST" ]; then
  echo "No LoadBalancer IP. Using minikube tunnel..."
  echo "Run 'minikube tunnel' in a separate terminal, then:"
  INGRESS_HOST=$(minikube ip)
  INGRESS_PORT=$(kubectl get svc istio-ingressgateway -n istio-system -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
fi

GATEWAY_URL="${INGRESS_HOST}:${INGRESS_PORT}"
echo "Gateway URL: http://${GATEWAY_URL}/productpage"

# Step 7: Generate some traffic
echo "[Step 7] Generating traffic..."
for i in $(seq 1 10); do
  curl -s -o /dev/null -w "Request $i: HTTP %{http_code}\n" "http://${GATEWAY_URL}/productpage"
done

echo ""
echo "=== Bookinfo Deployed ==="
echo "Open: http://${GATEWAY_URL}/productpage"
echo "Kiali: istioctl dashboard kiali"
echo ""
echo "Inspect sidecar in any pod:"
echo "  kubectl describe pod -l app=productpage"
echo "  istioctl proxy-status"
```

---

## Verification Checklist

```bash
# ✅ istiod is running
kubectl get pods -n istio-system -l app=istiod

# ✅ Ingress gateway is running
kubectl get pods -n istio-system -l app=istio-ingressgateway

# ✅ Sidecar injection is enabled
kubectl get namespace default -L istio-injection

# ✅ All pods have sidecars (2/2 containers)
kubectl get pods

# ✅ Proxy status shows all proxies synced
istioctl proxy-status

# ✅ No configuration errors
istioctl analyze
```

## Next Module

Continue to [Module 06: Sidecar Deep Dive →](../06-sidecar-deep-dive/)

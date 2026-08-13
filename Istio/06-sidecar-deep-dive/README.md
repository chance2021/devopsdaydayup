# Module 06: Sidecar Deep Dive

> **Why this matters**: This is the module that separates Istio users from Istio experts. Understanding how the sidecar works at the iptables level, what the init container does, and the tradeoffs between sidecar, CNI plugin, and ambient mesh is essential for debugging, security hardening, and scaling to 1M pods.

## Table of Contents
- [Part A: The Init Container Explained](#part-a-the-init-container-istio-init-explained)
- [Part B: How the Sidecar Proxy Works](#part-b-how-the-sidecar-proxy-works)
- [Part C: Sidecar vs Istio CNI Plugin](#part-c-sidecar-vs-istio-cni-plugin)
- [Part D: Sidecar vs Ambient Mesh](#part-d-sidecar-vs-ambient-mesh)
- [Lab: Sidecar Inspection](#lab-sidecar-inspection)
- [Lab: Ambient Mesh](#lab-ambient-mesh)

---

## Part A: The Init Container (`istio-init`) Explained

### What `istio-init` Does

When a pod starts in an Istio-injected namespace, an init container called `istio-init` runs BEFORE your application. Its sole job: **set up iptables rules to intercept all traffic**.

```
Pod Startup Sequence:
  1. kubelet creates pod sandbox (network namespace)
  2. CNI plugin sets up network (IP, veth, bridge)
  3. istio-init container runs ← SETS UP IPTABLES HERE
  4. istio-init exits (job done)
  5. istio-proxy (Envoy) starts
  6. Application container starts
```

### The Exact iptables Rules

Here are the EXACT chains and rules `istio-init` creates:

```bash
# =============================================
# NAT TABLE — This is where the magic happens
# =============================================

# === PREROUTING chain (inbound traffic) ===
-A PREROUTING -p tcp -j ISTIO_INBOUND

# === ISTIO_INBOUND chain ===
# Skip ports that should NOT be intercepted
-A ISTIO_INBOUND -p tcp --dport 15008 -j RETURN    # HBONE (ambient)
-A ISTIO_INBOUND -p tcp --dport 15090 -j RETURN    # Prometheus scrape
-A ISTIO_INBOUND -p tcp --dport 15021 -j RETURN    # Health check
-A ISTIO_INBOUND -p tcp --dport 15020 -j RETURN    # Stats
# Everything else → redirect to Envoy inbound
-A ISTIO_INBOUND -p tcp -j ISTIO_IN_REDIRECT

# === ISTIO_IN_REDIRECT chain ===
# Redirect to Envoy's INBOUND listener on port 15006
-A ISTIO_IN_REDIRECT -p tcp -j REDIRECT --to-ports 15006

# === OUTPUT chain (outbound traffic) ===
-A OUTPUT -p tcp -j ISTIO_OUTPUT

# === ISTIO_OUTPUT chain ===
# Traffic FROM the Envoy process (UID 1337) → don't intercept (prevents loop!)
-A ISTIO_OUTPUT -m owner --uid-owner 1337 -j RETURN
# Traffic TO loopback that is NOT from Envoy → don't intercept
-A ISTIO_OUTPUT -o lo ! -d 127.0.0.1/32 -m owner --gid-owner 1337 -j ISTIO_IN_REDIRECT
-A ISTIO_OUTPUT -o lo -m owner ! --gid-owner 1337 -j RETURN
# Everything else → redirect to Envoy outbound
-A ISTIO_OUTPUT -d 127.0.0.1/32 -j RETURN
-A ISTIO_OUTPUT -j ISTIO_REDIRECT

# === ISTIO_REDIRECT chain ===
# Redirect to Envoy's OUTBOUND listener on port 15001
-A ISTIO_REDIRECT -p tcp -j REDIRECT --to-ports 15001
```

### Visual Flow

```
INBOUND TRAFFIC (someone calling your service):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  External Request → Pod's eth0
         │
  ┌──────▼──────────┐
  │   PREROUTING     │
  │   (nat table)    │
  └──────┬──────────┘
         │ -j ISTIO_INBOUND
  ┌──────▼──────────┐
  │  ISTIO_INBOUND   │  Ports 15008,15090,15021,15020 → RETURN (skip)
  └──────┬──────────┘
         │ (all other ports)
  ┌──────▼──────────────┐
  │  ISTIO_IN_REDIRECT   │
  │  REDIRECT → :15006   │ ← Envoy INBOUND listener
  └──────┬──────────────┘
         │
  ┌──────▼──────┐
  │   Envoy      │ → Processes request (auth, metrics, etc.)
  │   :15006     │ → Forwards to localhost:APP_PORT
  └──────┬──────┘
         │
  ┌──────▼──────┐
  │   Your App   │
  │   :8080      │
  └─────────────┘


OUTBOUND TRAFFIC (your service calling another):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  App sends request to reviews:8080
         │
  ┌──────▼──────────┐
  │    OUTPUT         │
  │    (nat table)    │
  └──────┬──────────┘
         │ -j ISTIO_OUTPUT
  ┌──────▼──────────┐
  │  ISTIO_OUTPUT    │  From UID 1337 (Envoy)? → RETURN (skip!)
  │                  │  To 127.0.0.1? → RETURN
  └──────┬──────────┘
         │ (everything else)
  ┌──────▼──────────────┐
  │  ISTIO_REDIRECT      │
  │  REDIRECT → :15001   │ ← Envoy OUTBOUND listener
  └──────┬──────────────┘
         │
  ┌──────▼──────┐
  │   Envoy      │ → Route lookup (VirtualService)
  │   :15001     │ → mTLS encryption
  └──────┬──────┘ → Load balance to upstream endpoint
         │
  ┌──────▼──────────────┐
  │  Destination Pod     │
  │  (via Envoy :15006)  │
  └──────────────────────┘
```

### Why UID 1337?

Envoy runs as user ID 1337 inside the container. The iptables rule `-m owner --uid-owner 1337 -j RETURN` ensures that traffic FROM Envoy is NOT redirected back to Envoy — which would create an infinite loop.

```
Without UID bypass:
  App → REDIRECT → Envoy → sends request → REDIRECT → Envoy → REDIRECT → ∞ LOOP!

With UID bypass:
  App → REDIRECT → Envoy (UID 1337) → sends request → UID 1337 → RETURN → network ✓
```

### Required Capabilities

```yaml
securityContext:
  capabilities:
    add:
    - NET_ADMIN   # Required to create iptables rules
    - NET_RAW     # Required for raw socket operations
```

**Security concern**: `NET_ADMIN` allows the container to modify the pod's network stack. In hardened environments (PodSecurityStandards `restricted`), this is not allowed. → Solution: **Istio CNI Plugin** (Part C).

---

## Part B: How the Sidecar Proxy Works

### Envoy Listener Architecture

The `istio-proxy` container runs Envoy with specific listeners:

```
PORT   │ DIRECTION │ PURPOSE
───────┼───────────┼──────────────────────────────────────
15001  │ OUTBOUND  │ Virtual listener — catches ALL redirected outbound traffic
       │           │ Uses original destination to route (SO_ORIGINAL_DST)
───────┼───────────┼──────────────────────────────────────
15006  │ INBOUND   │ Virtual listener — catches ALL redirected inbound traffic  
       │           │ Forwards to localhost:APP_PORT after processing
───────┼───────────┼──────────────────────────────────────
15090  │ METRICS   │ Prometheus scrape endpoint (/stats/prometheus)
───────┼───────────┼──────────────────────────────────────
15021  │ HEALTH    │ Health check endpoint (/healthz/ready)
───────┼───────────┼──────────────────────────────────────
15000  │ ADMIN     │ Envoy admin interface (/config_dump, /clusters, etc.)
───────┼───────────┼──────────────────────────────────────
15053  │ DNS       │ DNS proxy (when enabled)
```

### Complete Request Lifecycle (Outbound Call)

```
Step 1: App calls reviews.default.svc.cluster.local:8080
        └─ App resolves DNS → gets ClusterIP 10.96.100.10
        └─ App opens TCP connection to 10.96.100.10:8080

Step 2: iptables REDIRECT captures the connection
        └─ Changes destination from 10.96.100.10:8080 → 127.0.0.1:15001
        └─ But kernel remembers original destination (SO_ORIGINAL_DST)

Step 3: Envoy receives connection on port 15001
        └─ Retrieves original destination (10.96.100.10:8080) via SO_ORIGINAL_DST
        └─ Matches against its listener/route configuration
        └─ Finds: 10.96.100.10 → cluster "outbound|8080||reviews.default.svc.cluster.local"

Step 4: Envoy applies routing rules
        └─ VirtualService: 80% to v1, 20% to v2 (if configured)
        └─ DestinationRule: ROUND_ROBIN load balancing
        └─ Retries: 2 attempts on 503
        └─ Timeout: 5s

Step 5: Envoy selects an endpoint from EDS
        └─ Endpoints: 10.0.1.5:8080, 10.0.1.6:8080, 10.0.2.3:8080
        └─ Selects 10.0.1.5:8080 (round robin)

Step 6: Envoy establishes mTLS connection to destination
        └─ Uses SPIFFE cert from SDS
        └─ TLS handshake with destination Envoy
        └─ Sends request over encrypted connection

Step 7: Destination pod's Envoy (port 15006) receives request
        └─ Terminates mTLS
        └─ Checks AuthorizationPolicy
        └─ Forwards to localhost:8080 (the actual app)

Step 8: Response flows back through both Envoys
        └─ Metrics recorded (request count, latency, response code)
        └─ Trace headers propagated
        └─ Access log written
```

### How Envoy Gets Its Configuration

```
Envoy Startup:
  1. Reads bootstrap config (mounted as ConfigMap)
     └─ Contains: istiod address, cluster name, node metadata
  
  2. Opens gRPC connection to istiod:15010 (or 15012 for mTLS)
     └─ Sends: DiscoveryRequest with proxy metadata
  
  3. istiod responds with full config via ADS (Aggregated Discovery Service)
     └─ LDS: All listeners this proxy needs
     └─ RDS: Routes for each listener
     └─ CDS: All upstream clusters this proxy can reach
     └─ EDS: Endpoints for each cluster
     └─ SDS: mTLS certificates
  
  4. Envoy applies config and starts accepting traffic
  
  5. Continuous: istiod pushes updates whenever config changes
     └─ Service added → new CDS/EDS push
     └─ VirtualService changed → new RDS push
     └─ Pod scaled → new EDS push
```

---

## Part C: Sidecar vs Istio CNI Plugin

### The Problem
`istio-init` requires `NET_ADMIN` capability to set up iptables rules. This is a security concern:
- Violates PodSecurityStandard `restricted` policy
- Not allowed in some hardened environments (OpenShift, GKE Autopilot)
- Grants more privileges than strictly necessary

### The Solution: Istio CNI Plugin

Instead of each pod's init container setting up iptables, a **DaemonSet on each node** does it during pod creation.

```
WITHOUT CNI Plugin:
  Pod has: istio-init (with NET_ADMIN) → sets up iptables

WITH CNI Plugin:
  Node has: istio-cni-node DaemonSet
  CNI plugin runs during pod sandbox creation → sets up iptables
  Pod does NOT need istio-init → no NET_ADMIN required
```

### How Istio CNI Works

```
1. Istio CNI installs itself in the CNI chain on each node
   └─ Inserts a config file in /etc/cni/net.d/
   └─ CNI plugins run in chain: [primary CNI] → [Istio CNI]

2. When kubelet creates a pod sandbox:
   └─ Primary CNI (Calico/Cilium) sets up pod networking
   └─ Istio CNI runs and:
       a. Detects if the pod should have a sidecar (checks annotations)
       b. Enters the pod's network namespace
       c. Sets up the same iptables rules that istio-init would
       d. Exits

3. Pod starts WITHOUT istio-init container
   └─ Only istio-proxy sidecar is injected
   └─ No NET_ADMIN capability needed on any container
```

### Installation

```bash
# Install Istio with CNI plugin enabled
istioctl install --set profile=default \
  --set components.cni.enabled=true \
  --set values.cni.cniBinDir="/opt/cni/bin" \
  --set values.cni.cniConfDir="/etc/cni/net.d"

# Verify CNI DaemonSet
kubectl get daemonset -n istio-system istio-cni-node
```

### Comparison Table

| Feature | istio-init (Default) | Istio CNI Plugin |
|---------|---------------------|-----------------|
| Where iptables are set up | In pod (init container) | On node (DaemonSet) |
| NET_ADMIN required | ✅ In pod | ❌ Not in pod |
| PodSecurityStandard `restricted` | ❌ Not compatible | ✅ Compatible |
| Extra DaemonSet | ❌ | ✅ (istio-cni-node) |
| CNI chain ordering | N/A | Must be correct |
| Debugging | Easy (inspect pod) | Harder (check node) |
| OpenShift compatible | ❌ (by default) | ✅ |
| GKE Autopilot compatible | ❌ | ✅ |
| Startup latency | Init container runs first | Slightly faster (no init) |

### When to Use CNI Plugin
- ✅ Regulated/hardened environments
- ✅ OpenShift clusters
- ✅ GKE Autopilot
- ✅ When PodSecurityStandard `restricted` is enforced
- ⚠️ Be careful with CNI chain ordering (must run after primary CNI)

---

## Part D: Sidecar vs Ambient Mesh

### Sidecar Model (Traditional)

Every pod gets an Envoy sidecar. Full L4 + L7 capabilities per pod.

```
┌─────────────────────────────────────────┐
│                   Node                    │
│  ┌─────────────┐  ┌─────────────┐       │
│  │ Pod A        │  │ Pod B        │      │
│  │ ┌───┐┌────┐ │  │ ┌───┐┌────┐ │      │
│  │ │App││Envoy││  │ │App││Envoy│ │      │
│  │ └───┘└────┘ │  │ └───┘└────┘ │      │
│  └─────────────┘  └─────────────┘       │
│                                          │
│  Memory: 2 Envoy instances × ~100MB     │
│  CPU: 2 Envoy instances × ~0.5 vCPU    │
└─────────────────────────────────────────┘
```

### Ambient Mesh (New Model)

Two layers: ztunnel (per-node L4) + optional waypoint proxy (per-namespace L7).

```
┌────────────────────────────────────────────────────────────┐
│                        Node                                  │
│  ┌─────────────┐  ┌─────────────┐                          │
│  │ Pod A        │  │ Pod B        │  ← NO sidecars!         │
│  │ ┌───┐        │  │ ┌───┐        │                         │
│  │ │App│        │  │ │App│        │                         │
│  │ └───┘        │  │ └───┘        │                         │
│  └──────┬───────┘  └──────┬───────┘                         │
│         │                  │                                 │
│  ┌──────▼──────────────────▼──────┐                         │
│  │         ztunnel (DaemonSet)     │ ← L4 proxy per node    │
│  │    - mTLS encryption/decryption │                         │
│  │    - L4 AuthorizationPolicy     │                         │
│  │    - TCP metrics                │                         │
│  └────────────────────────────────┘                         │
│                                                              │
│  Optional (only if L7 features needed):                      │
│  ┌────────────────────────────────┐                         │
│  │    Waypoint Proxy (per namespace)│ ← L7 proxy            │
│  │    - VirtualService routing      │                        │
│  │    - HTTP AuthorizationPolicy   │                        │
│  │    - HTTP metrics & tracing     │                        │
│  └────────────────────────────────┘                         │
│                                                              │
│  Memory: 1 ztunnel (~50MB) + optional waypoint              │
│  vs Sidecar: N Envoys × ~100MB                              │
└──────────────────────────────────────────────────────────────┘
```

### How ztunnel Works

ztunnel is a purpose-built L4 proxy (written in Rust for performance):
1. Runs as a DaemonSet (one per node)
2. Uses eBPF or iptables to redirect pod traffic through itself
3. Establishes mTLS tunnels between nodes (HBONE protocol)
4. Enforces L4 AuthorizationPolicy (source/destination IP, port)
5. Collects TCP-level metrics

### How Waypoint Proxies Work

For workloads that need L7 features:
1. Deploy a waypoint proxy per namespace (or per service account)
2. ztunnel forwards traffic TO the waypoint when L7 processing is needed
3. Waypoint applies: VirtualService routing, HTTP AuthZ, retries, fault injection
4. Waypoint forwards to destination

```bash
# Create a waypoint proxy for a namespace
istioctl x waypoint apply --namespace my-namespace

# Verify
kubectl get pods -n my-namespace -l gateway.networking.k8s.io/gateway-name
```

### Detailed Comparison

| Feature | Sidecar | Ambient (ztunnel + waypoint) |
|---------|---------|------------------------------|
| **L4 mTLS** | ✅ | ✅ (ztunnel) |
| **L4 AuthZ** | ✅ | ✅ (ztunnel) |
| **L7 routing (VirtualService)** | ✅ | ✅ (requires waypoint) |
| **L7 AuthZ (path/method)** | ✅ | ✅ (requires waypoint) |
| **HTTP retries/timeouts** | ✅ | ✅ (requires waypoint) |
| **Fault injection** | ✅ | ✅ (requires waypoint) |
| **Per-pod resource overhead** | ~100MB + 0.5 vCPU | ~0 (ztunnel shared) |
| **Node resource overhead** | N/A | ~50MB per ztunnel |
| **At 1M pods** | ~100TB memory | ~50MB × nodes (~5000 nodes = ~250GB) |
| **Sidecar injection needed** | ✅ | ❌ |
| **Pod restart for mesh join** | ✅ | ❌ |
| **Startup latency** | +200-500ms (sidecar init) | Minimal |
| **Maturity** | Mature (GA) | Newer (check version) |
| **EnvoyFilter support** | ✅ | Limited |
| **WASM plugins** | ✅ | Waypoint only |
| **Debugging familiarity** | Well-known tools | New paradigm |

### Decision Framework

```
Do you need L7 features for this workload?
  │
  ├── NO → Ambient mesh (ztunnel only)
  │        ✓ mTLS, L4 policy, TCP metrics
  │        ✓ Dramatically lower resource cost
  │
  └── YES → Do you need per-pod L7 control?
            │
            ├── YES → Sidecar model
            │         ✓ Full L7 per pod
            │         ✓ EnvoyFilter, WASM
            │
            └── NO (namespace-level is fine) → Ambient + Waypoint
                    ✓ L7 features via shared waypoint
                    ✓ Lower resource overhead than sidecar
```

### Migration Path: Sidecar → Ambient

```bash
# Step 1: Enable ambient mode for a namespace
kubectl label namespace my-ns istio.io/dataplane-mode=ambient

# Step 2: Remove sidecar injection label
kubectl label namespace my-ns istio-injection-

# Step 3: Restart pods (sidecars will be removed)
kubectl rollout restart deployment -n my-ns

# Step 4: If L7 features needed, add waypoint
istioctl x waypoint apply -n my-ns

# Rollback: Remove ambient, re-add sidecar injection
kubectl label namespace my-ns istio.io/dataplane-mode-
kubectl label namespace my-ns istio-injection=enabled
kubectl rollout restart deployment -n my-ns
```

---

## Lab: Sidecar Inspection

```bash
#!/bin/bash
# lab-sidecar-inspection.sh — Deep inspection of a running Istio sidecar

echo "=== Sidecar Deep Inspection Lab ==="
echo "Prerequisites: Istio installed, Bookinfo deployed with sidecars"

# Step 1: Verify sidecar is present
PRODUCT_POD=$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')
echo "[Step 1] Pod: $PRODUCT_POD"
echo "Containers (should see istio-proxy):"
kubectl get pod $PRODUCT_POD -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}'

# Step 2: Check the init container (istio-init)
echo ""
echo "[Step 2] Init container details:"
kubectl get pod $PRODUCT_POD -o jsonpath='{range .spec.initContainers[*]}Name: {.name}{"\n"}Image: {.image}{"\n"}Args: {.args}{"\n\n"}{end}'

# Step 3: Inspect the iptables rules inside the pod
echo "[Step 3] iptables rules in the pod's network namespace:"
kubectl exec $PRODUCT_POD -c istio-proxy -- \
  iptables -t nat -L -n -v --line-numbers 2>/dev/null || \
echo "(If iptables not available, try:)"
kubectl debug $PRODUCT_POD --image=nicolaka/netshoot -it --target=istio-proxy -- \
  iptables -t nat -L -n -v --line-numbers 2>/dev/null

# Step 4: Envoy listener ports
echo ""
echo "[Step 4] Envoy listeners:"
istioctl proxy-config listeners $PRODUCT_POD

# Step 5: Envoy routes
echo ""
echo "[Step 5] Envoy routes (sample):"
istioctl proxy-config routes $PRODUCT_POD --name=8080

# Step 6: Envoy clusters (upstream services)
echo ""
echo "[Step 6] Envoy clusters:"
istioctl proxy-config clusters $PRODUCT_POD | head -20

# Step 7: Envoy endpoints
echo ""
echo "[Step 7] Endpoints for reviews service:"
istioctl proxy-config endpoints $PRODUCT_POD | grep reviews

# Step 8: Envoy bootstrap config
echo ""
echo "[Step 8] Bootstrap config (istiod connection):"
istioctl proxy-config bootstrap $PRODUCT_POD | grep -A 5 "discovery_address"

# Step 9: mTLS certificates
echo ""
echo "[Step 9] mTLS certificates:"
istioctl proxy-config secret $PRODUCT_POD

# Step 10: Envoy admin interface
echo ""
echo "[Step 10] Envoy admin interface:"
echo "Port-forward to access:"
echo "  kubectl port-forward $PRODUCT_POD 15000:15000"
echo "Then open: http://localhost:15000"
echo ""
echo "Key admin endpoints:"
echo "  /config_dump — Full Envoy configuration"
echo "  /clusters — Upstream cluster info"
echo "  /listeners — Active listeners"
echo "  /stats — All metrics"
echo "  /server_info — Envoy version"

# Step 11: Check sidecar resource usage
echo ""
echo "[Step 11] Sidecar resource usage:"
kubectl top pod $PRODUCT_POD --containers 2>/dev/null || \
  echo "(Requires metrics-server)"

echo ""
echo "=== Lab Complete ==="
echo ""
echo "Key things you inspected:"
echo "1. istio-init container with NET_ADMIN capability"
echo "2. iptables rules redirecting traffic to ports 15001/15006"
echo "3. Envoy listeners, routes, clusters, endpoints"
echo "4. mTLS certificates issued by istiod"
echo "5. Bootstrap config showing connection to istiod"
```

---

## Lab: Ambient Mesh

```bash
#!/bin/bash
# lab-ambient.sh — Ambient mesh exploration

echo "=== Ambient Mesh Lab ==="
echo "Note: Requires Istio 1.18+ with ambient profile"

# Step 1: Install Istio with ambient profile
echo "[Step 1] Installing ambient mesh..."
istioctl install --set profile=ambient -y

# Step 2: Verify ztunnel DaemonSet
echo ""
echo "[Step 2] Verify ztunnel:"
kubectl get daemonset -n istio-system ztunnel
kubectl get pods -n istio-system -l app=ztunnel

# Step 3: Create test namespace with ambient mode
echo ""
echo "[Step 3] Creating ambient namespace..."
kubectl create namespace ambient-test
kubectl label namespace ambient-test istio.io/dataplane-mode=ambient

# Step 4: Deploy a test app (NO sidecar injection needed!)
echo ""
echo "[Step 4] Deploying test app..."
kubectl apply -n ambient-test -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
spec:
  replicas: 2
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
spec:
  selector:
    app: httpbin
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sleep
  template:
    metadata:
      labels:
        app: sleep
    spec:
      containers:
      - name: sleep
        image: curlimages/curl
        command: ["/bin/sleep", "infinity"]
EOF
sleep 10

# Step 5: Notice — pods have only 1/1 containers (NO sidecar!)
echo ""
echo "[Step 5] Pods (notice: 1/1, NO sidecar!):"
kubectl get pods -n ambient-test

# Step 6: But traffic is still encrypted (mTLS via ztunnel)
echo ""
echo "[Step 6] Testing connectivity (through ztunnel)..."
SLEEP_POD=$(kubectl get pod -n ambient-test -l app=sleep -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n ambient-test $SLEEP_POD -- curl -s http://httpbin.ambient-test/ip | head

# Step 7: Check ztunnel logs for mTLS
echo ""
echo "[Step 7] ztunnel logs (showing mTLS):"
kubectl logs -n istio-system -l app=ztunnel --tail=10 | grep -i "tls\|connect"

# Step 8: Compare resource usage: ambient vs sidecar
echo ""
echo "[Step 8] Resource comparison:"
echo "Ambient pods (no sidecar overhead):"
kubectl top pods -n ambient-test 2>/dev/null
echo ""
echo "ztunnel resource usage (shared per node):"
kubectl top pods -n istio-system -l app=ztunnel 2>/dev/null

# Step 9: Add a waypoint for L7 features
echo ""
echo "[Step 9] Adding waypoint proxy for L7 features..."
istioctl x waypoint apply -n ambient-test
kubectl get pods -n ambient-test -l gateway.networking.k8s.io/gateway-name

# Cleanup
echo ""
echo "[Cleanup]"
echo "  kubectl delete namespace ambient-test"
echo "  # Or keep it for further experimentation"

echo ""
echo "=== Key Observations ==="
echo "1. Pods in ambient mode have NO sidecar (1/1 containers)"
echo "2. ztunnel handles mTLS transparently at the node level"
echo "3. Resource overhead is per-node, not per-pod"
echo "4. Waypoint proxies are only needed for L7 features"
echo "5. At 1M pods across 5000 nodes: 5000 ztunnels vs 1M sidecars"
```

---

## Summary

| Topic | Key Takeaway | Interview Answer |
|-------|-------------|------------------|
| Init container | Sets up iptables REDIRECT rules before app starts | "istio-init creates NAT chains that redirect all TCP traffic to Envoy on ports 15001 (outbound) and 15006 (inbound), bypassing UID 1337 to prevent loops" |
| Sidecar proxy | Shares pod network namespace, receives all traffic via iptables | "Envoy listens on virtual listeners. It uses SO_ORIGINAL_DST to know the real destination, then applies routing, mTLS, and observability" |
| CNI plugin | Moves iptables setup from pod init container to node DaemonSet | "Istio CNI removes the need for NET_ADMIN capability in pods by setting up iptables at the CNI level during sandbox creation" |
| Ambient mesh | Per-node ztunnel (L4) + optional waypoint (L7) | "Ambient replaces per-pod sidecars with a shared ztunnel DaemonSet for L4 and optional waypoint proxies for L7, reducing resource overhead by orders of magnitude at scale" |

## Next Module

Continue to [Module 07: Traffic Management →](../07-traffic-management/)

# Module 12: Multi-Cluster Istio

> **Why this matters**: At 1M pods, you're running multiple Kubernetes clusters. Understanding multi-cluster Istio topologies — trust models, cross-cluster service discovery, and east-west gateways — is essential for designing a scalable, resilient mesh.

## Table of Contents
- [Theory: Why Multi-Cluster?](#theory-why-multi-cluster)
- [Theory: Trust Model](#theory-trust-model)
- [Theory: Multi-Cluster Topologies](#theory-multi-cluster-topologies)
- [Theory: East-West Gateway](#theory-east-west-gateway)
- [Theory: Cross-Cluster Service Discovery](#theory-cross-cluster-service-discovery)
- [Lab: Multi-Cluster Setup](#lab-multi-cluster-setup)

---

## Theory: Why Multi-Cluster?

| Reason | Explanation |
|--------|-------------|
| **Blast radius** | Cluster failure only impacts workloads in that cluster |
| **Scale limits** | K8s clusters have practical limits (~5000 nodes, ~150K pods) |
| **Geographic distribution** | Clusters in different regions for latency |
| **Regulatory compliance** | Data must stay in specific regions (GDPR, etc.) |
| **Team isolation** | Different teams own different clusters |
| **Upgrade isolation** | Upgrade Istio in one cluster without affecting others |

---

## Theory: Trust Model

For mTLS to work across clusters, all clusters must **share the same root CA** (or a common trust bundle). Without this, Envoy in Cluster A can't validate certificates from Cluster B.

```
                    Shared Root CA
                    ┌─────────────┐
                    │  Root Cert   │
                    │  (offline)   │
                    └──────┬──────┘
                    ┌──────┴──────┐
              ┌─────┴─────┐ ┌────┴──────┐
              │ Cluster A  │ │ Cluster B  │
              │ Intermed.  │ │ Intermed.  │
              │ CA (istiod)│ │ CA (istiod)│
              └────────────┘ └───────────┘
                    │              │
            Certs issued     Certs issued
           with same root   with same root
                    │              │
               spiffe://cluster.local/ns/X/sa/Y
                    CROSS-CLUSTER mTLS WORKS ✓
```

### Setting Up Shared Root CA

```bash
# Generate root CA (do this ONCE, store securely)
openssl req -newkey rsa:4096 -nodes -keyout root-key.pem \
  -x509 -days 3650 -out root-cert.pem \
  -subj "/O=MyOrg/CN=Root CA"

# Generate intermediate CA for Cluster A
openssl req -newkey rsa:4096 -nodes -keyout cluster-a-ca-key.pem \
  -out cluster-a-ca-csr.pem -subj "/O=MyOrg/CN=Cluster A CA"
openssl x509 -req -in cluster-a-ca-csr.pem -CA root-cert.pem \
  -CAkey root-key.pem -CAcreateserial -out cluster-a-ca-cert.pem -days 1825

# Create K8s secret in each cluster
kubectl create secret generic cacerts -n istio-system \
  --from-file=ca-cert.pem=cluster-a-ca-cert.pem \
  --from-file=ca-key.pem=cluster-a-ca-key.pem \
  --from-file=root-cert.pem=root-cert.pem \
  --from-file=cert-chain.pem=cert-chain.pem
```

---

## Theory: Multi-Cluster Topologies

### Topology 1: Multi-Primary (Flat Network)

```
┌─────────────────────────────────────────────────────────────────┐
│                      Flat Network (VPC Peering)                  │
│                                                                   │
│  ┌──────────────────────┐    ┌──────────────────────┐           │
│  │    Cluster A           │    │    Cluster B           │        │
│  │  ┌──────────┐         │    │  ┌──────────┐         │        │
│  │  │ istiod-A │         │    │  │ istiod-B │         │        │
│  │  └──────────┘         │    │  └──────────┘         │        │
│  │                        │    │                        │        │
│  │  Pod A ←──── direct ──────────→ Pod B               │        │
│  │  10.0.1.2             │    │  10.0.2.3              │        │
│  │                        │    │                        │        │
│  │  Pods can reach each   │    │  Pods can reach each  │        │
│  │  other directly        │    │  other directly       │        │
│  └──────────────────────┘    └──────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
```

**How it works**:
- Each cluster has its own istiod
- Pods have routable IPs across clusters (VPC peering, shared VPC)
- Each istiod watches a remote cluster's API server for service discovery
- Traffic goes directly pod-to-pod (no gateway needed)

**Pros**: Simplest, lowest latency
**Cons**: Requires flat network (not always possible), no network isolation

### Topology 2: Primary-Remote

```
┌────────────────────────────────────────────────────────────────┐
│                                                                 │
│  ┌──────────────────────┐    ┌──────────────────────┐         │
│  │  Primary Cluster       │    │  Remote Cluster       │       │
│  │  ┌──────────┐         │    │  (NO istiod)          │       │
│  │  │ istiod   │←────────┼────┼── Envoy sidecars     │       │
│  │  │ (control │         │    │   connect back to     │       │
│  │  │  plane)  │         │    │   istiod in Primary   │       │
│  │  └──────────┘         │    │                        │       │
│  │                        │    │                        │       │
│  │  Data plane pods       │    │  Data plane pods      │       │
│  └──────────────────────┘    └──────────────────────┘         │
└────────────────────────────────────────────────────────────────┘
```

**How it works**:
- Only the primary cluster runs istiod
- Remote cluster's sidecars connect to primary's istiod for config
- Reduces operational complexity (one control plane)

**Pros**: Fewer istiod instances to manage
**Cons**: Single point of failure, higher latency for remote proxies

### Topology 3: Multi-Primary on Different Networks (Most Common at Scale)

```
┌─────────────────────┐         ┌─────────────────────┐
│    Cluster A          │         │    Cluster B          │
│  ┌──────────┐        │         │  ┌──────────┐        │
│  │ istiod-A │        │         │  │ istiod-B │        │
│  └──────────┘        │         │  └──────────┘        │
│                       │         │                       │
│  Pods: 10.0.0.0/16   │         │  Pods: 10.0.0.0/16   │
│  (overlapping CIDRs!) │         │  (overlapping CIDRs!) │
│                       │         │                       │
│  ┌─────────────────┐ │         │ ┌─────────────────┐  │
│  │  East-West GW    │◄─── TLS tunnel ───►│  East-West GW    │  │
│  │  (port 15443)    │ │         │ │  (port 15443)    │  │
│  └─────────────────┘ │         │ └─────────────────┘  │
└─────────────────────┘         └─────────────────────┘
         ▲                               ▲
         │                               │
         └───────── Cross-cluster ───────┘
              traffic goes through
              east-west gateways
```

**How it works**:
- Each cluster has its own istiod AND its own east-west gateway
- Cross-cluster traffic goes through the east-west gateways (not direct pod-to-pod)
- Gateways create mTLS tunnels (port 15443) between clusters
- Pod CIDRs CAN overlap (gateways handle translation)

**Pros**: Works with any network topology, pod CIDR overlap OK
**Cons**: Extra hop through gateway, slightly higher latency

---

## Theory: East-West Gateway

The **east-west gateway** is a dedicated Istio gateway for cross-cluster traffic (as opposed to north-south ingress gateways for external traffic).

```yaml
# east-west-gateway.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: eastwest
spec:
  revision: ""
  profile: empty
  components:
    ingressGateways:
    - name: istio-eastwestgateway
      label:
        istio: eastwestgateway
        app: istio-eastwestgateway
      enabled: true
      k8s:
        env:
        - name: ISTIO_META_REQUESTED_NETWORK_VIEW
          value: network-a                    # This cluster's network name
        service:
          ports:
          - name: tls
            port: 15443
            targetPort: 15443
          - name: tls-istiod
            port: 15012
            targetPort: 15012
```

### How Cross-Cluster Traffic Flows

```
Service A (Cluster 1) → Service B (Cluster 2):

1. Pod A's Envoy resolves Service B
   (istiod in Cluster 1 has endpoints from Cluster 2)

2. Envoy sees Service B endpoint is in a different network
   → Routes to east-west gateway in Cluster 2

3. Cluster 1's Envoy → Cluster 2's east-west gateway (port 15443)
   → mTLS tunnel (SNI-based routing)
   → Forwards to Pod B in Cluster 2

4. Response flows back through the same path
```

---

## Theory: Cross-Cluster Service Discovery

### How istiod Discovers Remote Services

```bash
# Step 1: Create a remote secret in Cluster A for Cluster B
# This gives Cluster A's istiod access to Cluster B's API server
istioctl create-remote-secret \
  --name=cluster-b \
  --context=cluster-b-context | \
  kubectl apply -f - --context=cluster-a-context

# This creates a Secret with a kubeconfig to access Cluster B
# istiod in Cluster A uses this to watch Services/Endpoints in Cluster B
```

```
Cluster A's istiod:
  ├── Watches Cluster A API server → Cluster A services/endpoints
  └── Watches Cluster B API server (via remote secret) → Cluster B services/endpoints
       │
       ▼
  Merges endpoints from both clusters into EDS
       │
       ▼
  Pushes combined endpoints to all proxies in Cluster A
```

### Same-Name Services Across Clusters

If `reviews` service exists in both clusters:
- istiod merges endpoints from BOTH clusters
- Envoy sees endpoints from cluster-a AND cluster-b
- Load balancing spans both clusters
- Locality-aware routing prefers local-cluster endpoints (Module 13)

```
Cluster A: reviews → [10.0.1.5:8080, 10.0.1.6:8080]
Cluster B: reviews → [10.0.2.3:8080, 10.0.2.4:8080]

Envoy in Cluster A sees:
  reviews endpoints:
    locality=us-east-1a: [10.0.1.5:8080, 10.0.1.6:8080]  ← prefer
    locality=us-west-2a: [via east-west GW to 10.0.2.3, 10.0.2.4]  ← failover
```

---

## Lab: Multi-Cluster Setup

```bash
#!/bin/bash
# lab-multi-cluster.sh — Multi-Cluster Istio Lab (using Kind)

echo "=== Multi-Cluster Istio Lab ==="
echo "Using Kind to simulate two clusters"

# Step 1: Create two Kind clusters
echo "[Step 1] Creating two Kind clusters..."

cat <<EOF | kind create cluster --name cluster-a --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  podSubnet: "10.10.0.0/16"
  serviceSubnet: "10.110.0.0/16"
nodes:
- role: control-plane
- role: worker
EOF

cat <<EOF | kind create cluster --name cluster-b --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  podSubnet: "10.20.0.0/16"
  serviceSubnet: "10.120.0.0/16"
nodes:
- role: control-plane
- role: worker
EOF

# Step 2: Set contexts
CTX_CLUSTER_A="kind-cluster-a"
CTX_CLUSTER_B="kind-cluster-b"

# Step 3: Create shared CA
echo ""
echo "[Step 3] Setting up shared root CA..."

# Generate root cert (simplified for lab)
mkdir -p certs
cd certs

# Use Istio's sample certs for the lab
curl -sL https://raw.githubusercontent.com/istio/istio/release-1.20/tools/certs/common.mk -o common.mk
# For a real setup, generate your own CA (see Theory section above)

# Step 4: Install Istio on both clusters
echo ""
echo "[Step 4] Installing Istio on Cluster A..."
cat <<EOF | istioctl install --context=$CTX_CLUSTER_A -y -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      proxyMetadata:
        ISTIO_META_DNS_CAPTURE: "true"
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster-a
      network: network-a
EOF

echo "Installing Istio on Cluster B..."
cat <<EOF | istioctl install --context=$CTX_CLUSTER_B -y -f -
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      proxyMetadata:
        ISTIO_META_DNS_CAPTURE: "true"
  values:
    global:
      meshID: mesh1
      multiCluster:
        clusterName: cluster-b
      network: network-b
EOF

# Step 5: Install east-west gateways
echo ""
echo "[Step 5] Installing east-west gateways..."
# (Use istioctl or helm to install east-west gateway on each cluster)

# Step 6: Exchange remote secrets
echo ""
echo "[Step 6] Exchanging remote secrets..."
istioctl create-remote-secret --context=$CTX_CLUSTER_B --name=cluster-b | \
  kubectl apply -f - --context=$CTX_CLUSTER_A

istioctl create-remote-secret --context=$CTX_CLUSTER_A --name=cluster-a | \
  kubectl apply -f - --context=$CTX_CLUSTER_B

# Step 7: Verify multi-cluster
echo ""
echo "[Step 7] Verifying multi-cluster setup..."
echo "Cluster A remote clusters:"
istioctl remote-clusters --context=$CTX_CLUSTER_A 2>/dev/null

echo "Cluster B remote clusters:"
istioctl remote-clusters --context=$CTX_CLUSTER_B 2>/dev/null

# Step 8: Deploy test services
echo ""
echo "[Step 8] Deploying test services..."

# Deploy helloworld v1 on Cluster A
kubectl create namespace sample --context=$CTX_CLUSTER_A
kubectl label namespace sample istio-injection=enabled --context=$CTX_CLUSTER_A
kubectl apply -n sample --context=$CTX_CLUSTER_A -f \
  https://raw.githubusercontent.com/istio/istio/release-1.20/samples/helloworld/helloworld.yaml -l version=v1

kubectl apply -n sample --context=$CTX_CLUSTER_A -f \
  https://raw.githubusercontent.com/istio/istio/release-1.20/samples/helloworld/helloworld.yaml -l service=helloworld

# Deploy helloworld v2 on Cluster B
kubectl create namespace sample --context=$CTX_CLUSTER_B
kubectl label namespace sample istio-injection=enabled --context=$CTX_CLUSTER_B
kubectl apply -n sample --context=$CTX_CLUSTER_B -f \
  https://raw.githubusercontent.com/istio/istio/release-1.20/samples/helloworld/helloworld.yaml -l version=v2

kubectl apply -n sample --context=$CTX_CLUSTER_B -f \
  https://raw.githubusercontent.com/istio/istio/release-1.20/samples/helloworld/helloworld.yaml -l service=helloworld

# Step 9: Test cross-cluster traffic
echo ""
echo "[Step 9] Testing cross-cluster traffic..."
echo "Calling helloworld from Cluster A (should see v1 and v2 responses):"

# Deploy sleep client in Cluster A
kubectl apply -n sample --context=$CTX_CLUSTER_A -f \
  https://raw.githubusercontent.com/istio/istio/release-1.20/samples/sleep/sleep.yaml

sleep 10

SLEEP_POD=$(kubectl get pod -n sample --context=$CTX_CLUSTER_A -l app=sleep -o jsonpath='{.items[0].metadata.name}')

for i in $(seq 1 10); do
  kubectl exec -n sample --context=$CTX_CLUSTER_A $SLEEP_POD -c sleep -- \
    curl -s http://helloworld.sample:5000/hello 2>/dev/null
done

echo ""
echo "If you see both 'Hello version: v1' and 'Hello version: v2',"
echo "cross-cluster traffic is working!"

# Cleanup
echo ""
echo "[Cleanup] To clean up:"
echo "  kind delete cluster --name cluster-a"
echo "  kind delete cluster --name cluster-b"

echo ""
echo "=== Lab Complete ==="
```

---

## Summary

| Topology | Control Planes | Network | Gateway Needed | Best For |
|----------|---------------|---------|----------------|----------|
| Multi-Primary (flat) | One per cluster | Flat/shared | No | Simple, low latency |
| Primary-Remote | One (primary) | Any | No (flat) / Yes (diff) | Small remote clusters |
| Multi-Primary (diff networks) | One per cluster | Separate | Yes (east-west) | Production at scale |

## Next Module

Continue to [Module 13: Inter-AZ Traffic Optimization →](../13-inter-az-traffic-optimization/)

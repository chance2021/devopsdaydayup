# Module 13: Reducing Inter-AZ Traffic Cost

> **Why this matters**: At 1M pods across multiple AZs, inter-AZ data transfer costs can be **$100K-$500K+ per month** in cloud. Istio's locality-aware routing can reduce this by 80-90%. This is a direct cost-saving feature that makes Istio pay for itself.

## Table of Contents
- [Theory: The Cost Problem](#theory-the-cost-problem)
- [Theory: Locality Labels](#theory-locality-labels)
- [Theory: Locality Load Balancing](#theory-locality-load-balancing)
- [Theory: Topology-Aware Routing](#theory-topology-aware-routing)
- [Theory: Cost Calculation](#theory-cost-calculation)
- [Theory: Monitoring Inter-AZ Traffic](#theory-monitoring-inter-az-traffic)
- [Lab: Locality-Aware Routing](#lab-locality-aware-routing)

---

## Theory: The Cost Problem

### Cloud Provider Inter-AZ Pricing

| Provider | Same-AZ | Cross-AZ | Cross-Region |
|----------|---------|----------|-------------|
| AWS | Free | $0.01/GB each direction | $0.02-$0.09/GB |
| GCP | Free | $0.01/GB each direction | $0.02-$0.08/GB |
| Azure | Free | $0.01/GB each direction | $0.02-$0.08/GB |

### Without Locality Routing

```
┌─────────────────────────────────────────────────────────┐
│                      Cluster                              │
│                                                           │
│  AZ-a                AZ-b                AZ-c            │
│  ┌──────┐           ┌──────┐           ┌──────┐         │
│  │App-1 │──33%────→ │App-2 │──33%────→ │App-2 │         │
│  │      │           │(v1)  │           │(v1)  │         │
│  └──────┘           └──────┘           └──────┘         │
│       │                                    ▲             │
│       └────────────── 33% ────────────────┘              │
│                                                           │
│  Standard round-robin: 66% of traffic crosses AZ ✗      │
└─────────────────────────────────────────────────────────┘
```

### With Locality Routing

```
┌─────────────────────────────────────────────────────────┐
│                      Cluster                              │
│                                                           │
│  AZ-a                AZ-b                AZ-c            │
│  ┌──────┐           ┌──────┐           ┌──────┐         │
│  │App-1 │──100%───→ │App-2 │           │App-2 │         │
│  │      │           │(v1)  │           │(v1)  │         │
│  └──────┘           └──────┘           └──────┘         │
│                      same AZ                              │
│                                                           │
│  Locality routing: 0% crosses AZ ✓ (unless local fails) │
└─────────────────────────────────────────────────────────┘
```

---

## Theory: Locality Labels

Kubernetes nodes are labeled with topology information. Istio uses these labels for routing:

```bash
# Standard topology labels (set by cloud provider or manually)
topology.kubernetes.io/region: us-east-1
topology.kubernetes.io/zone: us-east-1a

# Legacy labels (still supported)
failure-domain.beta.kubernetes.io/region: us-east-1
failure-domain.beta.kubernetes.io/zone: us-east-1a
```

### How Locality Flows

```
Node label: topology.kubernetes.io/zone=us-east-1a
  │
  ▼
Pod inherits node's locality
  │
  ▼
Envoy reports locality to istiod during connection
  │
  ▼
istiod includes locality info in EDS endpoints
  │
  ▼
Envoy uses locality for load balancing decisions
```

### Check Locality Labels

```bash
# Check node labels
kubectl get nodes -o custom-columns=\
  'NAME:.metadata.name,\
   REGION:.metadata.labels.topology\.kubernetes\.io/region,\
   ZONE:.metadata.labels.topology\.kubernetes\.io/zone'

# Set labels manually (for minikube)
kubectl label node minikube topology.kubernetes.io/region=us-east-1
kubectl label node minikube topology.kubernetes.io/zone=us-east-1a
```

---

## Theory: Locality Load Balancing

### Enabling Locality LB

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  trafficPolicy:
    # IMPORTANT: Outlier detection MUST be configured!
    # Without it, locality LB won't activate.
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
    
    # Enable locality load balancing
    loadBalancer:
      localityLbSetting:
        enabled: true
```

### Locality Priority Order

```
Priority 1: Same zone (e.g., us-east-1a → us-east-1a)
Priority 2: Same region, different zone (e.g., us-east-1a → us-east-1b)
Priority 3: Different region (e.g., us-east-1 → us-west-2)
```

### Explicit Failover Configuration

```yaml
trafficPolicy:
  loadBalancer:
    localityLbSetting:
      enabled: true
      failover:
      - from: us-east-1        # If us-east-1 fails...
        to: us-east-2          # ...route to us-east-2 (nearest region)
      - from: us-west-2
        to: us-west-1
  outlierDetection:
    consecutiveErrors: 5
    interval: 30s
    baseEjectionTime: 30s
```

### Distribution Mode (Fine-Grained Control)

```yaml
trafficPolicy:
  loadBalancer:
    localityLbSetting:
      enabled: true
      distribute:
      - from: "us-east-1/us-east-1a/*"    # From zone a:
        to:
          "us-east-1/us-east-1a/*": 80      # 80% stays local
          "us-east-1/us-east-1b/*": 15      # 15% to zone b
          "us-east-1/us-east-1c/*": 5       # 5% to zone c
      - from: "us-east-1/us-east-1b/*"
        to:
          "us-east-1/us-east-1b/*": 80
          "us-east-1/us-east-1a/*": 15
          "us-east-1/us-east-1c/*": 5
  outlierDetection:
    consecutiveErrors: 5
    interval: 30s
    baseEjectionTime: 30s
```

### Why Outlier Detection is Required

**Without outlier detection**, Envoy can't detect that local endpoints are unhealthy. If all local pods are down but outlier detection isn't configured, Envoy will keep sending traffic to the dead local pods instead of failing over to another zone.

```
Scenario: All pods in us-east-1a are unhealthy

Without outlier detection:
  Envoy in us-east-1a → keeps sending to local pods → all requests fail ✗

With outlier detection:
  Envoy detects: 5 consecutive errors → ejects local pods
  Envoy routes to us-east-1b (failover) → requests succeed ✓
```

---

## Theory: Topology-Aware Routing (Kubernetes Native)

Kubernetes also has built-in topology-aware routing that works alongside Istio:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: reviews
  annotations:
    service.kubernetes.io/topology-aware-hints: "Auto"
spec:
  ports:
  - port: 80
```

### How K8s Topology Hints Work

```
1. kube-controller-manager sets "hints" on EndpointSlices
2. Hints indicate which zone each endpoint should serve
3. kube-proxy (or Envoy) uses hints to prefer local-zone endpoints

EndpointSlice:
  endpoints:
  - addresses: ["10.0.1.5"]
    zone: us-east-1a
    hints:
      forZones:
      - name: us-east-1a     # This endpoint should serve zone a
```

### Istio Locality LB vs K8s Topology Hints

| Feature | Istio Locality LB | K8s Topology Hints |
|---------|-------------------|--------------------|
| Level | L7 (Envoy) | L4 (kube-proxy) |
| Granularity | % distribution, failover chains | Binary (same zone or not) |
| Requires outlier detection | ✅ | ❌ |
| Works with Istio | ✅ (native) | ✅ (complements Istio) |
| Failover control | Explicit failover regions | Automatic |
| Production maturity | Mature | Mature |

**Recommendation**: Use BOTH together. Istio locality LB for in-mesh traffic, K8s topology hints for non-mesh or kube-proxy-level routing.

---

## Theory: Cost Calculation

### Model: 1M Pods, 100 Services

```
Assumptions:
  - 1M pods across 3 AZs (333K per AZ)
  - Average 100 RPS per pod inter-service
  - Average 5 KB per request + response
  - All traffic between pods of different services

Without locality routing:
  Total inter-service RPS: 1M × 100 = 100M RPS
  Cross-AZ probability: 66% (2 out of 3 AZs are "other")
  Cross-AZ RPS: 100M × 66% = 66M RPS
  Data per second: 66M × 5KB = 330 GB/s
  Monthly: 330 GB/s × 86400 × 30 = 855,360 TB
  Cost at $0.01/GB: $0.01 × 855,360,000 = $8,553,600/month 💀

With locality routing (80% local):
  Cross-AZ RPS: 100M × 20% = 20M RPS
  Data per second: 20M × 5KB = 100 GB/s
  Monthly: 100 GB/s × 86400 × 30 = 259,200 TB
  Cost at $0.01/GB: $0.01 × 259,200,000 = $2,592,000/month

Savings: $5,961,600/month (70% reduction!)

With aggressive locality routing (95% local):
  Cross-AZ RPS: 100M × 5% = 5M RPS
  Monthly cost: ~$648,000/month
  Savings: $7,905,600/month (92% reduction!)
```

> Note: Real-world numbers vary significantly based on traffic patterns, but the principle holds — locality routing provides massive cost savings.

---

## Theory: Monitoring Inter-AZ Traffic

### Prometheus Queries for AZ Traffic

```promql
# Total cross-AZ request rate (source zone ≠ destination zone)
sum(
  rate(istio_requests_total{
    source_workload_namespace!="",
    destination_workload_namespace!=""
  }[5m])
) by (source_canonical_service, destination_canonical_service)

# Aggregate by zone labels (requires custom telemetry)
# Add zone labels to metrics via Telemetry API:
```

```yaml
# Enable zone labels in metrics
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: zone-metrics
  namespace: istio-system
spec:
  metrics:
  - providers:
    - name: prometheus
    overrides:
    - match:
        metric: REQUEST_COUNT
      tagOverrides:
        source_zone:
          value: "upstream_peer.labels['topology.istio.io/zone'].value"
        destination_zone:
          value: "downstream_peer.labels['topology.istio.io/zone'].value"
```

```promql
# Cross-AZ traffic percentage
sum(rate(istio_requests_total{source_zone!="",destination_zone!="",source_zone!=destination_zone}[5m]))
/
sum(rate(istio_requests_total{source_zone!="",destination_zone!=""}[5m]))
```

---

## Lab: Locality-Aware Routing

```bash
#!/bin/bash
# lab-locality.sh — Locality-Aware Routing Lab

echo "=== Locality-Aware Routing Lab ==="
echo "Prerequisites: Minikube with 3 nodes (or Kind with 3 nodes)"

# Step 1: Label nodes with zones
echo "[Step 1] Labeling nodes with topology zones..."
NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
ZONES=("us-east-1a" "us-east-1b" "us-east-1c")
i=0
for node in $NODES; do
  zone=${ZONES[$i]}
  kubectl label node $node topology.kubernetes.io/region=us-east-1 --overwrite
  kubectl label node $node topology.kubernetes.io/zone=$zone --overwrite
  echo "  $node → $zone"
  i=$((i + 1))
done

# Step 2: Deploy a service with pods in each zone
echo ""
echo "[Step 2] Deploying test service..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-locality
spec:
  replicas: 6
  selector:
    matchLabels:
      app: hello-locality
  template:
    metadata:
      labels:
        app: hello-locality
    spec:
      containers:
      - name: hello
        image: hashicorp/http-echo
        args: ["-text=hello from \$(hostname)"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: hello-locality
spec:
  selector:
    app: hello-locality
  ports:
  - port: 5678
EOF

sleep 10

# Step 3: Check pod distribution across zones
echo ""
echo "[Step 3] Pod distribution across zones:"
kubectl get pods -l app=hello-locality -o custom-columns=\
'NAME:.metadata.name,NODE:.spec.nodeName,STATUS:.status.phase'

# Step 4: Enable locality load balancing
echo ""
echo "[Step 4] Enabling locality load balancing..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: hello-locality
spec:
  host: hello-locality
  trafficPolicy:
    outlierDetection:
      consecutiveErrors: 5
      interval: 10s
      baseEjectionTime: 30s
    loadBalancer:
      localityLbSetting:
        enabled: true
EOF

# Step 5: Test traffic routing
echo ""
echo "[Step 5] Testing locality routing..."
echo "Sending 20 requests from a specific zone..."

# Create a pod pinned to a specific node/zone
kubectl run locality-test --image=curlimages/curl \
  --overrides='{"spec":{"nodeName":"'$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')'"}}' \
  --restart=Never -- sleep infinity 2>/dev/null

sleep 5

for i in $(seq 1 20); do
  kubectl exec locality-test -- curl -s http://hello-locality:5678 2>/dev/null
done | sort | uniq -c | sort -rn

echo ""
echo "If locality routing is working, most requests should go to pods on the same node"

# Step 6: Check Envoy's locality-aware endpoint weights
echo ""
echo "[Step 6] Envoy endpoint locality weights:"
LOCALITY_POD=$(kubectl get pod locality-test -o jsonpath='{.metadata.name}')
istioctl proxy-config endpoints $LOCALITY_POD --cluster "outbound|5678||hello-locality.default.svc.cluster.local" 2>/dev/null

# Cleanup
kubectl delete pod locality-test 2>/dev/null
kubectl delete deployment hello-locality 2>/dev/null
kubectl delete svc hello-locality 2>/dev/null
kubectl delete destinationrule hello-locality 2>/dev/null

echo ""
echo "=== Lab Complete ==="
echo ""
echo "Key takeaways:"
echo "1. Locality LB prefers same-zone endpoints (lowest cost)"
echo "2. Outlier detection MUST be enabled for failover to work"
echo "3. Use 'distribute' for fine-grained % control"
echo "4. Monitor cross-AZ traffic with zone labels in metrics"
echo "5. At 1M pods, this saves millions in cloud data transfer costs"
```

---

## Summary

| Strategy | Mechanism | Cost Reduction | Complexity |
|----------|-----------|----------------|------------|
| Locality LB | Envoy prefers same-zone | 70-90% | Low |
| Distribution mode | Fine-grained % per zone | Configurable | Medium |
| K8s Topology Hints | kube-proxy zone awareness | 50-70% | Low |
| Combined | Istio + K8s | Maximum | Medium |

## Next Module

Continue to [Module 14: Upgrade Strategy →](../14-upgrade-strategy/)

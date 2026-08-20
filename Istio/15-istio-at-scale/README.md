# Module 15: Istio at Scale (100K → 1M Pods)

> **Why this matters**: This is THE critical module for your target role. Everything you've learned in Modules 01-14 comes together here. This module covers the specific tuning, architecture decisions, and operational practices needed to run Istio at 100K and 1M pod scale.

## Table of Contents
- [Part A: Intermediate Scale (100K Pods)](#part-a-intermediate-scale-100k-pods)
- [Part B: Large Scale (1M Pods)](#part-b-large-scale-1m-pods)
- [Part C: Resource Calculations](#part-c-resource-calculations)
- [Part D: Best Practices Summary](#part-d-best-practices-summary)
- [Sample Configurations](#sample-configurations)
- [Lab: Scale Testing](#lab-scale-testing)

---

## Part A: Intermediate Scale (100K Pods)

At 100K pods, default Istio configuration starts showing strain. Here's what breaks and how to fix it.

### Issue 1: istiod CPU/Memory Spikes During Deployments

```
Symptom: 
  istiod CPU spikes to 100% during rolling deployments
  pilot_xds_push_time increases from 100ms to 10s+
  
Root cause:
  Every pod change → EDS update → push to ALL connected proxies
  100 deployments × 50 pods each = 5000 endpoint changes
  Each change triggers push to 100K proxies

Solution:
  1. Increase istiod replicas to 3-5
  2. Enable push throttling
  3. Use Sidecar resource (see below)
```

```yaml
# istiod HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: istiod
  namespace: istio-system
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: istiod
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
```

### Issue 2: Envoy Memory Per Proxy Grows

```
Symptom:
  envoy_server_memory_allocated > 100MB per proxy
  OOM kills on sidecar containers

Root cause:
  Without Sidecar resource, every Envoy gets config for ALL 10,000 services
  10K clusters × 100 endpoints each = 1M endpoint entries per proxy

Solution:
  Sidecar resource — THE most important lever at scale
```

### Issue 3: Config Push Storms

```
Symptom:
  Continuous high rate of pilot_xds_pushes
  pilot_proxy_convergence_time p99 > 30s
  "Stale" proxies that never catch up

Root cause:
  Every config change → full push to all proxies
  At 100K proxies, a push takes minutes → by then, more changes arrived

Solution:
  Push debouncing + throttling
```

### Fixes for 100K Scale

```yaml
# IstioOperator for 100K pods
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    # Limit namespace discovery (only mesh-aware namespaces)
    discoverySelectors:
    - matchLabels:
        istio-mesh: enabled

    # Default sidecar config
    defaultConfig:
      holdApplicationUntilProxyStarts: true
      concurrency: 2              # Limit Envoy worker threads
      proxyMetadata:
        ISTIO_META_DNS_CAPTURE: "true"

  components:
    pilot:
      k8s:
        # Scale istiod
        replicaCount: 3
        resources:
          requests:
            cpu: 2000m
            memory: 4Gi
          limits:
            cpu: 4000m
            memory: 8Gi
        hpaSpec:
          minReplicas: 3
          maxReplicas: 10
          metrics:
          - type: Resource
            resource:
              name: cpu
              target:
                type: Utilization
                averageUtilization: 60

        # Push throttling
        env:
        - name: PILOT_PUSH_THROTTLE
          value: "100"             # Max concurrent pushes
        - name: PILOT_DEBOUNCE_AFTER
          value: "100ms"           # Wait 100ms for more changes before pushing
        - name: PILOT_DEBOUNCE_MAX
          value: "10s"             # Max wait before pushing

  values:
    # Sidecar resource limits
    global:
      proxy:
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
```

---

## Part B: Large Scale (1M Pods)

At 1M pods, you need fundamentally different approaches.

### Architecture for 1M Pods

```
┌────────────────────────────────────────────────────────────────────┐
│                    1M Pod Istio Architecture                        │
│                                                                     │
│  Cluster 1 (200K pods)  Cluster 2 (200K pods)  Cluster N...       │
│  ┌───────────────────┐  ┌───────────────────┐                     │
│  │ istiod ×10         │  │ istiod ×10         │                    │
│  │                     │  │                     │                    │
│  │ 200 namespaces     │  │ 200 namespaces     │                    │
│  │ Each with Sidecar  │  │ Each with Sidecar  │                    │
│  │ resource scoping   │  │ resource scoping   │                    │
│  │                     │  │                     │                    │
│  │ East-West GW       │  │ East-West GW       │                    │
│  └────────┬──────────┘  └────────┬──────────┘                     │
│           └──────── cross-cluster ─────┘                           │
│                                                                     │
│  Shared:                                                            │
│  - Common root CA                                                   │
│  - Centralized metrics (Thanos/Cortex/Mimir)                       │
│  - Unified dashboards                                               │
│  - GitOps for config management                                     │
└────────────────────────────────────────────────────────────────────┘
```

### Critical Components at 1M Scale

#### 1. Sidecar Resource (Non-Negotiable)

```yaml
# EVERY namespace MUST have a Sidecar resource
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: team-a
spec:
  egress:
  - hosts:
    - "./*"                        # Same namespace
    - "istio-system/*"             # Control plane
    - "shared-services/redis"      # Specific external services
    - "shared-services/kafka"
    # WITHOUT this, team-a's Envoys would get config for ALL 10K services
    # WITH this, they only get config for ~10-20 services

  # Optionally restrict inbound ports (reduce listener count)
  ingress:
  - port:
      number: 8080
      protocol: HTTP
    defaultEndpoint: 127.0.0.1:8080
```

#### 2. exportTo (Limit Config Visibility)

```yaml
# Every VirtualService should have exportTo
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
  namespace: team-a
spec:
  exportTo:
  - "."                # Only visible within team-a namespace
  - "istio-system"     # And to ingress gateways
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
```

#### 3. discoverySelectors (Limit Namespace Scope)

```yaml
# istiod only watches namespaces with this label
meshConfig:
  discoverySelectors:
  - matchLabels:
      istio-mesh: "enabled"
```

This prevents istiod from watching non-mesh namespaces (kube-system, monitoring, etc.), reducing K8s API server load.

#### 4. Push Throttling (Aggressive)

```yaml
env:
- name: PILOT_PUSH_THROTTLE
  value: "50"              # Only 50 concurrent pushes
- name: PILOT_DEBOUNCE_AFTER
  value: "500ms"           # Wait 500ms before pushing
- name: PILOT_DEBOUNCE_MAX
  value: "30s"             # Max 30s debounce
- name: PILOT_ENABLE_EDS_DEBOUNCE
  value: "true"            # Debounce endpoint changes specifically
```

#### 5. Ambient Mesh for L4-Only Workloads

```
1M pods:
  - 600K need only mTLS (L4) → Ambient mesh (ztunnel)
  - 400K need L7 features → Sidecar model or Ambient + Waypoint

Resource savings:
  Sidecar: 600K × 100MB = 60TB sidecar memory
  Ambient: 5000 nodes × 50MB = 250GB ztunnel memory
  Savings: 59.75TB memory (99.6% reduction for L4 workloads!)
```

#### 6. Disable Unused Features

```yaml
meshConfig:
  # Disable access logging if not needed (saves CPU/memory)
  accessLogFile: ""
  
  # Reduce tracing sampling (1% instead of default)
  defaultConfig:
    tracing:
      sampling: 1.0            # 1% sampling
  
  # Disable envoy stats for non-critical workloads
  enablePrometheusMerge: false
```

---

## Part C: Resource Calculations

### istiod Resources

```
Rule of thumb:
  ~1 vCPU + 1.5 GB memory per 1,000 connected sidecars

At 100K pods:
  istiod: 100 vCPUs + 150 GB memory
  With 10 replicas: 10 vCPU + 15 GB each

At 1M pods (across 5 clusters, 200K each):
  Per cluster: 200 vCPUs + 300 GB
  Per cluster with 20 replicas: 10 vCPU + 15 GB each
  Total across 5 clusters: 100 istiod pods
```

### Envoy Sidecar Resources

```
Per proxy (WITHOUT Sidecar resource):
  Config size: ~50 MB (10K services × all endpoints)
  Memory: >150 MB
  CPU: ~0.5 vCPU

Per proxy (WITH Sidecar resource):
  Config size: ~100 KB (20 services × local endpoints)
  Memory: ~30-50 MB
  CPU: ~0.1 vCPU

At 1M pods (sidecar model):
  Without Sidecar resource: 1M × 150 MB = 150 TB ← INFEASIBLE
  With Sidecar resource: 1M × 50 MB = 50 TB ← Still massive
  
  With Ambient for L4 workloads:
    400K sidecars × 50 MB = 20 TB
    5000 ztunnels × 50 MB = 250 GB
    Total: ~20 TB ← Much more feasible
```

### Comparison Table

| Component | 10K Pods | 100K Pods | 1M Pods |
|-----------|----------|-----------|---------|
| istiod replicas | 1-2 | 3-10 | 10-50 (per cluster) |
| istiod memory | 2-4 GB | 15-40 GB | 50-300 GB (per cluster) |
| Sidecar resource needed? | Optional | Recommended | **MANDATORY** |
| Config per proxy | ~5 MB | ~20 MB | ~50 MB → ~100 KB with Sidecar |
| Total sidecar memory | 1 TB | 10 TB | 50 TB → 20 TB with Ambient |
| Push latency (p99) | <100 ms | 1-5s | 5-30s (with throttling) |
| Ambient recommended? | No | Optional | **YES** for L4 workloads |
| Multi-cluster | Optional | Recommended | **MANDATORY** |

---

## Part D: Best Practices Summary

### Priority Order (Do These First!)

```
Priority 1: 🔴 Sidecar Resource
  - Apply to EVERY namespace
  - Only include services that namespace actually calls
  - Biggest single impact on config size and push performance

Priority 2: 🔴 exportTo
  - Set on every VirtualService, DestinationRule, ServiceEntry
  - Prevents config leaking to unrelated namespaces

Priority 3: 🟡 discoverySelectors
  - Limit which namespaces istiod watches
  - Reduces K8s API server load

Priority 4: 🟡 Push Throttling
  - PILOT_PUSH_THROTTLE, PILOT_DEBOUNCE_AFTER, PILOT_DEBOUNCE_MAX
  - Prevents config storms

Priority 5: 🟡 istiod HPA
  - Scale istiod horizontally
  - Proxy connections distributed across replicas

Priority 6: 🟢 Ambient Mesh
  - For L4-only workloads (majority at most companies)
  - Dramatic resource savings

Priority 7: 🟢 Multi-Cluster
  - Spread 1M pods across 5-10 clusters
  - Each cluster handles 100K-200K pods independently

Priority 8: 🟢 Feature Selection
  - Disable access logging for non-critical workloads
  - Reduce tracing sampling to 0.1-1%
  - Limit Envoy concurrency to 2 threads
```

### Anti-Patterns at Scale

```
❌ No Sidecar resource → Config explosion (50MB per proxy)
❌ All VirtualServices are mesh-wide → Everything pushed everywhere
❌ Single istiod replica → Single point of failure + overload
❌ Full tracing sampling → Massive data volume
❌ Default Envoy concurrency → Too many threads per proxy
❌ iptables kube-proxy at 1M pods → O(n) lookup performance
❌ All workloads use sidecar → Unnecessary L7 overhead for L4 services
❌ In-place upgrades → All-or-nothing risk
```

---

## Sample Configurations

### istiod HPA (for labs)

```yaml
# istiod-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: istiod
  namespace: istio-system
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: istiod
  minReplicas: 3
  maxReplicas: 20
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Pods
        value: 2
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Pods
        value: 1
        periodSeconds: 120
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 60
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
```

### Sidecar Resource Template

```yaml
# sidecar-resource.yaml — Template for each namespace
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: ${NAMESPACE}
spec:
  egress:
  - hosts:
    - "./*"                       # Services in same namespace
    - "istio-system/*"            # Control plane
    # Add ONLY the specific services this namespace calls:
    # - "other-namespace/service-name"
  outboundTrafficPolicy:
    mode: REGISTRY_ONLY          # Block traffic to unknown services
```

### Performance Tuning MeshConfig

```yaml
# performance-tuning.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    # Limit namespace scope
    discoverySelectors:
    - matchLabels:
        istio-mesh: "enabled"

    # Disable access logging (save CPU)
    accessLogFile: ""
    
    # Reduce default config
    defaultConfig:
      concurrency: 2
      holdApplicationUntilProxyStarts: true
      proxyMetadata:
        ISTIO_META_DNS_CAPTURE: "true"
        ISTIO_META_DNS_AUTO_ALLOCATE: "true"
      tracing:
        sampling: 1.0     # 1% trace sampling

    # Outbound traffic policy
    outboundTrafficPolicy:
      mode: REGISTRY_ONLY   # Only allow traffic to registered services

  components:
    pilot:
      k8s:
        env:
        - name: PILOT_PUSH_THROTTLE
          value: "100"
        - name: PILOT_DEBOUNCE_AFTER
          value: "300ms"
        - name: PILOT_DEBOUNCE_MAX
          value: "10s"
        - name: PILOT_ENABLE_EDS_DEBOUNCE
          value: "true"
        - name: PILOT_FILTER_GATEWAY_CLUSTER_CONFIG
          value: "true"

  values:
    global:
      proxy:
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 500m
            memory: 256Mi
```

---

## Lab: Scale Testing

```bash
#!/bin/bash
# lab-scale.sh — Scale Testing Lab

echo "=== Scale Testing Lab ==="
echo "This lab measures the impact of Sidecar resource on config size"

# Step 1: Deploy some services
echo "[Step 1] Deploying test services..."
for i in $(seq 1 10); do
  kubectl create deployment svc-$i --image=nginx --replicas=2 2>/dev/null
  kubectl expose deployment svc-$i --port=80 2>/dev/null
done
sleep 15

# Step 2: Measure config WITHOUT Sidecar resource
echo ""
echo "[Step 2] Config size WITHOUT Sidecar resource:"
PRODUCT_POD=$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$PRODUCT_POD" ]; then
  CONFIG_SIZE_BEFORE=$(istioctl proxy-config all $PRODUCT_POD -o json 2>/dev/null | wc -c)
  CLUSTER_COUNT_BEFORE=$(istioctl proxy-config clusters $PRODUCT_POD 2>/dev/null | wc -l)
  ENDPOINT_COUNT_BEFORE=$(istioctl proxy-config endpoints $PRODUCT_POD 2>/dev/null | wc -l)
  
  echo "  Config size: $((CONFIG_SIZE_BEFORE / 1024)) KB"
  echo "  Clusters: $CLUSTER_COUNT_BEFORE"
  echo "  Endpoints: $ENDPOINT_COUNT_BEFORE"
fi

# Step 3: Apply Sidecar resource
echo ""
echo "[Step 3] Applying Sidecar resource (limit to same namespace + istio-system)..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: default
spec:
  egress:
  - hosts:
    - "./*"
    - "istio-system/*"
EOF

# Wait for config push
sleep 10

# Step 4: Measure config WITH Sidecar resource
echo ""
echo "[Step 4] Config size WITH Sidecar resource:"
if [ -n "$PRODUCT_POD" ]; then
  CONFIG_SIZE_AFTER=$(istioctl proxy-config all $PRODUCT_POD -o json 2>/dev/null | wc -c)
  CLUSTER_COUNT_AFTER=$(istioctl proxy-config clusters $PRODUCT_POD 2>/dev/null | wc -l)
  ENDPOINT_COUNT_AFTER=$(istioctl proxy-config endpoints $PRODUCT_POD 2>/dev/null | wc -l)
  
  echo "  Config size: $((CONFIG_SIZE_AFTER / 1024)) KB"
  echo "  Clusters: $CLUSTER_COUNT_AFTER"
  echo "  Endpoints: $ENDPOINT_COUNT_AFTER"
  
  echo ""
  echo "  Reduction:"
  if [ "$CONFIG_SIZE_BEFORE" -gt 0 ]; then
    REDUCTION=$(( (CONFIG_SIZE_BEFORE - CONFIG_SIZE_AFTER) * 100 / CONFIG_SIZE_BEFORE ))
    echo "  Config: ${REDUCTION}% smaller"
  fi
  echo "  Clusters: $CLUSTER_COUNT_BEFORE → $CLUSTER_COUNT_AFTER"
  echo "  Endpoints: $ENDPOINT_COUNT_BEFORE → $ENDPOINT_COUNT_AFTER"
fi

# Step 5: Check istiod push metrics
echo ""
echo "[Step 5] istiod push metrics:"
ISTIOD_POD=$(kubectl get pod -n istio-system -l app=istiod -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n istio-system $ISTIOD_POD -- \
  curl -s localhost:15014/metrics 2>/dev/null | \
  grep -E "^pilot_xds_push_time|^pilot_proxy_convergence" | head -5

# Cleanup
echo ""
echo "[Cleanup]"
for i in $(seq 1 10); do
  kubectl delete deployment svc-$i 2>/dev/null
  kubectl delete svc svc-$i 2>/dev/null
done
kubectl delete sidecar default 2>/dev/null

echo ""
echo "=== Lab Complete ==="
echo ""
echo "At 1M pods, the Sidecar resource is NON-NEGOTIABLE."
echo "It's the difference between 50MB and 100KB per proxy."
echo "That's the difference between 50TB and 100GB total cluster memory."
```

---

## Summary

| Scale | Key Actions |
|-------|-------------|
| **10K pods** | Default config works. Monitor metrics. |
| **100K pods** | Sidecar resource, istiod HPA (3-10), push throttling, IPVS kube-proxy |
| **1M pods** | All of above + multi-cluster, Ambient mesh, aggressive Sidecar scoping, discoverySelectors, reduced tracing/logging, revision-based upgrades |

## Next Module

Continue to [Module 16: Interview Prep →](../16-interview-prep/)

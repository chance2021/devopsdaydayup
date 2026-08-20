# Module 07: Traffic Management

> **Why this matters**: Traffic management is Istio's most used feature. From canary deployments to fault injection, gRPC load balancing to traffic mirroring — this is what you'll configure daily. At scale, understanding gRPC vs HTTP and how Envoy handles protocol detection prevents production outages.

## Table of Contents
- [Theory: Istio Traffic Management Resources](#theory-istio-traffic-management-resources)
- [Theory: Gateway](#theory-gateway)
- [Theory: VirtualService](#theory-virtualservice)
- [Theory: DestinationRule](#theory-destinationrule)
- [Theory: ServiceEntry](#theory-serviceentry)
- [Theory: Sidecar Resource](#theory-sidecar-resource)
- [Theory: EnvoyFilter](#theory-envoyfilter)
- [Theory: gRPC vs HTTP in Istio](#theory-grpc-vs-http-in-istio)
- [Lab: Traffic Management](#lab-traffic-management)

---

## Theory: Istio Traffic Management Resources

```
                    External Traffic
                          │
                   ┌──────▼──────┐
                   │   Gateway    │  ← Which hosts/ports to accept
                   └──────┬──────┘
                          │
                   ┌──────▼──────────┐
                   │ VirtualService   │  ← HOW to route (paths, headers, weights)
                   └──────┬──────────┘
                          │
                   ┌──────▼──────────┐
                   │ DestinationRule  │  ← WHERE to route (subsets, LB, circuit breaking)
                   └──────┬──────────┘
                          │
                     ┌────┴────┐
                     │ Service  │  ← Standard K8s Service (endpoint discovery)
                     └────┬────┘
                          │
                   ┌──────▼──────┐
                   │  Pods (v1)   │
                   │  Pods (v2)   │  ← Actual workloads
                   └─────────────┘
```

---

## Theory: Gateway

A Gateway configures a load balancer at the edge of the mesh (the Istio IngressGateway).

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: my-gateway
spec:
  selector:
    istio: ingressgateway    # Use Istio's default ingress gateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "app.example.com"      # Accept traffic for this host
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "app.example.com"
    tls:
      mode: SIMPLE           # TLS termination
      credentialName: app-tls # K8s Secret with cert/key
```

### Gateway vs Kubernetes Ingress vs Gateway API

| Feature | K8s Ingress | Istio Gateway | K8s Gateway API |
|---------|-------------|---------------|-----------------|
| L7 routing | Basic | Full | Full |
| TLS modes | SIMPLE | SIMPLE, MUTUAL, PASSTHROUGH | SIMPLE, MUTUAL |
| Multi-protocol | HTTP only | HTTP, HTTPS, TCP, gRPC | HTTP, HTTPS, TCP, gRPC |
| Traffic splitting | ❌ | ✅ (via VirtualService) | ✅ (via HTTPRoute) |
| Istio integration | Limited | Native | Growing (preferred in new Istio) |

**Recommendation**: For new deployments, the Kubernetes Gateway API is the future. Istio supports it natively.

---

## Theory: VirtualService

VirtualService defines traffic routing rules. It's the most powerful and most commonly used Istio resource.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews                   # Short name → reviews.default.svc.cluster.local
  gateways:
  - my-gateway                # Apply to gateway traffic
  - mesh                      # Also apply to mesh-internal traffic
  http:
  # Rule 1: Route based on header
  - match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: reviews
        subset: v2             # Jason gets v2 (black stars)

  # Rule 2: Traffic splitting (canary deployment)
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 90               # 90% to v1
    - destination:
        host: reviews
        subset: v2
      weight: 10               # 10% to v2

    # Retry policy
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: "5xx,reset,connect-failure"
    
    # Timeout
    timeout: 10s

    # Fault injection (for testing)
    fault:
      delay:
        percentage:
          value: 10            # 10% of requests get 5s delay
        fixedDelay: 5s
      abort:
        percentage:
          value: 5             # 5% of requests get HTTP 503
        httpStatus: 503

    # Traffic mirroring (shadow traffic)
    mirror:
      host: reviews
      subset: v3
    mirrorPercentage:
      value: 100               # Mirror 100% of traffic to v3
```

### Key VirtualService Match Fields
```yaml
match:
  - uri:
      exact: "/api/v1/users"        # Exact URI match
      prefix: "/api/"               # Prefix match
      regex: "/api/v[0-9]+/.*"      # Regex match
    headers:
      cookie:
        regex: "^(.*?;)?(user=dev)(;.*)?$"
    queryParams:
      version:
        exact: "v2"
    method:
      exact: "GET"
    sourceLabels:
      app: frontend                  # Only from pods with this label
    sourceNamespace: "production"    # Only from this namespace
```

---

## Theory: DestinationRule

DestinationRule defines policies applied AFTER routing. Think of it as "how to talk to the service."

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  trafficPolicy:
    # Load balancing
    loadBalancer:
      simple: LEAST_REQUEST      # ROUND_ROBIN, LEAST_REQUEST, RANDOM, PASSTHROUGH
    
    # Connection pool
    connectionPool:
      tcp:
        maxConnections: 100      # Max TCP connections
        connectTimeout: 5s
      http:
        h2UpgradePolicy: DEFAULT
        maxRequestsPerConnection: 10
        http1MaxPendingRequests: 100
        http2MaxRequests: 1000
    
    # Circuit breaker (outlier detection)
    outlierDetection:
      consecutiveErrors: 5       # Eject after 5 consecutive errors
      interval: 30s              # Check every 30s
      baseEjectionTime: 30s      # Eject for at least 30s
      maxEjectionPercent: 50     # Don't eject more than 50% of hosts
      minHealthPercent: 30       # Disable outlier detection if <30% healthy
    
    # TLS settings
    tls:
      mode: ISTIO_MUTUAL         # Use Istio mTLS

  # Subsets (versions)
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
```

### Load Balancing Algorithms

| Algorithm | Description | Best For |
|-----------|-------------|----------|
| `ROUND_ROBIN` | Rotate through endpoints | General purpose |
| `LEAST_REQUEST` | Send to least-loaded endpoint | **gRPC** (avoids hot endpoints) |
| `RANDOM` | Random selection | Simple, low overhead |
| `PASSTHROUGH` | Direct to caller-specified address | External services |
| `LEAST_CONN` | Fewest active connections | Long-lived connections |
| Consistent hash | Sticky sessions (header, cookie, IP) | Session affinity |

```yaml
# Consistent hash example (sticky sessions)
loadBalancer:
  consistentHash:
    httpHeaderName: "x-user-id"    # Route same user to same pod
    # OR
    httpCookie:
      name: "JSESSIONID"
      ttl: 0s
    # OR
    useSourceIp: true
```

---

## Theory: ServiceEntry

ServiceEntry registers external services in the mesh, allowing Istio to manage traffic to services outside the cluster.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-api
spec:
  hosts:
  - api.external-service.com
  location: MESH_EXTERNAL        # Outside the mesh
  ports:
  - number: 443
    name: https
    protocol: TLS
  resolution: DNS                 # Resolve hostname via DNS
---
# You can then apply DestinationRule for circuit breaking, retries, etc.
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: external-api-dr
spec:
  host: api.external-service.com
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 50
    outlierDetection:
      consecutiveErrors: 3
```

---

## Theory: Sidecar Resource

> ⚠️ **This is THE most important resource at scale.** Without it, every sidecar gets config for EVERY service in the mesh.

```yaml
apiVersion: networking.istio.io/v1beta1
kind: Sidecar
metadata:
  name: default
  namespace: team-a             # Applies to all pods in team-a namespace
spec:
  egress:
  - hosts:
    - "./*"                     # Services in same namespace
    - "istio-system/*"          # Istio control plane
    - "shared-services/redis"   # Specific service in another namespace
    # ONLY these services will be in this sidecar's config!
    # Without this, ALL services in the mesh would be included
```

### Impact at Scale
```
WITHOUT Sidecar resource (1M pods, 10K services):
  Each Envoy config includes: 10K clusters + 1M endpoints
  Config size: ~50MB per proxy
  Push time: ~30 seconds
  Total config in cluster: 50MB × 1M = 50PB of config data

WITH Sidecar resource (each namespace sees ~20 services):
  Each Envoy config includes: 20 clusters + 200 endpoints
  Config size: ~100KB per proxy
  Push time: ~100ms
  Total config: 100KB × 1M = 100TB (500x reduction)
```

---

## Theory: EnvoyFilter

EnvoyFilter is the escape hatch for modifying raw Envoy configuration. Use carefully — it can break things.

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: add-header
  namespace: default
spec:
  workloadSelector:
    labels:
      app: reviews
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
      listener:
        filterChain:
          filter:
            name: "envoy.filters.network.http_connection_manager"
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.lua
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.lua.v3.Lua
          inlineCode: |
            function envoy_on_request(request_handle)
              request_handle:headers():add("x-custom-header", "my-value")
            end
```

---

## Theory: gRPC vs HTTP in Istio

### Protocol Detection

Istio uses **port naming convention** to detect protocols:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-grpc-service
spec:
  ports:
  - name: grpc-api       # ← Port name starts with "grpc-" → Istio uses HTTP/2
    port: 50051
    targetPort: 50051
  - name: http-web        # ← Port name starts with "http-" → Istio uses HTTP/1.1
    port: 8080
    targetPort: 8080
  - name: tcp-data        # ← Port name starts with "tcp-" → Istio uses TCP (no L7)
    port: 9090
    targetPort: 9090
  - name: unnamed         # ← No recognized prefix → Istio auto-detects (may be wrong!)
    port: 7070
```

### Port Naming Conventions
| Prefix | Protocol | L7 Features |
|--------|----------|-------------|
| `grpc-` | HTTP/2 (gRPC) | Full (routing, retries, metrics by method) |
| `http-` | HTTP/1.1 | Full |
| `http2-` | HTTP/2 | Full |
| `https-` | HTTPS | TLS passthrough (no L7) |
| `tcp-` | Raw TCP | Limited (connection metrics only) |
| `tls-` | TLS | TLS passthrough |
| `mongo-` | MongoDB | Protocol-specific |
| `redis-` | Redis | Protocol-specific |

### Why gRPC Needs Istio (Critical Interview Topic!)

#### The Problem: HTTP/2 Multiplexing Breaks kube-proxy LB

```
HTTP/1.1 Load Balancing (works fine with kube-proxy):
  Client opens NEW TCP connection per request
  kube-proxy distributes each connection to different pods
  Result: Load is balanced ✓

gRPC (HTTP/2) Load Balancing (BROKEN with kube-proxy):
  Client opens ONE TCP connection (HTTP/2)
  ALL requests multiplexed over this SINGLE connection
  kube-proxy only load-balances at connection level
  Result: ALL requests go to ONE pod ✗ (hot pod!)
```

```
┌──────────┐     1 TCP connection     ┌──────────┐
│  Client   │ ═══════════════════════> │  Pod A   │  ← Gets ALL requests!
│           │  (1000 gRPC streams)     │ (100% CPU)│
└──────────┘                           └──────────┘
                                       ┌──────────┐
                                       │  Pod B   │  ← Gets NOTHING!
                                       │ (0% CPU) │
                                       └──────────┘
```

#### The Solution: Istio/Envoy Request-Level Load Balancing

```
With Istio:
  Client → Envoy sidecar (outbound)
    Envoy terminates the HTTP/2 connection
    Envoy opens SEPARATE connections to each upstream pod
    Envoy load-balances at the REQUEST level (not connection level)
    Each gRPC call can go to a different pod ✓

┌──────────┐  1 conn   ┌──────────┐  conn 1  ┌──────────┐
│  Client   │ ════════> │  Envoy   │ ═══════> │  Pod A   │  ← 50%
│           │  (streams)│ (sidecar)│          └──────────┘
└──────────┘            │          │  conn 2  ┌──────────┐
                        │          │ ═══════> │  Pod B   │  ← 50%
                        └──────────┘          └──────────┘
```

### gRPC-Specific VirtualService Routing

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: grpc-routing
spec:
  hosts:
  - my-grpc-service
  http:
  # Route based on gRPC service and method
  - match:
    - uri:
        prefix: "/mypackage.MyService/GetUser"    # gRPC method matching
    route:
    - destination:
        host: my-grpc-service
        subset: v2
  
  # Default route
  - route:
    - destination:
        host: my-grpc-service
        subset: v1

    # gRPC retries (retry on specific gRPC status codes)
    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: "unavailable,resource-exhausted"    # gRPC status codes
```

### gRPC Best Practices with Istio
1. **Always name your port** `grpc-<name>` — never leave it unnamed
2. **Use `LEAST_REQUEST`** load balancing (avoids hot pods)
3. **Set max connections per endpoint** to create multiple connections for better distribution
4. **Configure retries** with gRPC-specific status codes (`unavailable`, `resource-exhausted`)
5. **Enable gRPC health checking** via Envoy's native gRPC health check
6. **Be aware of deadlines**: gRPC deadline propagation works through Envoy

---

## Lab: Traffic Management

```bash
#!/bin/bash
# lab-traffic.sh — Traffic Management Hands-On Lab

echo "=== Traffic Management Lab ==="
echo "Prerequisites: Istio + Bookinfo deployed"

# Step 1: Apply destination rules (defines subsets v1, v2, v3)
echo "[Step 1] Creating DestinationRules..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
EOF

# Step 2: Route all traffic to v1
echo "[Step 2] Routing 100% traffic to reviews-v1..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 100
EOF

echo "Testing (should always show NO stars)..."
for i in $(seq 1 5); do
  kubectl exec $(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}') \
    -c ratings -- curl -s productpage:9080/productpage 2>/dev/null | \
    grep -c "glyphicon glyphicon-star" | xargs -I {} echo "Request $i: {} stars found"
done

# Step 3: Canary deployment (90/10 split)
echo ""
echo "[Step 3] Canary: 90% v1, 10% v2..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 90
    - destination:
        host: reviews
        subset: v2
      weight: 10
EOF

echo "Testing (should see ~10% black stars)..."
STARS=0
TOTAL=20
for i in $(seq 1 $TOTAL); do
  COUNT=$(kubectl exec $(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}') \
    -c ratings -- curl -s productpage:9080/productpage 2>/dev/null | \
    grep -c "glyphicon glyphicon-star")
  if [ "$COUNT" -gt 0 ]; then
    STARS=$((STARS + 1))
  fi
done
echo "Got stars in $STARS/$TOTAL requests (~$((STARS * 100 / TOTAL))%, expected ~10%)"

# Step 4: Header-based routing
echo ""
echo "[Step 4] Header-based routing (user:jason → v2)..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
  - reviews
  http:
  - match:
    - headers:
        end-user:
          exact: jason
    route:
    - destination:
        host: reviews
        subset: v2
  - route:
    - destination:
        host: reviews
        subset: v1
EOF

# Step 5: Fault injection
echo ""
echo "[Step 5] Injecting 5s delay for 100% of requests to ratings..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ratings
spec:
  hosts:
  - ratings
  http:
  - fault:
      delay:
        percentage:
          value: 100
        fixedDelay: 5s
    route:
    - destination:
        host: ratings
EOF

echo "Testing (expect ~5s latency)..."
START=$(date +%s)
kubectl exec $(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}') \
  -c ratings -- curl -s productpage:9080/productpage 2>/dev/null > /dev/null
END=$(date +%s)
echo "Request took $((END - START)) seconds (expected ~5s)"

# Step 6: Circuit breaking
echo ""
echo "[Step 6] Setting up circuit breaker..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: reviews-circuit-breaker
spec:
  host: reviews
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 1
      http:
        http1MaxPendingRequests: 1
        maxRequestsPerConnection: 1
    outlierDetection:
      consecutiveErrors: 1
      interval: 1s
      baseEjectionTime: 30s
      maxEjectionPercent: 100
EOF

echo "Generating load to trigger circuit breaker..."
echo "(In production, use Fortio or similar load generator)"

# Cleanup
echo ""
echo "[Cleanup] Removing test resources..."
kubectl delete virtualservice reviews ratings 2>/dev/null
kubectl delete destinationrule reviews reviews-circuit-breaker 2>/dev/null

echo ""
echo "=== Lab Complete ==="
echo ""
echo "What you practiced:"
echo "1. 100% routing to a specific version"
echo "2. Canary deployment (90/10 traffic split)"
echo "3. Header-based routing"
echo "4. Fault injection (delays)"
echo "5. Circuit breaking"
```

---

## Summary

| Resource | Purpose | Scale Impact |
|----------|---------|--------------|
| Gateway | Edge load balancer config | Minimal |
| VirtualService | L7 routing rules | Moderate (many routes → larger RDS) |
| DestinationRule | LB, circuit breaking, TLS | Moderate |
| ServiceEntry | Register external services | Can add to config size |
| **Sidecar** | **Limit egress scope** | **CRITICAL — 500x config reduction** |
| EnvoyFilter | Raw Envoy config patches | Can cause issues if wrong |

## Next Module

Continue to [Module 08: Security — mTLS, AuthN, AuthZ →](../08-security-mtls-authn-authz/)

# Module 10: Envoy & xDS Protocol Deep Dive

> **Why this matters**: Envoy IS the data plane. At 1M pods, understanding xDS is essential for debugging config distribution, troubleshooting connectivity, and optimizing push performance. This is the deepest technical module — mastering it puts you in the top 1% of Istio engineers.

## Table of Contents
- [Part A: Envoy Architecture](#part-a-envoy-architecture)
- [Part B: xDS Protocol Deep Dive](#part-b-xds-protocol-deep-dive)
- [Part C: Envoy Admin API](#part-c-envoy-admin-api)
- [Part D: istioctl proxy-config Commands](#part-d-istioctl-proxy-config-commands)
- [Part E: Sidecar iptables Internals](#part-e-sidecar-iptables-internals)
- [Lab: xDS Exploration](#lab-xds-exploration)

---

## Part A: Envoy Architecture

### Core Components

```
┌──────────────────────────────────────────────────────────────────────┐
│                         ENVOY PROXY                                   │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │                        LISTENERS                                 │ │
│  │  ┌─────────────────────────────────────────────┐                │ │
│  │  │  Listener (0.0.0.0:15006 — inbound)          │               │ │
│  │  │  ┌─────────────────────────────────────────┐ │               │ │
│  │  │  │  Filter Chain 1 (match: app port 8080)   │ │               │ │
│  │  │  │  ┌─────────────────────────────────────┐│ │               │ │
│  │  │  │  │  Network Filter: HTTP Connection Mgr ││ │               │ │
│  │  │  │  │  ┌──────────────────────────────────┐││ │              │ │
│  │  │  │  │  │  HTTP Filter: Router              │││ │             │ │
│  │  │  │  │  │  ┌───────────────────────────────┐│││ │             │ │
│  │  │  │  │  │  │  Route: inbound|8080|http|app ││││ │             │ │
│  │  │  │  │  │  └───────────────────────────────┘│││ │             │ │
│  │  │  │  │  └──────────────────────────────────┘││ │              │ │
│  │  │  │  └─────────────────────────────────────┘│ │               │ │
│  │  │  └─────────────────────────────────────────┘ │               │ │
│  │  └─────────────────────────────────────────────┘                │ │
│  └─────────────────────────────────────────────────────────────────┘ │
│                              │                                        │
│                              │ route match                            │
│                              ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │                        CLUSTERS                                  │ │
│  │  ┌────────────────────────────────────────────────┐             │ │
│  │  │  Cluster: inbound|8080|http|app                 │            │ │
│  │  │  Type: STATIC or EDS                            │            │ │
│  │  │  LB: ROUND_ROBIN                                │            │ │
│  │  │  ┌──────────────────────────────┐               │            │ │
│  │  │  │  Endpoints (from EDS):        │              │            │ │
│  │  │  │  - 127.0.0.1:8080 (local app) │              │            │ │
│  │  │  └──────────────────────────────┘               │            │ │
│  │  └────────────────────────────────────────────────┘             │ │
│  └─────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
```

### Concept Hierarchy

```
Listener          "What address:port am I listening on?"
  └─ Filter Chain  "Which filters to apply (based on SNI, ALPN, etc.)?"
      └─ Filter    "What processing to do (HTTP, TCP, etc.)?"
          └─ Route "Where should this request go? (match + action)"
              └─ Cluster  "What upstream service? (LB policy, circuit breaker)"
                  └─ Endpoint  "What actual IP:port to send to?"
```

### Threading Model

```
Main Thread:
  - Handles admin operations
  - Config updates (xDS)
  - Stats flushing

Worker Threads (--concurrency flag):
  - One event loop per thread
  - Handle actual request processing
  - Each connection is pinned to a worker
  
Default concurrency: # of CPUs
  At scale: Set to 2 for sidecars to limit CPU usage
    --concurrency 2

Hot Restart:
  - New Envoy process starts alongside old
  - Existing connections drain to old process
  - New connections go to new process
  - Old process exits after drain period
  - Zero-downtime proxy upgrades!
```

---

## Part B: xDS Protocol Deep Dive

### What is xDS?

xDS is the **set of discovery service APIs** that Istio (Pilot) uses to dynamically configure every Envoy proxy. The "x" stands for various resource types.

### Discovery Services

```
┌────────────────────────────────────────────────────────────────┐
│                     xDS API Family                               │
│                                                                  │
│  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐ │
│  │ LDS  │  │ RDS  │  │ CDS  │  │ EDS  │  │ SDS  │  │ ADS  │ │
│  │Listen│  │Route │  │Clust │  │Endpt │  │Secre │  │Aggre │ │
│  │Disc. │  │Disc. │  │Disc. │  │Disc. │  │Disc. │  │Disc. │ │
│  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘ │
│     │         │         │         │         │         │       │
│     └─────────┴─────────┴─────────┴─────────┴─────────┘       │
│                           │                                     │
│                     All multiplexed                              │
│                     over ADS (single                             │
│                     gRPC stream)                                │
└────────────────────────────────────────────────────────────────┘
```

### LDS — Listener Discovery Service

**What Envoy learns**: "What ports should I listen on, and how should I process traffic on each port?"

```json
// Example LDS response from istiod:
{
  "name": "0.0.0.0_8080",
  "address": {
    "socketAddress": {
      "address": "0.0.0.0",
      "portValue": 8080
    }
  },
  "filterChains": [{
    "filters": [{
      "name": "envoy.filters.network.http_connection_manager",
      "typedConfig": {
        "routeConfigName": "8080",     // ← Links to RDS
        "httpFilters": [
          {"name": "istio.metadata_exchange"},
          {"name": "istio.stats"},
          {"name": "envoy.filters.http.router"}
        ]
      }
    }]
  }]
}
```

**Istio creates listeners for**:
- Each port your service is listening on (inbound)
- Virtual outbound listener on 15001 (catches all redirected outbound traffic)
- Virtual inbound listener on 15006 (catches all redirected inbound traffic)

### RDS — Route Discovery Service

**What Envoy learns**: "How should I route HTTP requests on this listener?"

```json
// Example RDS response:
{
  "name": "8080",
  "virtualHosts": [{
    "name": "reviews.default.svc.cluster.local:8080",
    "domains": ["reviews", "reviews.default", "reviews.default.svc", "reviews.default.svc.cluster.local"],
    "routes": [{
      "match": {"prefix": "/"},
      "route": {
        "weightedClusters": {
          "clusters": [
            {"name": "outbound|8080|v1|reviews.default.svc.cluster.local", "weight": 90},
            {"name": "outbound|8080|v2|reviews.default.svc.cluster.local", "weight": 10}
          ]
        },
        "retryPolicy": {
          "retryOn": "5xx",
          "numRetries": 2,
          "perTryTimeout": "2s"
        },
        "timeout": "10s"
      }
    }]
  }]
}
```

**VirtualService YAML → RDS routes is the key mapping to understand!**

### CDS — Cluster Discovery Service

**What Envoy learns**: "What upstream services exist and how should I connect to them?"

```json
// Example CDS response:
{
  "name": "outbound|8080|v1|reviews.default.svc.cluster.local",
  "type": "EDS",                        // Endpoints come from EDS
  "edsClusterConfig": {
    "serviceName": "outbound|8080|v1|reviews.default.svc.cluster.local"
  },
  "connectTimeout": "10s",
  "lbPolicy": "ROUND_ROBIN",
  "circuitBreakers": {
    "thresholds": [{
      "maxConnections": 1024,
      "maxPendingRequests": 1024,
      "maxRequests": 1024
    }]
  },
  "transportSocket": {                  // mTLS configuration
    "name": "envoy.transport_sockets.tls",
    "typedConfig": {
      "sni": "outbound_.8080_.v1_.reviews.default.svc.cluster.local"
    }
  }
}
```

**DestinationRule → CDS cluster is the key mapping!**

### EDS — Endpoint Discovery Service

**What Envoy learns**: "What are the actual IP:port addresses for each cluster?"

```json
// Example EDS response:
{
  "clusterName": "outbound|8080|v1|reviews.default.svc.cluster.local",
  "endpoints": [{
    "locality": {
      "region": "us-east-1",
      "zone": "us-east-1a"            // Used for locality-aware routing!
    },
    "lbEndpoints": [
      {"endpoint": {"address": {"socketAddress": {"address": "10.0.1.5", "portValue": 8080}}}},
      {"endpoint": {"address": {"socketAddress": {"address": "10.0.1.6", "portValue": 8080}}}}
    ]
  }, {
    "locality": {
      "region": "us-east-1",
      "zone": "us-east-1b"
    },
    "lbEndpoints": [
      {"endpoint": {"address": {"socketAddress": {"address": "10.0.2.3", "portValue": 8080}}}}
    ]
  }]
}
```

**Kubernetes Endpoints → EDS endpoints. Pod scaling → EDS update.**

### SDS — Secret Discovery Service

**What Envoy learns**: "What TLS certificates should I use?"

```
SDS delivers:
  - Workload certificate (for mTLS)
  - CA certificate (to validate peers)
  - Key (private key for TLS)

All delivered over gRPC, rotated automatically.
No files on disk — everything in memory.
```

### ADS — Aggregated Discovery Service

**What it does**: Multiplexes ALL xDS types over a single gRPC stream.

**Why ADS matters**:
- Without ADS: Separate connections for LDS, RDS, CDS, EDS → ordering issues
  - What if Envoy gets a route (RDS) referencing a cluster (CDS) that hasn't been delivered yet?
  - Answer: Traffic would fail!
- With ADS: Single stream with ordering guarantees
  - CDS is delivered BEFORE EDS (endpoints need clusters first)
  - LDS is delivered BEFORE RDS (routes need listeners first)
  - Istio uses ADS exclusively

### xDS Protocol Flow

```
┌─────────────┐                              ┌─────────────┐
│   Envoy      │                              │   istiod     │
│   (proxy)    │                              │  (Pilot)     │
└──────┬──────┘                              └──────┬──────┘
       │                                            │
       │─── gRPC stream (ADS) ─────────────────────>│
       │    DiscoveryRequest {                       │
       │      type: "type.googleapis.com/           │
       │             envoy.config.listener.v3",     │
       │      node: {id: "productpage~10.0.1.5~    │
       │             default~cluster.local"},       │
       │      resourceNames: [],                    │
       │      version: "",                          │
       │    }                                       │
       │                                            │
       │<──────── DiscoveryResponse ────────────────│
       │    {                                       │
       │      type: "listener",                     │
       │      version: "2024-01-01T00:00:00Z/42",  │
       │      nonce: "abc123",                      │
       │      resources: [listener1, listener2...]   │
       │    }                                       │
       │                                            │
       │─── ACK (same nonce) ──────────────────────>│
       │    DiscoveryRequest {                       │
       │      version: "2024-01-01T00:00:00Z/42",  │
       │      nonce: "abc123",                      │  ← ACK
       │      responseNonce: "abc123",              │
       │    }                                       │
       │                                            │
       │    ... time passes, config changes ...     │
       │                                            │
       │<──────── Push (new config) ────────────────│
       │    {                                       │
       │      version: "2024-01-01T00:00:01Z/43",  │
       │      nonce: "def456",                      │
       │      resources: [updated resources]         │
       │    }                                       │
       │                                            │
       │─── NACK (error) ─────────────────────────>│
       │    DiscoveryRequest {                       │
       │      version: "2024-01-01T00:00:00Z/42",  │  ← OLD version
       │      nonce: "def456",                      │  ← Current nonce
       │      errorDetail: {                        │
       │        message: "invalid route config"     │  ← NACK!
       │      }                                     │
       │    }                                       │
```

### Delta xDS (Incremental)

At 1M pods, full-state xDS is inefficient — every change sends the ENTIRE resource list.

**Delta xDS** sends only what changed:

```
Full State xDS:
  Config change → istiod sends ALL 10,000 clusters to proxy
  At 1M pods: 10,000 clusters × 1M proxies = 10B cluster configs pushed

Delta xDS:
  Config change → istiod sends ONLY the 1 changed cluster
  At 1M pods: 1 cluster × 1M proxies = 1M cluster configs pushed
  10,000x improvement!
```

```
// Delta request: subscribe to specific resources
DeltaDiscoveryRequest {
  resourceNamesSubscribe: ["cluster-new"],    // Want this
  resourceNamesUnsubscribe: ["cluster-old"],  // Don't want this
}

// Delta response: only changed resources
DeltaDiscoveryResponse {
  resources: [updatedCluster],
  removedResources: ["cluster-old"],
}
```

---

## Part C: Envoy Admin API

Every Envoy sidecar exposes an admin API on port 15000.

```bash
# Port-forward to access the admin UI
kubectl port-forward <pod> 15000:15000

# Then browse: http://localhost:15000
```

### Key Admin Endpoints

| Endpoint | What It Shows | Usage |
|----------|---------------|-------|
| `/config_dump` | Full Envoy configuration (JSON) | Debug routing, clusters, listeners |
| `/config_dump?resource=dynamic_listeners` | Only dynamic listeners | Filter specific config |
| `/clusters` | All upstream cluster info + stats | Check endpoint health, connection counts |
| `/listeners` | Active listeners | What ports Envoy is listening on |
| `/stats` | All Envoy statistics | Performance metrics, error counts |
| `/stats?filter=cluster.outbound` | Filtered stats | Focused debugging |
| `/server_info` | Envoy version, uptime | Version verification |
| `/logging` | Current log levels | Change log level dynamically |
| `/logging?level=debug` | Set log level to debug | Temporary debugging (NEVER in prod) |
| `/ready` | Readiness check | Health verification |

---

## Part D: istioctl proxy-config Commands

```bash
# === LISTENERS: What ports is Envoy listening on? ===
istioctl proxy-config listeners <pod-name>
istioctl proxy-config listeners <pod-name> --port 8080
istioctl proxy-config listeners <pod-name> -o json  # Full JSON detail

# === ROUTES: How is traffic routed? ===
istioctl proxy-config routes <pod-name>
istioctl proxy-config routes <pod-name> --name 8080

# === CLUSTERS: What upstream services can this proxy reach? ===
istioctl proxy-config clusters <pod-name>
istioctl proxy-config clusters <pod-name> --fqdn reviews.default.svc.cluster.local

# === ENDPOINTS: What are the actual Pod IPs? ===
istioctl proxy-config endpoints <pod-name>
istioctl proxy-config endpoints <pod-name> --cluster "outbound|8080||reviews.default.svc.cluster.local"

# === BOOTSTRAP: Initial config (istiod address, etc.) ===
istioctl proxy-config bootstrap <pod-name>

# === SECRETS: TLS certificates ===
istioctl proxy-config secret <pod-name>

# === ALL: Everything combined ===
istioctl proxy-config all <pod-name>

# === PROXY-STATUS: Which proxies are synced? ===
istioctl proxy-status
# Output shows SYNCED or NOT SENT for each proxy
```

### Reading Cluster Names

Istio uses a convention for cluster names:

```
outbound|8080|v1|reviews.default.svc.cluster.local
   │       │    │   └── FQDN of the service
   │       │    └── Subset name (from DestinationRule)
   │       └── Port number
   └── Direction (outbound = calling out, inbound = being called)
```

---

## Part E: Sidecar iptables Internals

Detailed analysis of every iptables rule created by `istio-init`:

```bash
# Inside a pod with Istio sidecar, the NAT table looks like this:

# === PREROUTING ===
# All incoming TCP → ISTIO_INBOUND chain
-A PREROUTING -p tcp -j ISTIO_INBOUND

# === ISTIO_INBOUND ===
# Exempt Istio control ports from interception
-A ISTIO_INBOUND -p tcp --dport 15008 -j RETURN    # HBONE mTLS tunnel
-A ISTIO_INBOUND -p tcp --dport 15090 -j RETURN    # Prometheus metric scrape
-A ISTIO_INBOUND -p tcp --dport 15021 -j RETURN    # Health check
-A ISTIO_INBOUND -p tcp --dport 15020 -j RETURN    # Merged Prometheus
# All other inbound → redirect to Envoy inbound listener
-A ISTIO_INBOUND -p tcp -j ISTIO_IN_REDIRECT

# === ISTIO_IN_REDIRECT ===
-A ISTIO_IN_REDIRECT -p tcp -j REDIRECT --to-port 15006

# === OUTPUT ===
# All outgoing TCP → ISTIO_OUTPUT chain
-A OUTPUT -p tcp -j ISTIO_OUTPUT

# === ISTIO_OUTPUT ===
# From Envoy (UID 1337): don't redirect (prevents infinite loop)
-A ISTIO_OUTPUT -m owner --uid-owner 1337 -j RETURN
# Loopback from non-Envoy with Envoy GID: redirect inbound
-A ISTIO_OUTPUT -o lo ! -d 127.0.0.1/32 -m owner --gid-owner 1337 -j ISTIO_IN_REDIRECT
# Loopback from other processes: don't redirect
-A ISTIO_OUTPUT -o lo -m owner ! --gid-owner 1337 -j RETURN
# Localhost destination: don't redirect
-A ISTIO_OUTPUT -d 127.0.0.1/32 -j RETURN
# Everything else: redirect to Envoy outbound listener
-A ISTIO_OUTPUT -j ISTIO_REDIRECT

# === ISTIO_REDIRECT ===
-A ISTIO_REDIRECT -p tcp -j REDIRECT --to-port 15001
```

### Packet Trace Through iptables

```
OUTBOUND: App calling reviews:8080
────────────────────────────────────
1. App sends SYN to 10.96.100.10:8080 (ClusterIP)
2. Kernel: OUTPUT chain → -j ISTIO_OUTPUT
3. ISTIO_OUTPUT: owner UID != 1337, dest != 127.0.0.1 → -j ISTIO_REDIRECT
4. ISTIO_REDIRECT: REDIRECT --to-port 15001
5. Destination changed: 10.96.100.10:8080 → 127.0.0.1:15001
6. Envoy receives on port 15001
7. Envoy: getsockopt(SO_ORIGINAL_DST) → 10.96.100.10:8080
8. Envoy: route lookup → cluster "outbound|8080||reviews..."
9. Envoy: EDS lookup → endpoint 10.0.1.5:8080
10. Envoy sends to 10.0.1.5:8080 (from UID 1337)
11. Kernel: OUTPUT chain → -j ISTIO_OUTPUT
12. ISTIO_OUTPUT: owner UID == 1337 → RETURN (no redirect!)
13. Packet exits to network toward 10.0.1.5
```

---

## Lab: xDS Exploration

```bash
#!/bin/bash
# lab-xds.sh — xDS Protocol Exploration Lab

echo "=== xDS Protocol Exploration Lab ==="
echo "Prerequisites: Istio + Bookinfo deployed"

PRODUCT_POD=$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')

# Step 1: View all listeners
echo "[Step 1] Listeners configured on productpage proxy:"
istioctl proxy-config listeners $PRODUCT_POD
echo ""
echo "Key listeners:"
echo "  0.0.0.0:15001 — Virtual outbound (catches all outbound traffic)"
echo "  0.0.0.0:15006 — Virtual inbound (catches all inbound traffic)"

# Step 2: Trace a specific route
echo ""
echo "[Step 2] Routes for outbound traffic on port 9080:"
istioctl proxy-config routes $PRODUCT_POD --name 9080 -o json | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for rc in data:
  for vh in rc.get('virtualHosts', []):
    if 'reviews' in vh.get('name', ''):
      print(f\"VirtualHost: {vh['name']}\")
      for route in vh.get('routes', []):
        match = route.get('match', {})
        action = route.get('route', {})
        print(f\"  Match: {match}\")
        print(f\"  Action: {json.dumps(action, indent=4)[:200]}...\")
" 2>/dev/null

# Step 3: View clusters for reviews service
echo ""
echo "[Step 3] Clusters for reviews:"
istioctl proxy-config clusters $PRODUCT_POD --fqdn reviews.default.svc.cluster.local

# Step 4: View endpoints for reviews
echo ""
echo "[Step 4] Endpoints for reviews:"
istioctl proxy-config endpoints $PRODUCT_POD --cluster "outbound|9080||reviews.default.svc.cluster.local"

# Step 5: Check xDS sync status
echo ""
echo "[Step 5] Proxy sync status (all proxies):"
istioctl proxy-status

# Step 6: View istiod push history
echo ""
echo "[Step 6] Recent xDS pushes from istiod:"
ISTIOD_POD=$(kubectl get pod -n istio-system -l app=istiod -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n istio-system $ISTIOD_POD --tail=20 | grep -i "push\|xds"

# Step 7: Full config dump (WARNING: can be huge at scale!)
echo ""
echo "[Step 7] Full config dump size:"
CONFIG_SIZE=$(istioctl proxy-config all $PRODUCT_POD -o json 2>/dev/null | wc -c)
echo "Full config size: $((CONFIG_SIZE / 1024)) KB"
echo "(At 1M pods without Sidecar resource, this could be 50+ MB)"

# Step 8: Correlate VirtualService → xDS
echo ""
echo "[Step 8] Correlation: VirtualService YAML → xDS config"
echo ""
echo "VirtualService 'reviews' (if exists):"
kubectl get virtualservice reviews -o yaml 2>/dev/null | head -20

echo ""
echo "Maps to Envoy route config:"
istioctl proxy-config routes $PRODUCT_POD --name 9080 2>/dev/null | grep reviews

echo ""
echo "=== Lab Complete ==="
echo ""
echo "What you learned:"
echo "1. LDS → Listeners on specific ports"
echo "2. RDS → Route tables for each listener"
echo "3. CDS → Upstream cluster definitions"
echo "4. EDS → Actual pod IP:port endpoints"
echo "5. ADS → All of the above over a single gRPC stream"
echo "6. VirtualService → RDS routes"
echo "7. DestinationRule → CDS cluster config"
echo "8. K8s Endpoints → EDS endpoints"
```

---

## Summary

| xDS Type | Istio Source | Envoy Config | What Changes It |
|----------|-------------|-------------|-----------------|
| LDS | Service ports + Sidecar resource | Listeners | New services, port changes |
| RDS | VirtualService + Gateway | Routes | Routing rules, traffic split changes |
| CDS | DestinationRule + Services | Clusters | LB policy, circuit breaker changes |
| EDS | K8s Endpoints | Endpoints | Pod scale up/down, node changes |
| SDS | Citadel (istiod CA) | TLS certs | Certificate rotation (~every 12h) |
| ADS | All of the above | Single gRPC stream | Any change in the mesh |

## Next Module

Continue to [Module 11: Custom DNS Integration →](../11-custom-dns-integration/)

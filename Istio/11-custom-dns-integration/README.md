# Module 11: Custom DNS Integration

> **Why this matters**: At 1M pods, DNS is a critical bottleneck. CoreDNS can become overwhelmed, and integrating with custom DNS (corporate internal DNS, external cloud DNS) requires understanding Istio's DNS proxy and ServiceEntry DNS modes. Misconfigured DNS is one of the top causes of Istio outages.

## Table of Contents
- [Theory: DNS Flow in Istio](#theory-dns-flow-in-istio)
- [Theory: Istio DNS Proxying](#theory-istio-dns-proxying)
- [Theory: ServiceEntry DNS Modes](#theory-serviceentry-dns-modes)
- [Theory: Custom DNS Scenarios](#theory-custom-dns-scenarios)
- [Theory: DNS at Scale](#theory-dns-at-scale)
- [Lab: DNS Integration](#lab-dns-integration)

---

## Theory: DNS Flow in Istio

### Without Istio DNS Proxy (Default)

```
App resolves "reviews.default.svc.cluster.local"
  │
  ▼
/etc/resolv.conf: nameserver 10.96.0.10
  │
  ▼
CoreDNS Pod (10.96.0.10)
  │
  ├─ Kubernetes zone? → Query K8s API for Service
  │    └─ Returns ClusterIP: 10.96.100.10
  │
  └─ External zone? → Forward to upstream DNS (8.8.8.8)
       └─ Returns external IP

App connects to resolved IP
  │
  ▼
iptables REDIRECT → Envoy → upstream
```

### With Istio DNS Proxy (Recommended at Scale)

```
App resolves "reviews.default.svc.cluster.local"
  │
  ▼
Envoy sidecar intercepts DNS query (port 15053)
  │
  ├─ Known ServiceEntry host? → Resolve locally (no CoreDNS call!)
  │    └─ Returns auto-allocated VIP or configured address
  │
  ├─ Kubernetes service? → Forward to CoreDNS
  │    └─ Returns ClusterIP
  │
  └─ Unknown? → Forward to CoreDNS → upstream DNS
```

---

## Theory: Istio DNS Proxying

### Enabling DNS Proxy

```yaml
# Method 1: MeshConfig (mesh-wide)
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    defaultConfig:
      proxyMetadata:
        ISTIO_META_DNS_CAPTURE: "true"        # Capture DNS queries
        ISTIO_META_DNS_AUTO_ALLOCATE: "true"   # Auto-allocate VIPs for ServiceEntries
```

```yaml
# Method 2: Per-pod annotation
metadata:
  annotations:
    proxy.istio.io/config: |
      proxyMetadata:
        ISTIO_META_DNS_CAPTURE: "true"
        ISTIO_META_DNS_AUTO_ALLOCATE: "true"
```

### How DNS Capture Works

When `ISTIO_META_DNS_CAPTURE=true`:

1. `istio-init` adds an iptables rule to redirect DNS traffic (UDP port 53) to Envoy
2. Envoy listens on port 15053 for DNS queries
3. Envoy checks its internal table (built from ServiceEntries and Kubernetes services)
4. If found: responds immediately (no CoreDNS round-trip)
5. If not found: forwards to CoreDNS

### Auto-Allocate VIPs

**Problem**: ServiceEntries for TCP services need a Virtual IP (VIP) for Envoy to route them. Without a VIP, Istio can't distinguish TCP traffic to different external services on the same port.

```yaml
# This ServiceEntry has no specific address → problem for TCP!
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-db
spec:
  hosts:
  - db.external.com
  ports:
  - number: 3306
    name: tcp-mysql
    protocol: TCP
  resolution: DNS
```

**Solution**: `ISTIO_META_DNS_AUTO_ALLOCATE=true` automatically assigns a VIP (from 240.240.0.0/16 range) to each ServiceEntry host. DNS queries for `db.external.com` return this VIP, allowing Envoy to route the traffic correctly.

---

## Theory: ServiceEntry DNS Modes

The `resolution` field in ServiceEntry controls how Envoy resolves the host:

### Resolution: NONE
```yaml
spec:
  resolution: NONE                # No DNS resolution
  addresses:
  - 1.2.3.4                      # Must provide static addresses
```
- Envoy uses the provided addresses directly
- No DNS lookup performed
- Use for: Known, static IP services

### Resolution: STATIC
```yaml
spec:
  resolution: STATIC
  endpoints:
  - address: 1.2.3.4
    ports:
      https: 443
  - address: 5.6.7.8
    ports:
      https: 443
```
- Envoy uses the statically listed endpoint addresses
- No DNS lookup performed
- Use for: Services with known, stable IPs

### Resolution: DNS
```yaml
spec:
  hosts:
  - api.external.com
  resolution: DNS                  # Envoy performs DNS lookup
  ports:
  - number: 443
    name: https
    protocol: HTTPS
```
- Envoy performs DNS lookup at connection establishment
- Each new connection may get a different IP
- DNS result is cached per the TTL
- Use for: External services with changing IPs

### Resolution: DNS_ROUND_ROBIN
```yaml
spec:
  hosts:
  - api.external.com
  resolution: DNS_ROUND_ROBIN      # DNS lookup + round-robin
  ports:
  - number: 443
    name: https
    protocol: HTTPS
```
- Envoy performs DNS lookup and gets ALL addresses
- Round-robins across all resolved addresses
- Better load distribution than plain DNS
- Use for: External services behind DNS-based LB

---

## Theory: Custom DNS Scenarios

### Scenario 1: External Service with Corporate Internal DNS

```yaml
# Your company has an internal DNS: legacy-db.corp.internal
# This hostname resolves only via your corporate DNS servers

# Step 1: Create ServiceEntry
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: legacy-db
spec:
  hosts:
  - legacy-db.corp.internal
  location: MESH_EXTERNAL
  ports:
  - number: 5432
    name: tcp-postgres
    protocol: TCP
  resolution: DNS           # Envoy will DNS-lookup the hostname

# Step 2: Ensure CoreDNS forwards to corporate DNS
# CoreDNS ConfigMap:
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
        }
        forward . /etc/resolv.conf
        cache 30
    }
    corp.internal:53 {
        forward . 10.0.0.53 10.0.0.54    # Corporate DNS servers
        cache 60
    }
```

### Scenario 2: Split-Horizon DNS

Different resolution depending on whether you're inside or outside the mesh:

```yaml
# Internal services resolve to cluster IPs
# External services resolve via cloud DNS
# Some services need different IPs based on location

apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: payment-api
spec:
  hosts:
  - payment-api.company.com
  location: MESH_EXTERNAL
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  resolution: DNS
  endpoints:
  - address: internal-payment-api.company.com  # Internal endpoint
    locality: us-east-1/us-east-1a             # Locality-aware routing
  - address: external-payment-api.company.com  # External failover
    locality: us-west-2/us-west-2a
```

### Scenario 3: Wildcard ServiceEntry

```yaml
# Allow all subdomains of *.external.corp.com
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-corp
spec:
  hosts:
  - "*.external.corp.com"          # Wildcard!
  location: MESH_EXTERNAL
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  resolution: NONE                  # NONE required for wildcards
```

### Scenario 4: Integration with AWS Route53 / GCP Cloud DNS

```yaml
# For services registered in Route53 private hosted zones
# Ensure CoreDNS forwards to the VPC DNS resolver

# CoreDNS forward config
data:
  Corefile: |
    aws.internal:53 {
        forward . 169.254.169.253    # AWS VPC DNS resolver
        cache 30
    }

# Then create ServiceEntry for specific services
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: rds-database
spec:
  hosts:
  - mydb.abc123.us-east-1.rds.amazonaws.com
  location: MESH_EXTERNAL
  ports:
  - number: 5432
    name: tcp-postgres
    protocol: TCP
  resolution: DNS
```

---

## Theory: DNS at Scale

### The Problem: CoreDNS Bottleneck

At 1M pods, DNS queries can overwhelm CoreDNS:

```
1M pods × average 10 DNS queries/second = 10M DNS queries/sec
CoreDNS typical capacity: ~50K queries/sec per instance
Needed: ~200 CoreDNS replicas (or caching!)
```

### Solution 1: NodeLocal DNSCache

```
┌─────────────────────────────────────────┐
│  Node                                    │
│  ┌────────────────┐                     │
│  │ NodeLocal DNS   │ ← DaemonSet        │
│  │ Cache           │    per node         │
│  │ (169.254.20.10) │                    │
│  └───────┬────────┘                     │
│          │ cache miss                    │
│          ▼                              │
│    ┌───────────┐                        │
│    │  CoreDNS   │ ← Only for            │
│    │  (central) │   cache misses         │
│    └───────────┘                        │
│                                          │
│  Pods on this node:                      │
│  /etc/resolv.conf: 169.254.20.10        │
│  (local cache, not CoreDNS directly)    │
└─────────────────────────────────────────┘
```

Deploy NodeLocal DNSCache:
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/dns/nodelocaldns/nodelocaldns.yaml
```

### Solution 2: Istio DNS Proxy

With `ISTIO_META_DNS_CAPTURE=true`:
- ServiceEntry hosts resolved locally at the sidecar
- Kubernetes services can also be cached at the sidecar
- Reduces CoreDNS load significantly

### Solution 3: Reduce ndots

Default `ndots: 5` causes unnecessary DNS lookups:

```bash
# Resolving "api.external.com" with ndots=5:
# 1. api.external.com.default.svc.cluster.local  → NXDOMAIN
# 2. api.external.com.svc.cluster.local          → NXDOMAIN
# 3. api.external.com.cluster.local               → NXDOMAIN
# 4. api.external.com.ec2.internal                → NXDOMAIN
# 5. api.external.com                             → SUCCESS!
# That's 5 DNS queries for 1 lookup!

# Fix: Set ndots=2 in pod spec
spec:
  dnsConfig:
    options:
    - name: ndots
      value: "2"
# Now only 2 unnecessary lookups before the real one
```

---

## Lab: DNS Integration

```bash
#!/bin/bash
# lab-dns.sh — Custom DNS Integration Lab

echo "=== DNS Integration Lab ==="

# Step 1: Check current DNS config in a mesh pod
echo "[Step 1] DNS configuration in a mesh pod:"
PRODUCT_POD=$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PRODUCT_POD -c istio-proxy -- cat /etc/resolv.conf

# Step 2: Test DNS resolution
echo ""
echo "[Step 2] DNS resolution tests:"
kubectl exec $PRODUCT_POD -c istio-proxy -- \
  sh -c 'for host in reviews details ratings kubernetes.default; do
    echo "Resolving $host:"
    nslookup $host 2>/dev/null | grep -A1 "Name:"
    echo ""
  done'

# Step 3: Create a ServiceEntry with DNS resolution
echo ""
echo "[Step 3] Creating ServiceEntry for external service..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: httpbin-external
spec:
  hosts:
  - httpbin.org
  location: MESH_EXTERNAL
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  - number: 80
    name: http
    protocol: HTTP
  resolution: DNS
EOF

# Step 4: Test external service access
echo ""
echo "[Step 4] Testing external service via ServiceEntry..."
kubectl exec $PRODUCT_POD -c istio-proxy -- \
  curl -s -o /dev/null -w "HTTP %{http_code}" http://httpbin.org/ip 2>/dev/null
echo ""

# Step 5: Check Envoy's DNS resolution
echo ""
echo "[Step 5] Envoy cluster for httpbin.org:"
istioctl proxy-config clusters $PRODUCT_POD | grep httpbin

echo ""
echo "Endpoints resolved by Envoy:"
istioctl proxy-config endpoints $PRODUCT_POD | grep httpbin

# Step 6: Enable DNS proxy (if not already)
echo ""
echo "[Step 6] To enable DNS proxy mesh-wide:"
echo "istioctl install --set meshConfig.defaultConfig.proxyMetadata.ISTIO_META_DNS_CAPTURE=true --set meshConfig.defaultConfig.proxyMetadata.ISTIO_META_DNS_AUTO_ALLOCATE=true"

# Step 7: Test wildcard ServiceEntry
echo ""
echo "[Step 7] Creating wildcard ServiceEntry..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: google-apis
spec:
  hosts:
  - "*.googleapis.com"
  location: MESH_EXTERNAL
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  resolution: NONE
EOF

# Cleanup
echo ""
echo "[Cleanup]"
kubectl delete serviceentry httpbin-external google-apis 2>/dev/null

echo ""
echo "=== Lab Complete ==="
echo ""
echo "Key takeaways:"
echo "1. Istio DNS proxy reduces CoreDNS load at scale"
echo "2. ServiceEntry resolution modes (NONE, STATIC, DNS, DNS_ROUND_ROBIN)"
echo "3. Auto-allocate VIPs solve TCP routing for DNS-based services"
echo "4. ndots=5 causes 4x unnecessary DNS queries — reduce at scale"
echo "5. NodeLocal DNSCache + Istio DNS proxy = minimal CoreDNS pressure"
```

---

## Summary

| DNS Feature | What It Does | Scale Impact |
|-------------|-------------|--------------|
| DNS Proxy | Resolves ServiceEntry hosts at sidecar | Reduces CoreDNS queries |
| Auto-Allocate | Generates VIPs for DNS-based services | Enables TCP routing |
| NodeLocal DNS | Per-node DNS cache | Reduces CoreDNS load 10x |
| ndots reduction | Fewer unnecessary DNS lookups | Reduces DNS queries 4x |
| Wildcard ServiceEntry | Allow entire domains | Simplifies external access |

## Next Module

Continue to [Module 12: Multi-Cluster Istio →](../12-multi-cluster/)

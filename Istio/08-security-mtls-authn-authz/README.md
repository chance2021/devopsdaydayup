# Module 08: Security — mTLS, Authentication & Authorization

> **Why this matters**: Zero-trust networking is the foundation of service mesh security at scale. At 1M pods, you need automated mTLS everywhere, fine-grained authorization, and the ability to explain the entire certificate lifecycle in an interview.

## Table of Contents
- [Part A: mTLS Deep Dive](#part-a-mtls-deep-dive)
- [Part B: Authentication (AuthN)](#part-b-authentication-authn)
- [Part C: Authorization (AuthZ)](#part-c-authorization-authz)
- [Lab: Security Hands-On](#lab-security-hands-on)

---

## Part A: mTLS Deep Dive

### SPIFFE Identity

Every workload in the mesh gets a cryptographic identity using the [SPIFFE](https://spiffe.io/) standard:

```
spiffe://<trust-domain>/ns/<namespace>/sa/<service-account>

Example:
spiffe://cluster.local/ns/default/sa/reviews
        └── trust domain ──┘   └ namespace ┘  └ svc account ┘
```

This identity is embedded in the X.509 certificate's SAN (Subject Alternative Name).

### Certificate Lifecycle (Step by Step)

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Certificate Issuance                               │
│                                                                      │
│  1. Pod starts → Envoy sidecar initializes                          │
│     │                                                                │
│  2. Envoy generates a private key (in memory, never on disk)        │
│     │                                                                │
│  3. Envoy creates a CSR (Certificate Signing Request)                │
│     │                                                                │
│  4. Envoy sends CSR to istiod via SDS (Secret Discovery Service)    │
│     │  over a gRPC stream, authenticated with K8s service account   │
│     │  token (JWT mounted at /var/run/secrets/...)                   │
│     │                                                                │
│  5. istiod validates the request:                                    │
│     │  a. Calls K8s TokenReview API to verify the SA token          │
│     │  b. Extracts namespace + service account from the token       │
│     │  c. Builds SPIFFE ID: spiffe://cluster.local/ns/X/sa/Y       │
│     │                                                                │
│  6. istiod signs the certificate with its CA private key             │
│     │  (or delegates to external CA: Vault, cert-manager, etc.)     │
│     │                                                                │
│  7. istiod returns signed certificate + CA chain via SDS             │
│     │                                                                │
│  8. Envoy installs the certificate and starts accepting mTLS        │
│                                                                      │
│  Certificate details:                                                │
│  - TTL: 24 hours (default, configurable)                             │
│  - Rotation: Automatically at ~12 hours (50% of TTL)                │
│  - Key: RSA 2048 or EC P256                                         │
│  - No disk persistence: cert & key live in Envoy memory only        │
└─────────────────────────────────────────────────────────────────────┘
```

### PeerAuthentication Modes

```yaml
# Mesh-wide: all services require mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system       # mesh-wide when in istio-system
spec:
  mtls:
    mode: STRICT                # Only accept mTLS connections
```

| Mode | Behavior | Use Case |
|------|----------|----------|
| `STRICT` | Only mTLS, reject plaintext | Production (after migration) |
| `PERMISSIVE` | Accept both mTLS and plaintext | **Migration period** (critical!) |
| `DISABLE` | No mTLS enforcement | Debugging, non-mesh services |
| `UNSET` | Inherit from parent | Default |

### Migration Path to STRICT mTLS

```
Step 1: Enable Istio with PERMISSIVE mode (default)
        → Both mTLS and plaintext work
        → Non-mesh services can still communicate

Step 2: Gradually add sidecars to all services
        → As services get sidecars, they automatically use mTLS

Step 3: Monitor mTLS adoption:
        → Check metrics: connection_security_policy="mutual_tls" vs "none"
        → Use Kiali to visualize which connections are mTLS

Step 4: When 100% mTLS:
        → Switch to STRICT mode
        → Any plaintext connection will be REJECTED
```

### Precedence Rules

```
Most specific wins:
  Workload-level (matchLabels) > Namespace-level > Mesh-level

Example:
  Mesh: STRICT (everything requires mTLS)
  Namespace "legacy": PERMISSIVE (legacy namespace can accept plaintext)
  Pod "health-check": DISABLE (specific pod exempted)
```

### External CA Integration

```yaml
# Using cert-manager as external CA
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  meshConfig:
    caCertificates:
    - certSigners:
      - clusterissuers.cert-manager.io/istio-ca
  values:
    pilot:
      env:
        EXTERNAL_CA: ISTIOD_RA_KUBERNETES_API
```

### Verifying mTLS

```bash
# Check certificate details
istioctl proxy-config secret <pod-name> -o json | \
  python3 -c "
import json,sys,base64
data = json.load(sys.stdin)
for s in data.get('dynamicActiveSecrets', []):
    cert = s.get('secret', {}).get('tlsCertificate', {}).get('certificateChain', {}).get('inlineBytes', '')
    if cert:
        import subprocess
        result = subprocess.run(['openssl', 'x509', '-text', '-noout'],
            input=base64.b64decode(cert), capture_output=True)
        print(result.stdout.decode())
"

# Verify mTLS is active between two pods
istioctl x describe pod <pod-name>

# Check if connection is mTLS or plaintext
kubectl exec <pod> -c istio-proxy -- \
  curl -s http://localhost:15000/stats | grep "ssl.handshake"
```

---

## Part B: Authentication (AuthN)

### PeerAuthentication (mTLS Identity)
Covered above — verifies the **service identity** via mTLS certificates.

### RequestAuthentication (JWT Validation)

Validates JWT tokens at the mesh layer — before the request reaches your application.

```yaml
apiVersion: security.istio.io/v1beta1
kind: RequestAuthentication
metadata:
  name: jwt-auth
  namespace: default
spec:
  selector:
    matchLabels:
      app: my-api
  jwtRules:
  - issuer: "https://accounts.google.com"
    jwksUri: "https://www.googleapis.com/oauth2/v3/certs"
    # OR inline:
    # jwks: |
    #   { "keys": [...] }
    audiences:
    - "my-api.example.com"
    forwardOriginalToken: true    # Forward JWT to upstream
    outputPayloadToHeader: "x-jwt-payload"  # Extract claims to header
```

### How JWT Auth Works in Istio

```
1. Client sends request with: Authorization: Bearer <JWT>
2. Envoy intercepts the request
3. Envoy validates:
   a. Token signature (using JWKS from issuer)
   b. Token expiration (exp claim)
   c. Issuer matches (iss claim)
   d. Audience matches (aud claim)
4. If valid:
   a. Extract claims
   b. Set x-jwt-payload header (if configured)
   c. Forward request to application
5. If invalid:
   a. Return 401 Unauthorized
   b. Request never reaches the application
```

**Important**: `RequestAuthentication` only validates the token IF it's present. It does NOT require a token. To require authentication, combine with `AuthorizationPolicy`.

---

## Part C: Authorization (AuthZ)

### AuthorizationPolicy

This is Istio's RBAC system. It controls **who can access what**.

```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-reviews
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  action: ALLOW                  # ALLOW, DENY, CUSTOM, AUDIT
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/default/sa/productpage"   # SPIFFE identity
        namespaces:
        - "default"
    to:
    - operation:
        methods: ["GET"]
        paths: ["/api/*"]
    when:
    - key: request.headers[x-token]
      values: ["admin", "superuser"]
```

### Evaluation Order (Critical for Interviews!)

```
Request arrives at Envoy
        │
        ▼
┌───────────────┐
│  CUSTOM action │ → External authz (e.g., OPA) → ALLOW or DENY
└───────┬───────┘
        │ (if no CUSTOM or CUSTOM allows)
        ▼
┌───────────────┐
│  DENY policies │ → If ANY deny rule matches → DENY (403)
└───────┬───────┘
        │ (if no DENY match)
        ▼
┌───────────────┐
│ ALLOW policies │ → If ANY allow rule matches → ALLOW
└───────┬───────┘
        │ (if no ALLOW match)
        ▼
┌────────────────────────────────────────┐
│ Default behavior:                       │
│  - No policies exist → ALLOW           │
│  - Any ALLOW policy exists → DENY      │
│    (deny-by-default once ALLOW exists) │
└────────────────────────────────────────┘
```

### Common Authorization Patterns

#### Pattern 1: Zero-Trust (Deny-All + Explicit Allow)

```yaml
# Step 1: Deny all traffic to namespace
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  {}  # Empty spec = deny all (because no rules match)
---
# Step 2: Allow specific service-to-service
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-productpage-to-reviews
  namespace: production
spec:
  selector:
    matchLabels:
      app: reviews
  action: ALLOW
  rules:
  - from:
    - source:
        principals:
        - "cluster.local/ns/production/sa/productpage"
    to:
    - operation:
        methods: ["GET", "POST"]
```

#### Pattern 2: Namespace Isolation

```yaml
# Only allow traffic from within the same namespace
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: namespace-isolation
  namespace: team-a
spec:
  action: ALLOW
  rules:
  - from:
    - source:
        namespaces: ["team-a"]
```

#### Pattern 3: JWT Claim-Based Access

```yaml
# Combine RequestAuthentication + AuthorizationPolicy
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: require-jwt
spec:
  selector:
    matchLabels:
      app: my-api
  action: ALLOW
  rules:
  - from:
    - source:
        requestPrincipals: ["*"]    # Any valid JWT
    when:
    - key: request.auth.claims[role]
      values: ["admin"]             # Must have role=admin claim
    to:
    - operation:
        paths: ["/admin/*"]
```

#### Pattern 4: Deny Specific Paths

```yaml
# Block access to sensitive endpoints
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-admin-external
spec:
  selector:
    matchLabels:
      app: my-api
  action: DENY
  rules:
  - from:
    - source:
        notNamespaces: ["admin"]    # Deny if NOT from admin namespace
    to:
    - operation:
        paths: ["/admin/*", "/debug/*", "/metrics"]
```

---

## Lab: Security Hands-On

```bash
#!/bin/bash
# lab-security.sh — Security Lab: mTLS, AuthN, AuthZ

echo "=== Security Lab ==="
echo "Prerequisites: Istio + Bookinfo deployed"

# Step 1: Check current mTLS status
echo "[Step 1] Current mTLS status:"
istioctl x describe pod $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')

# Step 2: Verify mTLS with tcpdump (encrypted traffic)
echo ""
echo "[Step 2] Verify traffic is encrypted (mTLS)..."
echo "Starting tcpdump in productpage pod..."
PRODUCTPAGE_POD=$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')

# Capture a few packets
kubectl exec $PRODUCTPAGE_POD -c istio-proxy -- \
  timeout 5 tcpdump -i eth0 -c 10 -A 'port 9080' 2>/dev/null | head -30 || \
  echo "(tcpdump may need elevated permissions — the traffic should be encrypted, not readable as plaintext)"

# Step 3: Check certificates
echo ""
echo "[Step 3] Certificate details:"
istioctl proxy-config secret $PRODUCTPAGE_POD

# Step 4: Enable STRICT mTLS
echo ""
echo "[Step 4] Enabling STRICT mTLS..."
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT
EOF

# Step 5: Test that non-mesh clients are rejected
echo ""
echo "[Step 5] Testing that non-mesh (no sidecar) clients are rejected..."
kubectl run no-sidecar --image=busybox:1.36 --restart=Never \
  --overrides='{"metadata":{"annotations":{"sidecar.istio.io/inject":"false"}}}' \
  --rm -it -- wget -qO- --timeout=3 http://productpage:9080 2>/dev/null && \
  echo "CONNECTED (unexpected with STRICT mTLS)" || \
  echo "REJECTED ✓ (expected — no mTLS certificate)"

# Step 6: Deny-all + explicit allow
echo ""
echo "[Step 6] Implementing zero-trust (deny-all + allow)..."

# Deny all traffic to reviews
kubectl apply -f - <<EOF
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all-reviews
  namespace: default
spec:
  selector:
    matchLabels:
      app: reviews
  action: DENY
  rules:
  - from:
    - source:
        notPrincipals:
        - "cluster.local/ns/default/sa/bookinfo-productpage"
EOF

echo "Testing: productpage → reviews (should work)..."
kubectl exec $(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}') \
  -c istio-proxy -- curl -s http://reviews:9080/reviews/0 2>/dev/null | head -1 && \
  echo "✓ productpage can reach reviews" || echo "✗ blocked"

echo "Testing: ratings → reviews (should be blocked)..."
kubectl exec $(kubectl get pod -l app=ratings -o jsonpath='{.items[0].metadata.name}') \
  -c ratings -- curl -s --max-time 3 http://reviews:9080/reviews/0 2>/dev/null && \
  echo "✗ ratings can reach reviews (unexpected)" || \
  echo "✓ ratings blocked from reviews (expected)"

# Step 7: Check authorization in Kiali
echo ""
echo "[Step 7] View security policies in Kiali:"
echo "  istioctl dashboard kiali"
echo "  Navigate to: Graph → Display → Security"

# Cleanup
echo ""
echo "[Cleanup]"
kubectl delete peerauthentication default 2>/dev/null
kubectl delete authorizationpolicy deny-all-reviews 2>/dev/null

echo ""
echo "=== Lab Complete ==="
echo ""
echo "What you practiced:"
echo "1. Verified mTLS is active (certificate inspection)"
echo "2. Confirmed traffic encryption with tcpdump"
echo "3. Enabled STRICT mTLS (rejected plaintext connections)"
echo "4. Implemented deny-all + allow authorization (zero-trust)"
echo "5. Tested service-to-service authorization"
```

---

## Summary

| Concept | What It Does | Key for Interview |
|---------|-------------|-------------------|
| mTLS | Encrypts all traffic + verifies identity via SPIFFE certs | "Every workload gets an auto-rotated X.509 certificate with SPIFFE identity, issued by istiod's CA via SDS" |
| PeerAuthentication | Controls mTLS enforcement mode | "STRICT rejects plaintext, PERMISSIVE allows both (for migration), most specific scope wins" |
| RequestAuthentication | Validates JWT tokens at the proxy | "JWT is validated by Envoy before reaching the app, but doesn't require it — combine with AuthorizationPolicy" |
| AuthorizationPolicy | Service-to-service access control | "Evaluation order: CUSTOM → DENY → ALLOW → default. Once any ALLOW policy exists, default becomes deny" |

## Next Module

Continue to [Module 09: Observability & Metrics →](../09-observability-metrics/)

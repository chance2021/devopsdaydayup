# Module 14: Upgrade Strategy (Zero Downtime)

> **Why this matters**: Upgrading Istio across 1M pods without downtime is one of the hardest operational challenges. A bad upgrade can take down your entire production environment. This module covers revision-based canary upgrades — the only safe strategy at scale.

## Table of Contents
- [Theory: Istio Versioning](#theory-istio-versioning)
- [Theory: In-Place Upgrade (Not Recommended at Scale)](#theory-in-place-upgrade)
- [Theory: Canary Upgrade with Revisions](#theory-canary-upgrade-with-revisions)
- [Theory: Revision Tags](#theory-revision-tags)
- [Theory: Data Plane Upgrade Strategies](#theory-data-plane-upgrade-strategies)
- [Theory: Pre-Upgrade Checklist](#theory-pre-upgrade-checklist)
- [Theory: Rollback Procedure](#theory-rollback-procedure)
- [Lab: Zero-Downtime Upgrade](#lab-zero-downtime-upgrade)

---

## Theory: Istio Versioning

### Version Format
```
1.20.3
│  │  │
│  │  └── Patch: Bug fixes, security patches (safe to upgrade)
│  └──── Minor: New features, behavior changes (test first)
└─────── Major: Breaking changes (rare, careful planning)
```

### Support Policy
- Only **current (N)** and **previous (N-1)** minor versions are supported
- Control plane and data plane must be within **N±1** minor versions
- Example: istiod 1.20 works with Envoy sidecars 1.19-1.21

### Version Skew Rules
```
✅ istiod 1.20 + sidecar 1.20 (same version)
✅ istiod 1.20 + sidecar 1.19 (N-1, during upgrade)
✅ istiod 1.20 + sidecar 1.21 (N+1, after control plane rollback)
❌ istiod 1.20 + sidecar 1.18 (too old, N-2)
```

---

## Theory: In-Place Upgrade

```bash
# Simple but risky — replaces istiod in-place
istioctl upgrade -y

# What happens:
# 1. Old istiod is replaced with new version
# 2. ALL proxies must be compatible with new istiod
# 3. No gradual migration possible
# 4. Rollback requires re-installing old version
```

### Why NOT to Use at Scale

| Risk | Impact at 1M Pods |
|------|-------------------|
| Incompatible config | ALL 1M sidecars could reject new config |
| Control plane bug | ALL services affected simultaneously |
| No gradual testing | Can't validate with a subset of traffic first |
| Rollback is disruptive | Requires re-installing old version |

---

## Theory: Canary Upgrade with Revisions

This is the **RECOMMENDED** approach for production at scale.

### How Revisions Work

```
BEFORE UPGRADE:
  istiod (revision: 1-19 or "default")
    └── Serves ALL namespaces with istio-injection=enabled

DURING UPGRADE (two istiods running simultaneously):
  istiod-1-19  ← Old version, still serving most namespaces
  istiod-1-20  ← New version, serving migrated namespaces
    │
    ├── namespace-a: istio.io/rev=1-20 → uses new istiod
    ├── namespace-b: istio.io/rev=1-20 → uses new istiod
    └── namespace-c: istio-injection=enabled → uses old istiod

AFTER UPGRADE (all migrated):
  istiod-1-20  ← New version, serving ALL namespaces
  (old istiod-1-19 removed)
```

### Step-by-Step Canary Upgrade

```bash
# Step 1: Install new version alongside old (with revision label)
istioctl install --set revision=1-20 --set profile=default -y

# This creates:
#   - istiod-1-20 (new deployment)
#   - mutatingwebhookconfiguration istio-sidecar-injector-1-20
# The old istiod continues running!

# Verify both are running
kubectl get pods -n istio-system -l app=istiod
# NAME                      READY   STATUS
# istiod-5f7b4d8c5-xxx     1/1     Running   ← old
# istiod-1-20-7c9d4f5-yyy  1/1     Running   ← new

# Step 2: Migrate one namespace at a time
# Remove old label, add new revision label
kubectl label namespace test-ns istio-injection-
kubectl label namespace test-ns istio.io/rev=1-20

# Step 3: Restart pods to get new sidecar
kubectl rollout restart deployment -n test-ns

# Step 4: Verify pods use new sidecar
istioctl proxy-status | grep test-ns
# Should show proxies connected to istiod-1-20

# Verify sidecar version
kubectl get pods -n test-ns -o jsonpath='{.items[*].spec.containers[?(@.name=="istio-proxy")].image}'
# Should show new proxy version

# Step 5: Test thoroughly in the migrated namespace
# - Check error rates
# - Verify mTLS works
# - Test traffic routing
# - Check metrics

# Step 6: Migrate remaining namespaces one by one
for ns in $(kubectl get namespaces -l istio-injection=enabled -o jsonpath='{.items[*].metadata.name}'); do
  echo "Migrating namespace: $ns"
  kubectl label namespace $ns istio-injection-
  kubectl label namespace $ns istio.io/rev=1-20
  kubectl rollout restart deployment -n $ns
  # Wait and verify before next namespace
  sleep 30
  istioctl proxy-status | grep $ns
done

# Step 7: Remove old istiod
istioctl uninstall --revision=default  # or specific old revision
kubectl delete validatingwebhookconfiguration istiod-default-validator 2>/dev/null

# Step 8: Verify only new version remains
kubectl get pods -n istio-system -l app=istiod
istioctl proxy-status
```

---

## Theory: Revision Tags

Revision tags add an abstraction layer over revisions, making upgrades even smoother.

```
WITHOUT Tags:
  Namespaces labeled: istio.io/rev=1-19
  Upgrade: Change EVERY namespace label to istio.io/rev=1-20
  Risk: Manual relabeling of many namespaces

WITH Tags:
  Tag "prod" → points to revision 1-19
  Namespaces labeled: istio.io/rev=prod
  Upgrade: Change what "prod" points to (ONE command)
  Namespaces don't need relabeling!
```

### Using Revision Tags

```bash
# Step 1: Install Istio with revision
istioctl install --set revision=1-19 -y

# Step 2: Create a tag pointing to this revision
istioctl tag set prod --revision 1-19 --overwrite

# Step 3: Label namespaces with the TAG (not revision)
kubectl label namespace production istio.io/rev=prod
kubectl label namespace staging istio.io/rev=prod

# Step 4: When upgrading, install new revision
istioctl install --set revision=1-20 -y

# Step 5: Create a "canary" tag for testing
istioctl tag set canary --revision 1-20

# Step 6: Test with one namespace
kubectl label namespace staging istio.io/rev=canary --overwrite
kubectl rollout restart deployment -n staging

# Step 7: Once validated, point "prod" tag to new revision
istioctl tag set prod --revision 1-20 --overwrite

# Step 8: Restart pods in production namespaces
kubectl rollout restart deployment -n production

# Step 9: Clean up old revision
istioctl uninstall --revision=1-19
istioctl tag remove canary
```

### Revision Tags Diagram

```
BEFORE UPGRADE:
  Tag "prod" ─────→ Revision 1-19 ─────→ istiod-1-19
                          ▲
  Namespaces: istio.io/rev=prod
  (production, staging, team-a, team-b...)

DURING CANARY:
  Tag "prod" ─────→ Revision 1-19 ─────→ istiod-1-19
  Tag "canary" ───→ Revision 1-20 ─────→ istiod-1-20
                          ▲
  staging: istio.io/rev=canary (testing new version)
  production: istio.io/rev=prod (still on old version)

AFTER CUTOVER:
  Tag "prod" ─────→ Revision 1-20 ─────→ istiod-1-20
                          ▲                    (old removed)
  ALL namespaces: istio.io/rev=prod (no label changes!)
```

---

## Theory: Data Plane Upgrade Strategies

### Strategy 1: Rolling Restart (Standard)

```bash
# Restart pods namespace by namespace
kubectl rollout restart deployment -n <namespace>

# Pods get new sidecars during restart
# Zero-downtime if replicas > 1 and PDBs configured
```

**Pros**: Simple, well-understood
**Cons**: Slow at 1M pods, causes pod churn

### Strategy 2: In-Place Sidecar Update (Istio 1.19+)

```yaml
# New in Istio 1.19: update sidecar without pod restart
# Uses proxy hot-restart mechanism
metadata:
  annotations:
    proxy.istio.io/overrides: '{"image": "istio/proxyv2:1.20.0"}'
```

**Pros**: No pod restart needed, faster
**Cons**: Newer feature, less battle-tested

### Strategy 3: Blue-Green at Namespace Level

```bash
# Create new namespace with new version
kubectl create namespace production-v2
kubectl label namespace production-v2 istio.io/rev=1-20

# Deploy same workloads to new namespace
kubectl apply -n production-v2 -f production-deployments.yaml

# Shift traffic using VirtualService
# ...then decommission old namespace
```

**Pros**: Completely isolated testing
**Cons**: Double resource usage during migration

---

## Theory: Pre-Upgrade Checklist

```bash
# 1. Check compatibility
istioctl x precheck

# 2. Check version skew
istioctl version
# Ensure control plane and data plane are within N±1

# 3. Review release notes for breaking changes
# https://istio.io/latest/news/releases/

# 4. Check for deprecated APIs
istioctl analyze --all-namespaces

# 5. Backup custom resources
kubectl get virtualservice,destinationrule,gateway,\
  serviceentry,authorizationpolicy,peerauthentication,\
  envoyfilter,sidecar,telemetry -A -o yaml > istio-config-backup.yaml

# 6. Test in staging first
# Deploy new version to staging cluster
# Run traffic tests
# Check metrics and error rates

# 7. Verify webhook configurations
kubectl get mutatingwebhookconfigurations | grep istio
kubectl get validatingwebhookconfigurations | grep istio

# 8. Check istiod resource usage (ensure headroom for upgrade)
kubectl top pods -n istio-system

# 9. Plan maintenance window (even with zero-downtime, have a rollback plan)
```

---

## Theory: Rollback Procedure

```bash
# If something goes wrong during canary upgrade:

# Option 1: Revert namespace to old revision
kubectl label namespace <ns> istio.io/rev=1-19 --overwrite
kubectl rollout restart deployment -n <ns>

# Option 2: If using revision tags, revert the tag
istioctl tag set prod --revision 1-19 --overwrite
kubectl rollout restart deployment -n production

# Option 3: Nuclear — uninstall new version
istioctl uninstall --revision=1-20
# Old version (1-19) continues serving

# Verify rollback
istioctl proxy-status  # All proxies should show old version
```

---

## Lab: Zero-Downtime Upgrade

```bash
#!/bin/bash
# lab-upgrade.sh — Zero-Downtime Istio Upgrade Lab

echo "=== Zero-Downtime Upgrade Lab ==="
echo "This lab simulates a revision-based canary upgrade"

# Step 1: Check current version
echo "[Step 1] Current Istio version:"
istioctl version

CURRENT_VERSION=$(istioctl version --remote=false 2>/dev/null | head -1)
echo "Current: $CURRENT_VERSION"

# Step 2: Check proxy status before upgrade
echo ""
echo "[Step 2] Proxy status (before upgrade):"
istioctl proxy-status | head -10

# Step 3: Install a new "revision" (simulated)
echo ""
echo "[Step 3] Installing new revision..."
echo "In a real upgrade, you would run:"
echo "  istioctl install --set revision=1-20 --set profile=default -y"
echo ""
echo "This creates istiod-1-20 alongside the existing istiod"

# Step 4: Demonstrate revision tag workflow
echo ""
echo "[Step 4] Revision tag workflow:"
echo "  istioctl tag set prod --revision <current-revision>"
echo "  kubectl label namespace default istio.io/rev=prod"
echo ""
echo "  # Install new version"
echo "  istioctl install --set revision=1-20 -y"
echo ""
echo "  # Test with canary tag"
echo "  istioctl tag set canary --revision 1-20"
echo "  kubectl label namespace staging istio.io/rev=canary"
echo "  kubectl rollout restart deployment -n staging"
echo ""
echo "  # Cut over production"
echo "  istioctl tag set prod --revision 1-20 --overwrite"
echo "  kubectl rollout restart deployment -n production"

# Step 5: Verify no downtime
echo ""
echo "[Step 5] During upgrade, verify no downtime:"
echo "  # In one terminal, generate continuous traffic:"
echo "  while true; do curl -s http://\$GATEWAY_URL/productpage > /dev/null && echo OK || echo FAIL; sleep 0.5; done"
echo ""
echo "  # In another terminal, perform the upgrade"
echo "  # You should see continuous 'OK' — zero downtime!"

# Step 6: Post-upgrade validation
echo ""
echo "[Step 6] Post-upgrade validation commands:"
echo "  istioctl proxy-status  # All proxies SYNCED with new istiod"
echo "  istioctl analyze       # No config issues"
echo "  istioctl version       # Verify all versions match"

echo ""
echo "=== Lab Complete ==="
echo ""
echo "Key takeaways:"
echo "1. NEVER do in-place upgrade at scale"
echo "2. Canary upgrades let you test before committing"
echo "3. Revision tags avoid relabeling namespaces"
echo "4. Always maintain N±1 version skew"
echo "5. Rollback = revert the tag, restart pods"
```

---

## Summary

| Strategy | Downtime | Risk | Complexity | Recommended Scale |
|----------|----------|------|------------|-------------------|
| In-place | Brief | High | Low | Dev/test only |
| Canary (revisions) | Zero | Low | Medium | 100K+ pods ✅ |
| Revision tags | Zero | Lowest | Medium | 1M+ pods ✅✅ |
| Blue-green namespace | Zero | Low | High | Critical services |

## Next Module

Continue to [Module 15: Istio at Scale →](../15-istio-at-scale/)

# Module 16: Interview Preparation

> **Why this matters**: You've learned everything. Now it's time to prove it. This module contains 150+ questions organized by category, troubleshooting playbooks, and scenario-based questions that test deep understanding — exactly what you'll face in a Staff/Principal interview.

## Table of Contents
- [Architecture & Fundamentals (25 questions)](#architecture--fundamentals)
- [Sidecar & Data Plane (20 questions)](#sidecar--data-plane)
- [Traffic Management (20 questions)](#traffic-management)
- [Security: mTLS, AuthN, AuthZ (20 questions)](#security-mtls-authn-authz)
- [Observability & Metrics (15 questions)](#observability--metrics)
- [Envoy & xDS Protocol (20 questions)](#envoy--xds-protocol)
- [Scale & Performance (20 questions)](#scale--performance)
- [Multi-Cluster & Networking (15 questions)](#multi-cluster--networking)
- [Troubleshooting Playbook](#troubleshooting-playbook)
- [Scenario-Based Questions](#scenario-based-questions)

---

## Architecture & Fundamentals

### Q1: What is Istio and what problems does it solve?
**A**: Istio is a service mesh that provides traffic management, security (mTLS), observability, and policy enforcement for microservices — WITHOUT modifying application code. It uses sidecar proxies (Envoy) injected into every pod to intercept and control all network traffic.

### Q2: Explain the Istio architecture. What are the control plane and data plane?
**A**: 
- **Control plane (istiod)**: Converts Istio config into Envoy-native config, issues mTLS certificates, validates config
- **Data plane (Envoy sidecars)**: Proxy injected into every pod that handles all traffic — routing, mTLS, metrics, tracing

### Q3: What is istiod? What components does it contain?
**A**: istiod is the unified control plane binary combining:
- **Pilot**: Service discovery + xDS config distribution to Envoy
- **Citadel**: Certificate Authority for mTLS certificates
- **Galley**: Configuration validation webhook
- **Sidecar Injector**: Mutating webhook that adds sidecars to pods

### Q4: How does sidecar injection work?
**A**: When a namespace has the label `istio-injection=enabled`, Kubernetes API server calls istiod's MutatingWebhook before creating the pod. The webhook modifies the pod spec to add `istio-init` (init container) and `istio-proxy` (sidecar).

### Q5: What is the difference between `istio-injection=enabled` and `istio.io/rev=<revision>`?
**A**: `istio-injection=enabled` uses the default istiod. `istio.io/rev=1-20` uses a specific revision-tagged istiod — essential for canary upgrades where multiple istiod versions run simultaneously.

### Q6: What Istio profiles are available and when would you use each?
**A**: `default` (production: istiod + ingress GW), `demo` (learning: all components + extras), `minimal` (control plane only), `ambient` (sidecar-less mesh), `empty` (base for custom config).

### Q7: What port does istiod listen on for xDS? For webhook?
**A**: xDS: port 15010 (plaintext) or 15012 (mTLS). Webhook: port 443. Metrics: port 15014.

### Q8: How does Istio differ from a Kubernetes Ingress controller?
**A**: Ingress only handles north-south (external→cluster) traffic at the edge. Istio manages ALL traffic — north-south AND east-west (service-to-service) — plus provides mTLS, observability, and fine-grained authorization.

### Q9: What is the Kubernetes Gateway API and how does it relate to Istio?
**A**: The Gateway API is a Kubernetes-native standard for traffic routing that replaces Ingress. Istio natively supports it and it's becoming the preferred way to configure Istio gateways, replacing Istio's custom Gateway resource.

### Q10: What happens if istiod goes down?
**A**: Existing sidecars continue working with their last-known configuration. No NEW config changes will be applied, no NEW certificates will be issued, and no NEW pods will get sidecars. This is by design — the data plane is resilient to control plane failures.

### Q11-25: [Additional fundamentals]
- Q11: What is a Service Mesh and why do we need one?
- Q12: Compare Istio vs Linkerd vs Consul Connect
- Q13: What is a SPIFFE identity?
- Q14: How does Istio integrate with Kubernetes RBAC?
- Q15: What is the role of Kubernetes Services in Istio?
- Q16: Explain the concept of "mesh-wide" vs "namespace-scoped" policies
- Q17: What is `meshConfig` and where is it configured?
- Q18: How does Istio handle non-HTTP protocols (TCP, gRPC, MongoDB)?
- Q19: What is protocol detection and why does port naming matter?
- Q20: What is `holdApplicationUntilProxyStarts` and why is it important?
- Q21: What is the trust domain in Istio?
- Q22: How does Istio handle headless services?
- Q23: What is the difference between `REGISTRY_ONLY` and `ALLOW_ANY` outbound traffic policy?
- Q24: What is `istioctl analyze` and what does it check?
- Q25: What is `istioctl proxy-status` and what does SYNCED vs STALE mean?

---

## Sidecar & Data Plane

### Q26: What does the `istio-init` container do?
**A**: It runs BEFORE the app and sets up iptables rules in the pod's network namespace. It creates four chains in the NAT table: `ISTIO_INBOUND` (inbound interception), `ISTIO_IN_REDIRECT` (redirect to port 15006), `ISTIO_OUTPUT` (outbound interception), `ISTIO_REDIRECT` (redirect to port 15001). It requires `NET_ADMIN` capability.

### Q27: Why does istio-init bypass traffic from UID 1337?
**A**: UID 1337 is the Envoy process. If Envoy's own outbound traffic were redirected back to Envoy, it would create an infinite loop. The rule `-m owner --uid-owner 1337 -j RETURN` ensures Envoy's traffic goes directly to the network.

### Q28: What ports does the Envoy sidecar listen on?
**A**: 15001 (outbound virtual listener), 15006 (inbound virtual listener), 15090 (Prometheus metrics), 15021 (health check), 15000 (admin API), 15053 (DNS proxy when enabled).

### Q29: What is SO_ORIGINAL_DST and why does Envoy need it?
**A**: When iptables REDIRECTs traffic to Envoy (port 15001), the original destination IP is lost. `SO_ORIGINAL_DST` is a socket option that lets Envoy retrieve the original destination from the kernel's conntrack table. This is how Envoy knows where the traffic was actually going.

### Q30: Explain the difference between Istio CNI and istio-init.
**A**: Both set up the same iptables rules. `istio-init` does it via an init container (requires `NET_ADMIN` in the pod). Istio CNI does it via a DaemonSet on each node that runs during pod creation (no `NET_ADMIN` needed in the pod). Use CNI for hardened environments, OpenShift, GKE Autopilot.

### Q31: What is Ambient Mesh? How does it differ from the sidecar model?
**A**: Ambient mesh replaces per-pod sidecars with two layers: **ztunnel** (per-node L4 proxy for mTLS + L4 policy) and optional **waypoint proxies** (per-namespace L7 for HTTP features). No sidecar injection needed. Massive resource savings: 1 ztunnel per node vs 1 sidecar per pod.

### Q32: When would you choose sidecar over ambient?
**A**: Sidecar when you need per-pod L7 policy, EnvoyFilter/WASM, or mature production support. Ambient when you mainly need mTLS, want lower resource overhead, or have many pods that only need L4 features.

### Q33: How does the Envoy sidecar get its configuration?
**A**: Envoy reads bootstrap config (mounted ConfigMap) containing the istiod address, then opens a gRPC stream (ADS) to istiod on port 15012. istiod pushes LDS, RDS, CDS, EDS, and SDS configuration. Config is continuously updated whenever services/config change.

### Q34-45: [Additional sidecar questions]
- Q34: What is the HBONE protocol in ambient mesh?
- Q35: How does ztunnel intercept traffic?
- Q36: What is a waypoint proxy and when is it needed?
- Q37: How do you exclude specific ports from sidecar interception?
- Q38: What is `holdApplicationUntilProxyStarts` and why does it matter?
- Q39: How much memory does a typical sidecar use?
- Q40: What is Envoy hot restart?
- Q41: How do you configure sidecar resource limits?
- Q42: What is the `--concurrency` flag and what should it be set to at scale?
- Q43: How do you access the Envoy admin API?
- Q44: What is `istio-proxy` container's readiness probe?
- Q45: How does Istio handle pod startup ordering (app vs sidecar)?

---

## Traffic Management

### Q46: What is a VirtualService?
**A**: A VirtualService defines traffic routing rules — how requests are matched (by URI, header, method) and routed (to specific versions, with weights for canary, with retries/timeouts/fault injection). It maps to Envoy's RDS (Route Discovery Service) configuration.

### Q47: What is a DestinationRule?
**A**: A DestinationRule defines policies applied after routing — load balancing algorithm, connection pool settings, outlier detection (circuit breaking), TLS mode, and service subsets (versions). It maps to Envoy's CDS (Cluster Discovery Service) configuration.

### Q48: How do you implement a canary deployment with Istio?
**A**: Create a VirtualService with weighted routing (e.g., 90% to v1, 10% to v2) and a DestinationRule with subsets (v1 labels, v2 labels). Gradually shift weight. Monitor error rates. Roll back by changing weights.

### Q49: What is traffic mirroring in Istio?
**A**: Traffic mirroring sends a copy of live traffic to a "mirror" service without affecting the primary traffic path. Used for testing new versions with real production traffic. Configured via the `mirror` field in VirtualService.

### Q50: Why does gRPC load balancing not work with standard Kubernetes Services?
**A**: gRPC uses HTTP/2, which multiplexes all requests over a single TCP connection. kube-proxy load-balances at the connection level, so all requests go to one pod. Istio/Envoy solves this by load-balancing at the request level.

### Q51: What is the `Sidecar` resource and why is it critical at scale?
**A**: The Sidecar resource limits which services a namespace's sidecars can reach. Without it, every sidecar gets config for ALL services in the mesh (could be 10K+). With it, each sidecar only gets config for 10-20 services. At 1M pods, this is the difference between 50MB and 100KB config per proxy.

### Q52-65: [Additional traffic questions]
- Q52: What is a ServiceEntry?
- Q53: What is an EnvoyFilter and when should you use it?
- Q54: How does Istio handle retries and timeouts?
- Q55: What is fault injection and how do you use it?
- Q56: Explain the difference between `ROUND_ROBIN`, `LEAST_REQUEST`, and `RANDOM` LB
- Q57: How do you implement session affinity (sticky sessions)?
- Q58: What is circuit breaking and how do you configure it?
- Q59: What is `outboundTrafficPolicy` and what are the modes?
- Q60: How do you configure rate limiting in Istio?
- Q61: What is the difference between Istio Gateway and IngressGateway?
- Q62: How does gRPC routing work in Istio?
- Q63: What are consistent hash load balancing strategies?
- Q64: How does connection pooling work in DestinationRule?
- Q65: What is `exportTo` and why should you always set it?

---

## Security: mTLS, AuthN, AuthZ

### Q66: How does mTLS work in Istio?
**A**: At pod startup, Envoy sends a CSR to istiod via SDS. istiod validates the pod's Kubernetes service account token (TokenReview API), signs an X.509 certificate with SPIFFE identity, and returns it. Envoy uses this cert for all connections. Certificates auto-rotate every ~12 hours (default 24h TTL).

### Q67: What is the difference between STRICT and PERMISSIVE mTLS?
**A**: STRICT only accepts mTLS connections (rejects plaintext). PERMISSIVE accepts both mTLS and plaintext — essential during migration when some services don't have sidecars yet. Always migrate from PERMISSIVE → STRICT, never the reverse.

### Q68: Explain AuthorizationPolicy evaluation order.
**A**: CUSTOM → DENY → ALLOW → default. If CUSTOM action exists: evaluated first. Then DENY rules: if ANY match → 403. Then ALLOW rules: if ANY match → allowed. Default: if no ALLOW policy exists → allow all; if ANY ALLOW policy exists → deny by default.

### Q69: How do you implement zero-trust networking in Istio?
**A**: 1) Enable STRICT mTLS mesh-wide. 2) Apply empty AuthorizationPolicy per namespace (deny-all baseline). 3) Add specific ALLOW policies for each legitimate service-to-service call. 4) Validate with `istioctl analyze`.

### Q70-85: [Additional security questions]
- Q70: What is a SPIFFE identity? Give an example.
- Q71: How does certificate rotation work without restarting the pod?
- Q72: What is SDS (Secret Discovery Service)?
- Q73: How do you integrate an external CA (Vault, cert-manager)?
- Q74: What is RequestAuthentication and how does it differ from PeerAuthentication?
- Q75: How do you validate JWT tokens in Istio?
- Q76: How does AuthorizationPolicy source principal matching work?
- Q77: Can you do path-based authorization in Istio?
- Q78: What is the AUDIT action in AuthorizationPolicy?
- Q79: How do precedence rules work for PeerAuthentication?
- Q80: How do you verify mTLS is working with tcpdump?
- Q81: What happens when a non-mesh service calls a service with STRICT mTLS?
- Q82: How do you exclude a specific port from mTLS?
- Q83: What is the trust domain and how does it work across clusters?
- Q84: How do you rotate the root CA certificate?
- Q85: What is the CUSTOM action and when would you use it with OPA?

---

## Observability & Metrics

### Q86: What are the key metrics for Istio control plane health?
**A**: `pilot_xds_push_time` (push latency), `pilot_proxy_convergence_time` (convergence), `pilot_total_xds_rejects` (config rejections), `pilot_xds_pushes` (push rate), `citadel_server_csr_count` (cert requests). At scale, if push_time p99 > 10s, you need to scale istiod or add Sidecar resources.

### Q87: What are the golden signal metrics for the data plane?
**A**: `istio_requests_total` (request count by service, response code), `istio_request_duration_milliseconds` (latency histogram), `envoy_server_memory_allocated` (proxy memory). If memory > 100MB per proxy, config is too large — need Sidecar resource.

### Q88: Why must applications forward trace headers?
**A**: Envoy creates spans at the proxy level, but to connect spans into a distributed trace, the application must forward B3 or W3C trace context headers to downstream calls. Without this, traces are disconnected — each service has independent spans.

### Q89: How do you monitor mTLS coverage across the mesh?
**A**: Query `sum(istio_requests_total{connection_security_policy="mutual_tls"}) / sum(istio_requests_total)`. Should be >99.9% in a STRICT mTLS mesh. Low coverage indicates non-mesh services or PERMISSIVE mode.

### Q90-100: [Additional observability questions]
- Q90: What is the Telemetry API and when would you use it?
- Q91: How do you reduce metric cardinality at scale?
- Q92: How does Kiali build its service graph?
- Q93: What is the difference between Envoy stats and Istio metrics?
- Q94: How do you create a custom Prometheus alerting rule for Istio?
- Q95: What is `envoy_cluster_outlier_detection_ejections_active` telling you?
- Q96: How do you customize Envoy access logs?
- Q97: What is the impact of access logging on performance?
- Q98: How do you set up Jaeger/Zipkin with Istio?
- Q99: What trace sampling rate would you use at 1M pods?
- Q100: How do you monitor inter-AZ traffic costs?

---

## Envoy & xDS Protocol

### Q101: What is xDS? Name all the discovery services.
**A**: xDS is the API family for dynamic Envoy configuration: LDS (Listeners), RDS (Routes), CDS (Clusters), EDS (Endpoints), SDS (Secrets), ADS (Aggregated — single gRPC stream multiplexing all types). Istio uses ADS exclusively.

### Q102: Explain the xDS push flow.
**A**: 1) Envoy opens gRPC stream to istiod. 2) Sends DiscoveryRequest with node info. 3) istiod sends DiscoveryResponse with resources + version + nonce. 4) Envoy ACKs (same nonce, new version) or NACKs (same nonce, old version + error). 5) istiod pushes updates on any service/config change.

### Q103: What is ADS and why does Istio use it?
**A**: ADS (Aggregated Discovery Service) multiplexes all xDS types over a single gRPC stream. This ensures ordering guarantees: CDS before EDS (endpoints need clusters), LDS before RDS (routes need listeners). Without ADS, Envoy could get routes referencing nonexistent clusters.

### Q104: What is Delta xDS and why does it matter at scale?
**A**: Standard xDS sends FULL resource state on every change. Delta xDS sends only changed resources. At 1M pods with 10K services, a single endpoint change with full-state xDS pushes all 10K clusters. With Delta xDS, only the 1 changed cluster is pushed. Critical for reducing push bandwidth.

### Q105: How do you read an Envoy cluster name like `outbound|8080|v1|reviews.default.svc.cluster.local`?
**A**: Direction (outbound), port (8080), subset (v1 from DestinationRule), service FQDN. This naming convention helps correlate Istio config to Envoy config when debugging.

### Q106-120: [Additional Envoy/xDS questions]
- Q106: What is a listener filter chain?
- Q107: How does Envoy handle HTTP/2 vs HTTP/1.1?
- Q108: What is the Envoy threading model?
- Q109: How does Envoy hot restart work?
- Q110: What is `config_dump` and how do you use it?
- Q111: How do you correlate VirtualService YAML to Envoy routes?
- Q112: What is SO_ORIGINAL_DST?
- Q113: How do you change Envoy log level dynamically?
- Q114: What is the Envoy stats endpoint?
- Q115: How do you inspect mTLS certificates from Envoy?
- Q116: What is a WASM filter?
- Q117: How does Envoy handle health checking?
- Q118: What is a Lua filter in Envoy?
- Q119: How does Envoy implement circuit breaking?
- Q120: What is the relationship between CDS and EDS?

---

## Scale & Performance

### Q121: You're scaling to 1M pods. What are the first 3 things you configure?
**A**: 1) **Sidecar resource** in every namespace (reduces config per proxy from 50MB to 100KB). 2) **exportTo** on all VirtualService/DestinationRule (prevents config leaking). 3) **istiod HPA** with push throttling (handles the load).

### Q122: How do you calculate istiod resource requirements?
**A**: Rule of thumb: ~1 vCPU + 1.5GB per 1000 connected sidecars. At 100K pods: need 100 vCPUs, 150GB — spread across 10 replicas. At 1M pods across 5 clusters: 20 replicas per cluster at 10 vCPU + 15GB each.

### Q123: What is `PILOT_PUSH_THROTTLE` and when should you tune it?
**A**: Maximum number of concurrent xDS pushes. Default handles most cases, but at 100K+ pods, set to 50-100 to prevent istiod from being overwhelmed. Combined with `PILOT_DEBOUNCE_AFTER` (batch changes) and `PILOT_DEBOUNCE_MAX` (max wait).

### Q124: Why is the Sidecar resource the single most impactful tuning lever?
**A**: Without it, every Envoy gets config for EVERY service. At 10K services × 100 endpoints = ~1M entries per proxy = ~50MB config. With Sidecar resource limiting to 20 services = ~100KB. That's 500x reduction per proxy, 500TB → 100GB total at 1M pods.

### Q125: How does ambient mesh help at 1M pods?
**A**: At 1M pods: sidecar model = 1M Envoy instances × ~50-100MB = 50-100TB. Ambient = ~5000 ztunnels (one per node) × ~50MB = 250GB. For L4-only workloads (most services), ambient reduces sidecar memory by 99.6%.

### Q126-140: [Additional scale questions]
- Q126: What is `discoverySelectors` and why is it important?
- Q127: How do you handle Istio upgrades at 1M pods?
- Q128: What is the impact of iptables vs IPVS kube-proxy at scale?
- Q129: How does locality-aware routing reduce inter-AZ costs?
- Q130: What is the `ndots` problem and how does it affect DNS at scale?
- Q131: How do you monitor config push performance?
- Q132: What is the maximum number of endpoints Envoy can handle?
- Q133: How do you debug a "slow convergence" issue?
- Q134: What is EDS debouncing?
- Q135: How do you reduce trace storage costs at scale?
- Q136: What are the risks of EnvoyFilter at scale?
- Q137: How do you handle multi-cluster service discovery at scale?
- Q138: What is the conntrack table and why does it matter?
- Q139: How do you size the east-west gateway?
- Q140: What is the impact of disabling access logging?

---

## Multi-Cluster & Networking

### Q141: What are the multi-cluster topologies in Istio?
**A**: 1) Multi-primary flat network (each cluster has istiod, pods reach each other directly). 2) Primary-remote (one istiod serves multiple clusters). 3) Multi-primary different networks (each has istiod + east-west gateway for cross-cluster traffic). #3 is most common in production.

### Q142: What is an east-west gateway?
**A**: A dedicated Istio gateway for cross-cluster traffic (port 15443). When pods in Cluster A call services in Cluster B (on a different network), traffic goes through east-west gateways via mTLS tunnels. It handles SNI-based routing to the correct destination.

### Q143: How does cross-cluster service discovery work?
**A**: Remote secrets give each cluster's istiod API access to other clusters. istiod watches Services/Endpoints in all clusters, merges them into a single endpoint list, and pushes it to proxies via EDS. Pods see endpoints from all clusters transparently.

### Q144: How does locality-aware routing work across clusters?
**A**: Endpoints in EDS include locality info (region/zone). Envoy prefers same-zone → same-region → other-region. Cross-cluster endpoints are accessed via east-west gateway. If all same-zone endpoints are ejected (outlier detection), traffic fails over to another zone or cluster.

### Q145-155: [Additional networking questions]
- Q145: How do you set up a shared root CA across clusters?
- Q146: What is HBONE protocol in ambient mesh cross-cluster?
- Q147: How do you verify cross-cluster connectivity?
- Q148: What is the DNS proxy and why does it help at scale?
- Q149: How does ServiceEntry DNS resolution mode affect routing?
- Q150: What is split-horizon DNS in Istio?
- Q151: How do you implement cross-cluster AuthorizationPolicy?
- Q152: How does NodeLocal DNSCache work with Istio?
- Q153: What is the relationship between CNI plugins and Istio?
- Q154: How do you troubleshoot cross-cluster mTLS failures?
- Q155: How does revision-based canary upgrade work in multi-cluster?

---

## Troubleshooting Playbook

### Problem: Pod Can't Reach External Service

```
1. Check outbound traffic policy:
   kubectl get meshconfig -o yaml | grep outboundTrafficPolicy
   → If REGISTRY_ONLY, need ServiceEntry

2. Check if ServiceEntry exists:
   kubectl get serviceentry | grep <host>

3. Check sidecar egress scope:
   istioctl proxy-config clusters <pod> | grep <host>
   → If not listed, Sidecar resource is blocking it

4. Check DNS resolution:
   kubectl exec <pod> -c istio-proxy -- nslookup <host>
   → If fails, DNS issue (not Istio)

5. Check iptables interception:
   kubectl exec <pod> -c istio-proxy -- iptables -t nat -L
   → Verify ISTIO_OUTPUT chain exists
```

### Problem: 503 Errors After Enabling STRICT mTLS

```
1. Check which connections are failing:
   istioctl x describe pod <pod>
   → Shows mTLS status per connection

2. Common cause: Non-mesh client calling mesh service
   → Set PeerAuthentication to PERMISSIVE for that service
   → Or add sidecar to the client

3. Check certificate validity:
   istioctl proxy-config secret <pod>
   → Verify cert is valid and not expired

4. Check CA connectivity:
   kubectl logs -n istio-system -l app=istiod | grep "CSR\|error"
   → Look for certificate signing errors
```

### Problem: High Latency Through the Mesh

```
1. Check sidecar config size:
   istioctl proxy-config all <pod> -o json | wc -c
   → > 10MB = need Sidecar resource

2. Check Envoy memory:
   kubectl top pod <pod> --containers | grep istio-proxy
   → > 100MB = config too large

3. Check connection pool settings:
   istioctl proxy-config clusters <pod> -o json | grep maxConnections
   → Too low = queuing

4. Check circuit breaker ejections:
   istioctl proxy-config clusters <pod> | grep "outlier"
   → HIGH = endpoints being removed

5. Check istiod push latency:
   kubectl exec -n istio-system <istiod> -- curl localhost:15014/metrics | grep push_time
   → p99 > 5s = istiod overloaded
```

### Problem: Sidecar Not Injecting

```
1. Check namespace label:
   kubectl get namespace <ns> --show-labels
   → Must have istio-injection=enabled OR istio.io/rev=<tag>

2. Check webhook:
   kubectl get mutatingwebhookconfiguration | grep istio
   → Must exist and not have failures

3. Check pod annotation override:
   kubectl get pod <pod> -o yaml | grep "sidecar.istio.io/inject"
   → annotation: "false" overrides namespace label

4. Check istiod logs:
   kubectl logs -n istio-system <istiod> | grep "injection\|webhook"
```

---

## Scenario-Based Questions

### Scenario 1: "How would you roll out Istio to 1M existing pods?"

**Answer framework**:
1. **Phase 1 (Week 1-2)**: Install Istio with PERMISSIVE mTLS. Start with one team's namespace. Use revision tags for future upgrades.
2. **Phase 2 (Week 3-8)**: Roll out namespace by namespace. Apply Sidecar resource to each namespace FIRST (limit config scope). Use PERMISSIVE mTLS to avoid breaking non-mesh services.
3. **Phase 3 (Week 9-12)**: Monitor mTLS coverage via metrics. Once 100% coverage, switch to STRICT mTLS namespace by namespace.
4. **Phase 4 (Ongoing)**: Enable Ambient mesh for L4-only workloads. Implement exportTo, discoverySelectors. Scale istiod based on load.

### Scenario 2: "Design the upgrade strategy for Istio across 50 clusters"

**Answer framework**:
1. Use revision tags: `istio.io/rev=prod` on all namespaces
2. Install new version with revision in one staging cluster
3. Create `canary` tag, test in staging
4. Roll out to 3 production clusters (1 per region)
5. Monitor for 24-48 hours
6. Cut `prod` tag to new revision
7. Rolling restart across all 50 clusters (automated via CI/CD)
8. Keep old revision for 1 week as rollback option

### Scenario 3: "istiod is at 95% CPU. Diagnose and fix."

**Answer framework**:
1. **Immediate**: Check `pilot_xds_pushes` rate — if thousands/sec, there's churn
2. **Check**: `pilot_k8s_reg_events` — spikes mean many K8s changes (deployments, scaling)
3. **Check**: Number of connected proxies per istiod replica — uneven distribution?
4. **Fix**: Scale istiod replicas (HPA)
5. **Fix**: Increase `PILOT_DEBOUNCE_AFTER` to batch changes
6. **Fix**: Apply Sidecar resources to reduce config per push
7. **Fix**: Enable `discoverySelectors` to reduce watched namespaces
8. **Root cause**: Likely too many services/endpoints being pushed to too many proxies

### Scenario 4: "How would you reduce inter-AZ data transfer costs by 80%?"

**Answer framework**:
1. Label nodes with topology zones
2. Enable locality-aware routing via DestinationRule with `localityLbSetting.enabled: true`
3. Configure outlier detection (required for locality failover)
4. Use distribute mode for fine-grained control (80% local, 20% adjacent)
5. Monitor with zone labels in metrics
6. Enable K8s topology-aware hints for kube-proxy-level routing
7. Measure before/after with cross-AZ traffic metrics

### Scenario 5: "A service is seeing 503s after enabling STRICT mTLS. Diagnose."

**Answer framework**:
1. Check which specific connection is failing: `istioctl x describe pod <pod>`
2. Is the caller in the mesh? Check for sidecar: `kubectl get pod <caller> -o yaml | grep istio-proxy`
3. If no sidecar → caller can't do mTLS → either add sidecar or set PERMISSIVE for that service
4. If sidecar exists → check certificate: `istioctl proxy-config secret <pod>`
5. Check istiod CA health: `kubectl logs -n istio-system <istiod> | grep CSR`
6. Check AuthorizationPolicy: `istioctl analyze -n <namespace>`
7. Try PERMISSIVE temporarily to confirm mTLS is the cause

### Scenario 6: "Explain the complete packet path from Pod A calling Pod B via HTTP"

**Answer framework**:
```
1. App in Pod A sends HTTP request to reviews:8080
2. DNS resolves to ClusterIP (10.96.100.10)
3. App opens TCP connection to 10.96.100.10:8080
4. Kernel hits OUTPUT chain → ISTIO_OUTPUT → ISTIO_REDIRECT
5. iptables REDIRECT changes dest to 127.0.0.1:15001
6. Envoy receives on port 15001
7. Envoy retrieves original dest (10.96.100.10:8080) via SO_ORIGINAL_DST
8. Envoy matches listener → finds route → selects cluster "outbound|8080||reviews..."
9. VirtualService routing applied (weight, header match, etc.)
10. DestinationRule applied (LB algorithm, circuit breaker)
11. EDS lookup → selects endpoint 10.0.2.3:8080 (Pod B)
12. Envoy establishes mTLS connection to 10.0.2.3:15006
13. Uses SPIFFE cert from SDS, TLS handshake succeeds
14. Sends HTTP request over encrypted connection
15. Pod B's iptables: PREROUTING → ISTIO_INBOUND → ISTIO_IN_REDIRECT
16. Redirected to Envoy port 15006
17. Pod B's Envoy: checks AuthorizationPolicy → allowed
18. Forwards to localhost:8080 (the actual app in Pod B)
19. App processes request, returns response
20. Response flows back: Pod B Envoy → mTLS → Pod A Envoy → App
21. Both Envoys record metrics (request count, latency, response code)
22. Trace span created and exported
```

---

## Quick Reference Card

```
KEY PORTS:        15001 (outbound)  15006 (inbound)  15090 (metrics)
                  15021 (health)    15000 (admin)    15012 (xDS mTLS)

KEY COMMANDS:     istioctl proxy-status           # Proxy sync status
                  istioctl proxy-config all <pod>  # Full Envoy config
                  istioctl analyze                 # Config validation
                  istioctl version                 # Version info
                  istioctl x describe pod <pod>    # Pod mesh status

KEY RESOURCES:    VirtualService  → Routes (RDS)
                  DestinationRule → Clusters (CDS)
                  Sidecar         → Config scope
                  Gateway         → Edge routing
                  ServiceEntry    → External services
                  PeerAuth        → mTLS mode
                  AuthzPolicy     → Access control

KEY METRICS:      pilot_xds_push_time              # Control plane health
                  pilot_proxy_convergence_time      # Config lag
                  istio_requests_total              # Golden signal
                  envoy_server_memory_allocated     # Proxy health

SCALE LEVERS:     1. Sidecar resource (500x config reduction)
                  2. exportTo (prevent config leaking)
                  3. discoverySelectors (reduce API load)
                  4. Push throttling (prevent storms)
                  5. Ambient mesh (99.6% memory savings for L4)
```

## Congratulations! 🎓

You've completed the entire Istio Mastery Guide. You now understand Istio from Linux networking primitives through 1M-pod scale operations. Go ace that interview!

**Return to [Main README](../README.md)**

# Module 09: Observability & Istio Health Metrics

> **Why this matters**: At 1M pods, you can't SSH into pods to debug. You need metrics, traces, and dashboards that tell you instantly whether Istio is healthy or about to fail. This module covers every metric that matters and how to alert on them.

## Table of Contents
- [Part A: Observability Stack](#part-a-observability-stack)
- [Part B: Critical Istio Health Metrics](#part-b-critical-istio-health-metrics)
- [Part C: Prometheus Alerting Rules](#part-c-prometheus-alerting-rules)
- [Part D: Grafana Dashboards](#part-d-grafana-dashboards)
- [Lab: Observability](#lab-observability)

---

## Part A: Observability Stack

### Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   App Pod    │     │   App Pod    │     │   App Pod    │
│ ┌─────────┐ │     │ ┌─────────┐ │     │ ┌─────────┐ │
│ │ Envoy   │ │     │ │ Envoy   │ │     │ │ Envoy   │ │
│ │ :15090  │ │     │ │ :15090  │ │     │ │ :15090  │ │
│ └────┬────┘ │     │ └────┬────┘ │     │ └────┬────┘ │
└──────┼──────┘     └──────┼──────┘     └──────┼──────┘
       │                   │                   │
       │    Prometheus scrapes :15090           │
       └───────────────────┼───────────────────┘
                           │
                    ┌──────▼──────┐
                    │  Prometheus  │ ← Stores time series metrics
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼──────┐  ┌─▼──────┐  ┌─▼──────┐
       │   Grafana    │  │ Kiali  │  │ Alerts  │
       │ (dashboards) │  │ (graph)│  │ (PD/    │
       │              │  │        │  │ Slack)  │
       └─────────────┘  └────────┘  └────────┘

istiod also exposes metrics:
  istiod:15014 → pilot_* metrics → Prometheus
```

### Metrics Pipeline

```
Envoy generates statistics
  → Prometheus scrapes :15090/stats/prometheus
    → Standard Istio metrics:
      - istio_requests_total
      - istio_request_duration_milliseconds_bucket
      - istio_request_bytes_bucket
      - istio_response_bytes_bucket
      - istio_tcp_connections_opened_total
      - istio_tcp_connections_closed_total
      - istio_tcp_received_bytes_total
      - istio_tcp_sent_bytes_total
```

### Distributed Tracing

```
Request flow:
  Client → Envoy A → App A → Envoy A → Envoy B → App B → Envoy B → ...

Trace headers that MUST be propagated by your application:
  - x-request-id
  - x-b3-traceid
  - x-b3-spanid
  - x-b3-parentspanid
  - x-b3-sampled
  - x-b3-flags
  - traceparent (W3C)
  - tracestate (W3C)

⚠️ CRITICAL: Envoy generates spans, but your APPLICATION must forward
   trace headers to downstream calls. Istio does NOT do this automatically!
```

### Telemetry API (Reducing Cardinality at Scale)

At 1M pods, default metrics cardinality explodes. Use the Telemetry API to reduce it:

```yaml
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: reduce-cardinality
  namespace: istio-system        # mesh-wide
spec:
  metrics:
  - providers:
    - name: prometheus
    overrides:
    - match:
        metric: REQUEST_COUNT
      tagOverrides:
        destination_canonical_service:
          operation: REMOVE        # Remove a high-cardinality label
        request_protocol:
          operation: REMOVE
    - match:
        metric: ALL_METRICS
      disabled: false
  tracing:
  - randomSamplingPercentage: 1   # Only sample 1% of traces at scale
```

---

## Part B: Critical Istio Health Metrics

### Control Plane (istiod) Metrics

These tell you if istiod is healthy and keeping up with the mesh:

#### 🔴 Must-Monitor Metrics

| Metric | Description | Alert Threshold | What It Means |
|--------|-------------|-----------------|---------------|
| `pilot_xds_pushes` | Total config pushes (by type) | Rate > 1000/min | Config churn — something is causing constant updates |
| `pilot_xds_push_time` | Time to compute+push config | p99 > 10s | istiod is overloaded, proxies falling behind |
| `pilot_proxy_convergence_time` | Time for proxies to converge | p99 > 30s | Proxies are slow to apply new config |
| `pilot_total_xds_rejects` | Envoy rejecting pushed config | > 0 for 10min | Bad config — Envoy can't apply what istiod sends |
| `pilot_conflict_inbound_listener` | Inbound listener conflicts | > 0 | Two services claiming same port on same pod |
| `pilot_conflict_outbound_listener_tcp_over_current_tcp` | Outbound TCP conflicts | > 0 | TCP services with overlapping config |

#### 🟡 Important Metrics

| Metric | Description | Why It Matters |
|--------|-------------|----------------|
| `pilot_k8s_reg_events` | K8s registry events (by event type) | Spikes = many deployments happening → config churn |
| `pilot_services` | Total services in mesh | Track growth over time |
| `pilot_virt_services` | Total VirtualServices | Complexity indicator |
| `pilot_xds_expired_nonce` | Proxy sent stale version | High = proxies falling behind on config |
| `galley_validation_failed` | Config validation failures | Bad YAML being applied |
| `citadel_server_csr_count` | Certificate signing requests | Spike during deployments |
| `citadel_server_success_cert_issuance_count` | Successful cert issuances | Should match CSR count |
| `citadel_server_csr_parsing_err_count` | CSR parsing errors | > 0 = cert problems |
| `process_resident_memory_bytes` (istiod) | istiod memory usage | Track trend, scale if growing |
| `go_goroutines` (istiod) | Goroutine count | Leak indicator if growing unbounded |

### Data Plane (Envoy Sidecar) Metrics

These are the **golden signals** for your services:

#### 🔴 Golden Signal Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `istio_requests_total` | Total requests (with labels: response_code, source, dest) | Error rate > 1% |
| `istio_request_duration_milliseconds_bucket` | Request latency histogram | p99 > SLO threshold |
| `istio_tcp_connections_opened_total` | TCP connections opened | Sudden spike = connection storm |
| `istio_tcp_connections_closed_total` | TCP connections closed | Compare with opened for leak detection |

#### 🟡 Envoy Internal Metrics

| Metric | Description | Concern Level |
|--------|-------------|---------------|
| `envoy_server_memory_allocated` | Memory per proxy | > 100MB = config too large, need Sidecar resource |
| `envoy_server_live` | Proxy is alive | 0 = dead proxy |
| `envoy_cluster_upstream_cx_active` | Active upstream connections | Monitor for leaks |
| `envoy_cluster_upstream_rq_timeout` | Request timeouts | Service degradation |
| `envoy_cluster_upstream_rq_retry` | Retry count | Too many = cascading failure risk |
| `envoy_cluster_upstream_cx_connect_fail` | Connection failures | Can't reach upstream |
| `envoy_cluster_outlier_detection_ejections_active` | Circuit breaker ejections | Hosts being removed |
| `envoy_listener_downstream_cx_active` | Active downstream connections | Connection load |
| `envoy_server_total_connections` | Total proxy connections | Resource usage |

### Mesh-Wide Health Indicators

| Indicator | PromQL Query | Healthy Value |
|-----------|-------------|---------------|
| mTLS coverage | `sum(istio_requests_total{connection_security_policy="mutual_tls"}) / sum(istio_requests_total)` | > 99.9% |
| Mesh error rate | `sum(rate(istio_requests_total{response_code=~"5.."}[5m])) / sum(rate(istio_requests_total[5m]))` | < 0.1% |
| Sidecar injection | `count(kube_pod_container_info{container="istio-proxy"}) / count(kube_pod_info)` | Match expectation |
| Proxy version skew | `count by (tag) (istio_build)` | All same version |
| Cert expiry | `min(citadel_server_root_cert_expiry_timestamp) - time()` | > 30 days |

---

## Part C: Prometheus Alerting Rules

```yaml
# prometheus-alerts.yaml — Production Istio Alerting Rules
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: istio-alerts
  namespace: istio-system
spec:
  groups:
  - name: istio-control-plane
    rules:
    # istiod is down
    - alert: IstiodDown
      expr: absent(up{job="istiod"} == 1)
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "istiod is not running"
        description: "istiod has been down for more than 5 minutes"

    # xDS push latency too high
    - alert: IstiodPushLatencyHigh
      expr: histogram_quantile(0.99, sum(rate(pilot_xds_push_time_bucket[5m])) by (le)) > 5
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "istiod xDS push latency p99 > 5s"
        description: "Config push to proxies is taking too long"

    # Config rejection
    - alert: IstioConfigRejectionRate
      expr: sum(rate(pilot_total_xds_rejects[5m])) > 0
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Envoy proxies are rejecting Istio config"
        description: "Check for invalid configuration"

    # Proxy convergence too slow
    - alert: IstiodConvergenceSlow
      expr: histogram_quantile(0.99, sum(rate(pilot_proxy_convergence_time_bucket[5m])) by (le)) > 30
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Proxy convergence time p99 > 30s"

    # istiod high memory
    - alert: IstiodHighMemory
      expr: process_resident_memory_bytes{job="istiod"} > 4e9
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "istiod memory > 4GB"

  - name: istio-data-plane
    rules:
    # Sidecar high memory
    - alert: EnvoyMemoryHigh
      expr: envoy_server_memory_allocated > 150e6
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Envoy sidecar memory > 150MB"
        description: "Consider using Sidecar resource to limit config scope"

    # High error rate per service
    - alert: IstioServiceErrorRateHigh
      expr: |
        sum(rate(istio_requests_total{response_code=~"5.."}[5m])) by (destination_service)
        / sum(rate(istio_requests_total[5m])) by (destination_service) > 0.05
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Service {{ $labels.destination_service }} error rate > 5%"

    # High latency
    - alert: IstioServiceLatencyHigh
      expr: |
        histogram_quantile(0.99,
          sum(rate(istio_request_duration_milliseconds_bucket[5m])) by (destination_service, le)
        ) > 1000
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Service {{ $labels.destination_service }} p99 latency > 1s"

  - name: istio-security
    rules:
    # mTLS coverage dropped
    - alert: IstioMTLSCoverageDropped
      expr: |
        sum(rate(istio_requests_total{connection_security_policy="mutual_tls"}[5m]))
        / sum(rate(istio_requests_total[5m])) < 0.99
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "mTLS coverage dropped below 99%"

    # Certificate expiry
    - alert: IstioCertExpiryWarning
      expr: (citadel_server_root_cert_expiry_timestamp - time()) < 86400
      for: 1h
      labels:
        severity: critical
      annotations:
        summary: "Istio root certificate expires within 24 hours"
```

---

## Part D: Grafana Dashboards

### Pre-Built Istio Dashboards

| Dashboard | What It Shows | Key Panels |
|-----------|---------------|------------|
| **Istio Mesh** | Mesh-wide golden signals | Global request rate, error rate, latency |
| **Istio Service** | Per-service metrics | Request rate, error rate by service |
| **Istio Workload** | Per-pod metrics | CPU, memory, connection count per pod |
| **Istio Control Plane** | istiod health | xDS push rate, push latency, memory |
| **Istio Performance** | Envoy performance | Proxy CPU, memory, connection stats |

### Custom "Scale Health" Dashboard (1M Pods)

Key panels to create:

```
Row 1: Control Plane Health
  - istiod CPU usage (all replicas)
  - istiod Memory usage (all replicas)
  - xDS Push Rate (pushes/sec by type)
  - Push Latency (p50, p90, p99)

Row 2: Config Distribution
  - Proxy Convergence Time (p50, p90, p99)
  - xDS Rejections
  - Config Conflicts
  - Active proxy count (connected to each istiod)

Row 3: Data Plane Overview
  - Total mesh request rate
  - Mesh error rate (5xx / total)
  - Average sidecar memory
  - Sidecar memory distribution (histogram)

Row 4: Security
  - mTLS coverage %
  - Certificate issuance rate
  - CSR errors
  - Auth policy denials

Row 5: Scale Indicators
  - Total services in mesh
  - Total endpoints in mesh
  - Config size per proxy (estimate)
  - Push throttle queue depth
```

---

## Lab: Observability

```bash
#!/bin/bash
# lab-observability.sh — Observability Lab

echo "=== Observability Lab ==="
echo "Prerequisites: Istio + Bookinfo + addons deployed"

# Step 1: Generate traffic
echo "[Step 1] Generating traffic to Bookinfo..."
GATEWAY_URL=$(kubectl get svc istio-ingressgateway -n istio-system \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$GATEWAY_URL" ]; then
  GATEWAY_URL="$(minikube ip):$(kubectl get svc istio-ingressgateway -n istio-system \
    -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')"
fi

echo "Gateway: $GATEWAY_URL"
for i in $(seq 1 50); do
  curl -s -o /dev/null "http://$GATEWAY_URL/productpage"
done
echo "Generated 50 requests"

# Step 2: Query Prometheus for key metrics
echo ""
echo "[Step 2] Querying Prometheus metrics..."
kubectl port-forward svc/prometheus -n istio-system 9090:9090 &
PF_PID=$!
sleep 2

echo "Total requests:"
curl -s "http://localhost:9090/api/v1/query?query=sum(istio_requests_total)" | \
  python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('result',[{}])[0].get('value',['','N/A'])[1])" 2>/dev/null

echo "Error rate:"
curl -s "http://localhost:9090/api/v1/query?query=sum(rate(istio_requests_total{response_code=~\"5..\"}[5m]))/sum(rate(istio_requests_total[5m]))" | \
  python3 -c "import json,sys; d=json.load(sys.stdin); r=d.get('data',{}).get('result',[]); print(r[0].get('value',['','0'])[1] if r else '0')" 2>/dev/null

echo "istiod push count:"
curl -s "http://localhost:9090/api/v1/query?query=sum(pilot_xds_pushes)" | \
  python3 -c "import json,sys; d=json.load(sys.stdin); r=d.get('data',{}).get('result',[]); print(r[0].get('value',['','N/A'])[1] if r else 'N/A')" 2>/dev/null

kill $PF_PID 2>/dev/null

# Step 3: Open dashboards
echo ""
echo "[Step 3] Opening dashboards..."
echo "Run these commands in separate terminals:"
echo "  istioctl dashboard kiali       # Service graph"
echo "  istioctl dashboard grafana     # Metrics dashboards"
echo "  istioctl dashboard jaeger      # Distributed traces"
echo "  istioctl dashboard prometheus  # Raw metrics"

# Step 4: Check istiod metrics
echo ""
echo "[Step 4] istiod control plane metrics:"
ISTIOD_POD=$(kubectl get pod -n istio-system -l app=istiod -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n istio-system $ISTIOD_POD -- curl -s localhost:15014/metrics 2>/dev/null | \
  grep -E "^pilot_xds_pushes|^pilot_proxy_convergence|^pilot_services|^pilot_xds_push_time" | head -20

# Step 5: Check per-proxy metrics
echo ""
echo "[Step 5] Per-proxy metrics (productpage sidecar):"
PRODUCT_POD=$(kubectl get pod -l app=productpage -o jsonpath='{.items[0].metadata.name}')
kubectl exec $PRODUCT_POD -c istio-proxy -- curl -s localhost:15090/stats/prometheus 2>/dev/null | \
  grep -E "^istio_requests_total|^envoy_server_memory" | head -10

# Step 6: Envoy access logs
echo ""
echo "[Step 6] Access logs from productpage sidecar:"
kubectl logs $PRODUCT_POD -c istio-proxy --tail=5

echo ""
echo "=== Lab Complete ==="
echo ""
echo "Key metrics to remember:"
echo "1. pilot_xds_push_time → How fast istiod pushes config"
echo "2. pilot_proxy_convergence_time → How fast proxies converge"
echo "3. istio_requests_total → Golden signal for request counting"
echo "4. envoy_server_memory_allocated → Proxy memory (keep < 100MB)"
echo "5. connection_security_policy → mTLS coverage tracking"
```

---

## Summary

| Category | Key Metrics | Why |
|----------|------------|-----|
| **Control Plane** | `pilot_xds_push_time`, `pilot_proxy_convergence_time`, `pilot_total_xds_rejects` | Is istiod keeping up? |
| **Data Plane** | `istio_requests_total`, `istio_request_duration_milliseconds`, `envoy_server_memory_allocated` | Are services healthy? Are sidecars bloated? |
| **Security** | mTLS coverage ratio, `citadel_server_csr_count`, cert expiry | Is the mesh secure? |
| **Scale** | Config size per proxy, push rate, convergence time | Can the mesh handle the load? |

## Next Module

Continue to [Module 10: Envoy & xDS Deep Dive →](../10-envoy-xds-deep-dive/)

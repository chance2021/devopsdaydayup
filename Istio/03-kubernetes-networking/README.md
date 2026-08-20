# Module 03: Kubernetes Networking

> **Why this matters**: Istio sits ON TOP of Kubernetes networking. If you don't understand how Services, kube-proxy, and CNI work, you can't troubleshoot Istio. At 1M pods, you'll need to know whether a problem is in the K8s network layer or the Istio layer.

## Table of Contents
- [Theory: The Kubernetes Networking Model](#theory-the-kubernetes-networking-model)
- [Theory: CNI Plugins](#theory-cni-plugins)
- [Theory: kube-proxy Deep Dive](#theory-kube-proxy-deep-dive)
- [Theory: CoreDNS](#theory-coredns)
- [Theory: Service Types & Traffic Flow](#theory-service-types--traffic-flow)
- [Lab 1: kube-proxy iptables Inspection](#lab-1-kube-proxy-iptables-inspection)
- [Lab 2: CoreDNS Deep Dive](#lab-2-coredns-deep-dive)

---

## Theory: The Kubernetes Networking Model

Kubernetes enforces **four fundamental networking rules**:

1. **Every pod gets its own IP address** (no manual allocation)
2. **Pods can communicate with any other pod without NAT** (flat network)
3. **Agents on a node can communicate with all pods on that node**
4. **Pods see themselves with the same IP that other pods see them with**

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                         │
│                                                              │
│   Node 1 (10.0.1.0/24)              Node 2 (10.0.2.0/24)   │
│  ┌──────────────────────┐  ┌──────────────────────┐         │
│  │ Pod A: 10.0.1.2      │  │ Pod C: 10.0.2.2      │        │
│  │ Pod B: 10.0.1.3      │  │ Pod D: 10.0.2.3      │        │
│  └──────────────────────┘  └──────────────────────┘         │
│                                                              │
│  Pod A can reach Pod D at 10.0.2.3 directly (no NAT!)       │
│  This "flat network" is implemented by the CNI plugin        │
└─────────────────────────────────────────────────────────────┘
```

---

## Theory: CNI Plugins

**Container Network Interface (CNI)** plugins implement the pod networking model. They are responsible for:
- Allocating pod IPs (IPAM)
- Creating the pod's network namespace connectivity
- Programming routes so pods can reach each other across nodes

### Major CNI Plugins Comparison

| Feature | Flannel | Calico | Cilium |
|---------|---------|--------|--------|
| Overlay | VXLAN, host-gw | VXLAN, IPIP, none (BGP) | VXLAN, native |
| Network Policy | ❌ (needs Calico) | ✅ (iptables) | ✅ (eBPF) |
| Encryption | ❌ | WireGuard | WireGuard, IPsec |
| Performance | Good | Very good | Best (eBPF bypasses iptables) |
| Scale | Good | Excellent | Excellent |
| eBPF | ❌ | Partial | Full |
| **Istio integration** | Standard | Standard | Can replace kube-proxy & Istio sidecar |

### How a CNI Plugin Sets Up Pod Networking (Calico example)

```
1. kubelet calls CRI to create pod sandbox
2. CRI creates network namespace
3. kubelet calls CNI plugin (Calico)
4. Calico:
   a. Allocates pod IP from IPAM
   b. Creates veth pair (one end in pod ns, one on host)
   c. Assigns IP to pod-side veth
   d. Adds route on host: 10.0.1.2 → veth-xxx
   e. Advertises route via BGP (or tunnels via VXLAN/IPIP)
5. Pod is now reachable from any node in the cluster
```

### Cilium and eBPF (Important at Scale)

At 1M pods, **Cilium with eBPF** is increasingly preferred because:
- eBPF programs run in kernel space — faster than iptables userspace rules
- Can bypass kube-proxy entirely (direct socket-level load balancing)
- Can replace parts of Istio sidecar (L3/L4 policy without Envoy)
- Network policies are more efficient than iptables chains

```
Traditional:  App → iptables → conntrack → routing → NIC
Cilium/eBPF:  App → eBPF hook → NIC (bypass iptables entirely)
```

---

## Theory: kube-proxy Deep Dive

**kube-proxy** runs on every node and implements Kubernetes `Service` abstraction. It watches the API server for Service/Endpoint changes and programs rules to forward traffic.

### kube-proxy Modes

#### 1. iptables Mode (Default)

```bash
# For a Service: my-svc (ClusterIP: 10.96.100.10, Port: 80)
# With 3 backend pods: 10.0.1.2:8080, 10.0.1.3:8080, 10.0.2.2:8080

# Chain hierarchy:
# KUBE-SERVICES → KUBE-SVC-XXXX → KUBE-SEP-YYYY

# Step 1: Match service IP
-A KUBE-SERVICES -d 10.96.100.10/32 -p tcp --dport 80 -j KUBE-SVC-XXXX

# Step 2: Load balance (random probability)
-A KUBE-SVC-XXXX -m statistic --mode random --probability 0.33333 -j KUBE-SEP-AAA
-A KUBE-SVC-XXXX -m statistic --mode random --probability 0.50000 -j KUBE-SEP-BBB
-A KUBE-SVC-XXXX -j KUBE-SEP-CCC

# Step 3: DNAT to actual pod
-A KUBE-SEP-AAA -p tcp -j DNAT --to-destination 10.0.1.2:8080
-A KUBE-SEP-BBB -p tcp -j DNAT --to-destination 10.0.1.3:8080
-A KUBE-SEP-CCC -p tcp -j DNAT --to-destination 10.0.2.2:8080
```

**Problem at scale**: With 10,000 services × 100 pods each = **1,000,000 iptables rules**. Each packet must traverse the chain linearly → O(n) performance degrades.

#### 2. IPVS Mode (Required at Scale)

```bash
# Same service, but using IPVS:
# ipvsadm -Ln
IP Virtual Server version 1.2.1 (size=4096)
TCP  10.96.100.10:80 rr
  -> 10.0.1.2:8080     Masq  1    0    0
  -> 10.0.1.3:8080     Masq  1    0    0
  -> 10.0.2.2:8080     Masq  1    0    0
```

**Advantage**: IPVS uses hash tables → O(1) lookup regardless of number of services.

| Metric | iptables (10K services) | IPVS (10K services) |
|--------|------------------------|---------------------|
| Rule update time | ~10 seconds | ~1 second |
| Latency per packet | Increases with rules | Constant |
| CPU usage | High | Low |
| LB algorithms | Random only | rr, wrr, lc, wlc, sh, dh, sed, nq |

### What Happens When Istio is Added?

With Istio, **kube-proxy rules still exist**, but traffic takes a different path:

```
WITHOUT Istio:
  App → kube-proxy iptables (DNAT to pod IP) → destination pod

WITH Istio:
  App → Istio iptables (REDIRECT to Envoy 15001) → Envoy sidecar
    → Envoy routes to upstream (bypasses kube-proxy DNAT for mesh traffic)
    → destination pod's Envoy (port 15006) → destination App
```

Envoy effectively **replaces kube-proxy's load balancing** for in-mesh traffic, using its own service discovery (from istiod via xDS).

---

## Theory: CoreDNS

CoreDNS is the cluster DNS server. It resolves Service names to ClusterIPs.

### DNS Resolution Flow
```
App → resolve "my-svc.default.svc.cluster.local"
  → /etc/resolv.conf points to CoreDNS (10.96.0.10)
    → CoreDNS queries K8s API for Service
      → Returns ClusterIP: 10.96.100.10
        → App connects to 10.96.100.10
          → kube-proxy DNATs to pod IP
```

### DNS Record Types
```
# ClusterIP Service
my-svc.default.svc.cluster.local → A record → 10.96.100.10

# Headless Service (ClusterIP: None)
my-svc.default.svc.cluster.local → A records → 10.0.1.2, 10.0.1.3, 10.0.2.2
                                               (returns all pod IPs directly)

# Pod DNS
10-0-1-2.default.pod.cluster.local → A record → 10.0.1.2

# SRV records (for port discovery)
_http._tcp.my-svc.default.svc.cluster.local → SRV → 0 100 80 my-svc.default.svc.cluster.local
```

### DNS at Scale (1M Pods)
At 1M pods, CoreDNS becomes a bottleneck:
- Every new pod → DNS queries for dependent services
- High RPS workloads → thousands of DNS queries/second
- **Solutions**:
  - Scale CoreDNS replicas (HPA)
  - NodeLocal DNSCache (DaemonSet caching DNS on each node)
  - Istio DNS Proxy (resolves ServiceEntry locally at the sidecar)
  - Reduce `ndots` in resolv.conf (default 5 → causes 4 extra lookups per query)

---

## Theory: Service Types & Traffic Flow

### ClusterIP (Default)
```
Internal only. ClusterIP → kube-proxy DNAT → Pod
```

### NodePort
```
External:30080 → Node iptables DNAT → ClusterIP → kube-proxy → Pod
```

### LoadBalancer
```
Cloud LB → NodePort → ClusterIP → kube-proxy → Pod
(or direct-to-pod with cloud-specific integration)
```

### ExternalName
```
DNS CNAME: my-svc → external.database.com (no proxying)
```

### With Istio
```
Istio Gateway (Envoy) replaces LoadBalancer/Ingress for mesh traffic:
External → Istio IngressGateway (Envoy) → VirtualService routing → Pod's Envoy → App
```

---

## Lab 1: kube-proxy iptables Inspection

```bash
#!/bin/bash
# lab-kube-proxy.sh — Inspect kube-proxy iptables rules in Minikube

echo "=== Lab 1: kube-proxy iptables Inspection ==="
echo "Prerequisites: Minikube running with a deployed service"

# Step 1: Deploy a simple service
echo "[Step 1] Deploying test service..."
kubectl create deployment web --image=nginx --replicas=3 2>/dev/null
kubectl expose deployment web --port=80 --type=ClusterIP 2>/dev/null
sleep 5

# Step 2: Get service details
echo "[Step 2] Service details:"
kubectl get svc web -o wide
SVC_IP=$(kubectl get svc web -o jsonpath='{.spec.clusterIP}')
echo "Service ClusterIP: $SVC_IP"

# Step 3: Get endpoint details
echo "[Step 3] Endpoints:"
kubectl get endpoints web

# Step 4: SSH into minikube to inspect iptables
echo "[Step 4] Inspecting kube-proxy iptables rules..."
echo "--- KUBE-SERVICES chain (entry point) ---"
minikube ssh "sudo iptables -t nat -L KUBE-SERVICES -n" 2>/dev/null | grep "$SVC_IP"

echo "--- KUBE-SVC chain for our service ---"
SVC_CHAIN=$(minikube ssh "sudo iptables -t nat -L KUBE-SERVICES -n" 2>/dev/null | grep "$SVC_IP" | awk '{print $1}' | head -1)
if [ -n "$SVC_CHAIN" ]; then
  echo "Chain name: $SVC_CHAIN"
  minikube ssh "sudo iptables -t nat -L $SVC_CHAIN -n -v" 2>/dev/null
  
  echo "--- KUBE-SEP chains (individual endpoints) ---"
  for sep in $(minikube ssh "sudo iptables -t nat -L $SVC_CHAIN -n" 2>/dev/null | grep KUBE-SEP | awk '{print $1}'); do
    echo "Endpoint chain: $sep"
    minikube ssh "sudo iptables -t nat -L $sep -n -v" 2>/dev/null
  done
fi

# Step 5: Complete packet path trace
echo ""
echo "[Step 5] Complete packet path:"
echo "1. App sends to $SVC_IP:80"
echo "2. Packet hits PREROUTING → KUBE-SERVICES chain"
echo "3. KUBE-SERVICES matches $SVC_IP → jumps to KUBE-SVC-XXXX"
echo "4. KUBE-SVC-XXXX uses --probability to randomly pick KUBE-SEP-YYYY"
echo "5. KUBE-SEP-YYYY DNATs to actual pod IP"
echo "6. Packet reaches the pod"

# Step 6: Check kube-proxy mode
echo ""
echo "[Step 6] kube-proxy mode:"
kubectl get configmap kube-proxy -n kube-system -o yaml 2>/dev/null | grep mode

# Cleanup
echo ""
echo "[Cleanup]"
kubectl delete deployment web 2>/dev/null
kubectl delete svc web 2>/dev/null
echo "=== Lab 1 Complete ==="
```

---

## Lab 2: CoreDNS Deep Dive

```bash
#!/bin/bash
# lab-coredns.sh — CoreDNS Deep Dive in Minikube

echo "=== Lab 2: CoreDNS Deep Dive ==="

# Step 1: Inspect CoreDNS deployment
echo "[Step 1] CoreDNS pods:"
kubectl get pods -n kube-system -l k8s-app=kube-dns

echo "CoreDNS ConfigMap:"
kubectl get configmap coredns -n kube-system -o yaml

# Step 2: Create a test service
echo "[Step 2] Creating test service..."
kubectl create deployment hello --image=nginx --replicas=2 2>/dev/null
kubectl expose deployment hello --port=80 2>/dev/null
sleep 5

# Step 3: DNS resolution from inside a pod
echo "[Step 3] DNS resolution test..."
kubectl run dns-test --image=busybox:1.36 --restart=Never --rm -it -- sh -c '
echo "=== /etc/resolv.conf ==="
cat /etc/resolv.conf
echo ""
echo "=== Resolve by short name ==="
nslookup hello
echo ""
echo "=== Resolve by FQDN ==="
nslookup hello.default.svc.cluster.local
echo ""
echo "=== Resolve kubernetes API service ==="
nslookup kubernetes.default.svc.cluster.local
echo ""
echo "=== SRV record lookup ==="
nslookup -type=srv _http._tcp.hello.default.svc.cluster.local
echo ""
echo "=== What ndots does (watch the queries!) ==="
echo "When ndots=5, a name with <5 dots gets search domains appended first"
echo "hello → tries hello.default.svc.cluster.local, hello.svc.cluster.local, etc."
' 2>/dev/null

# Step 4: Headless service DNS
echo "[Step 4] Headless service DNS..."
kubectl expose deployment hello --name=hello-headless --port=80 --cluster-ip=None 2>/dev/null
sleep 3
kubectl run dns-test2 --image=busybox:1.36 --restart=Never --rm -it -- sh -c '
echo "=== Regular service (returns ClusterIP) ==="
nslookup hello
echo ""
echo "=== Headless service (returns pod IPs) ==="
nslookup hello-headless
' 2>/dev/null

# Step 5: DNS query latency
echo "[Step 5] DNS performance:"
kubectl run dns-perf --image=busybox:1.36 --restart=Never --rm -it -- sh -c '
echo "Measuring DNS latency (10 queries)..."
for i in $(seq 1 10); do
  start=$(date +%s%N)
  nslookup hello.default.svc.cluster.local > /dev/null 2>&1
  end=$(date +%s%N)
  echo "Query $i: $(( ($end - $start) / 1000000 )) ms"
done
' 2>/dev/null

# Cleanup
kubectl delete deployment hello 2>/dev/null
kubectl delete svc hello hello-headless 2>/dev/null
echo "=== Lab 2 Complete ==="
```

---

## Summary

| K8s Networking Layer | What It Does | Scale Concern | Istio Impact |
|---------------------|-------------|---------------|--------------|
| CNI (Calico/Cilium) | Pod IP allocation + cross-node routing | Must handle 1M pod IPs efficiently | No change (Istio sits above CNI) |
| kube-proxy | Service → Pod load balancing | Switch to IPVS at scale | Envoy replaces kube-proxy LB for mesh traffic |
| CoreDNS | Service name → ClusterIP resolution | Bottleneck at 1M pods | Istio DNS proxy reduces CoreDNS load |
| NetworkPolicy | L3/L4 network isolation | O(n) iptables rules | Istio AuthorizationPolicy adds L7 |

## Next Module

Continue to [Module 04: Minikube Setup →](../04-minikube-setup/)

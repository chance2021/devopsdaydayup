# Module 01: Linux Networking Foundations

> **Why this matters**: Every packet in Istio flows through Linux networking primitives. When you're debugging why a pod can't reach another pod at 1M scale, you need to understand network namespaces, iptables, and routing — not just Istio YAML. This module teaches you to see the matrix.

## Table of Contents
- [Theory: Network Namespaces](#theory-network-namespaces)
- [Theory: veth Pairs](#theory-veth-pairs)
- [Theory: Linux Bridges](#theory-linux-bridges)
- [Theory: iptables Deep Dive](#theory-iptables-deep-dive)
- [Theory: conntrack](#theory-conntrack)
- [Theory: IPVS](#theory-ipvs)
- [Theory: Packet Analysis Tools](#theory-packet-analysis-tools)
- [Lab 1: Network Namespaces](#lab-1-network-namespaces)
- [Lab 2: iptables](#lab-2-iptables)
- [Lab 3: Bridges & veth Pairs](#lab-3-bridges--veth-pairs)

---

## Prerequisites

Since macOS doesn't have Linux networking primitives, we'll run all labs inside a Docker container:

```bash
# Start a privileged container with networking tools
docker run -it --rm --privileged --name netlab \
  ubuntu:22.04 bash

# Inside the container, install required tools
apt-get update && apt-get install -y \
  iproute2 iptables ipvsadm bridge-utils \
  tcpdump net-tools curl dnsutils \
  conntrack nftables
```

---

## Theory: Network Namespaces

A **network namespace** is a Linux kernel feature that provides an isolated copy of the network stack. Each namespace gets its own:
- Network interfaces
- Routing table
- iptables rules
- Socket table (ports)

**This is how Kubernetes pods are isolated.** Every pod runs in its own network namespace.

```
┌─────────────────────────────────────────────────────────┐
│                    Host (Root Namespace)                  │
│    eth0: 192.168.1.100                                   │
│    Routing table: default via 192.168.1.1                │
│    iptables: [host rules]                                │
│                                                          │
│  ┌──────────────────┐    ┌──────────────────┐           │
│  │   Namespace: ns1  │    │   Namespace: ns2  │          │
│  │   eth0: 10.0.1.1  │    │   eth0: 10.0.2.1  │         │
│  │   Routes: [own]   │    │   Routes: [own]   │         │
│  │   iptables: [own] │    │   iptables: [own] │         │
│  └──────────────────┘    └──────────────────┘           │
└─────────────────────────────────────────────────────────┘
```

### Key Commands
```bash
# List all network namespaces
ip netns list

# Create a network namespace
ip netns add my_namespace

# Execute a command inside a namespace
ip netns exec my_namespace ip addr show

# Delete a namespace
ip netns delete my_namespace
```

### How Kubernetes Uses This
- kubelet (via the container runtime) creates a new network namespace for each pod
- The CNI plugin then sets up networking inside that namespace
- Multiple containers in the same pod share the same network namespace (that's why they share localhost!)

---

## Theory: veth Pairs

A **veth (Virtual Ethernet) pair** is like a virtual network cable with two ends. Anything sent into one end comes out the other. They are used to connect network namespaces together.

```
┌──────────────┐          ┌──────────────┐
│  Namespace A  │          │  Namespace B  │
│               │          │               │
│    veth0  ────┼──────────┼──── veth1     │
│  10.0.0.1     │  (pair)  │  10.0.0.2     │
└──────────────┘          └──────────────┘
```

### Key Commands
```bash
# Create a veth pair
ip link add veth0 type veth peer name veth1

# Move one end to a namespace
ip link set veth1 netns my_namespace

# Assign IP addresses
ip addr add 10.0.0.1/24 dev veth0
ip netns exec my_namespace ip addr add 10.0.0.2/24 dev veth1

# Bring them up
ip link set veth0 up
ip netns exec my_namespace ip link set veth1 up
```

### How Kubernetes Uses This
- Each pod's network namespace has one end of a veth pair
- The other end is connected to a bridge or directly to the host's network stack
- This is how traffic gets from a pod to the host and then to other pods/external

---

## Theory: Linux Bridges

A **Linux bridge** is a virtual L2 switch. It connects multiple network interfaces and forwards frames between them based on MAC addresses.

```
                     ┌─────────────────┐
                     │   Linux Bridge   │
                     │   (br0)          │
                     │   10.0.0.0/24    │
                     └───┬─────┬───┬───┘
                         │     │   │
                    veth0│veth2│   │veth4
                         │     │   │
                    veth1│veth3│   │veth5
                         │     │   │
                    ┌────┴┐ ┌─┴──┐ ┌┴────┐
                    │ ns1  │ │ ns2 │ │ ns3  │
                    │10.0. │ │10.0.│ │10.0. │
                    │0.2   │ │0.3  │ │0.4   │
                    └──────┘ └─────┘ └──────┘
```

### Key Commands
```bash
# Create a bridge
ip link add br0 type bridge
ip link set br0 up

# Attach a veth to the bridge
ip link set veth0 master br0

# Assign IP to bridge (acts as gateway)
ip addr add 10.0.0.1/24 dev br0
```

### How Kubernetes Uses This
- **Flannel** uses a bridge (`cni0`) to connect pod veth pairs
- Docker uses `docker0` bridge by default
- **Calico** and **Cilium** use different approaches (BGP routing, eBPF)

---

## Theory: iptables Deep Dive

`iptables` is the Linux kernel firewall and the **backbone of kube-proxy and Istio traffic interception**. Understanding it is non-negotiable.

### The 5 Tables
| Table | Purpose | Used By |
|-------|---------|---------|
| `filter` | Accept/drop packets (firewall) | Default table |
| `nat` | Translate addresses (SNAT/DNAT) | kube-proxy, Istio |
| `mangle` | Modify packet headers (TTL, TOS) | QoS |
| `raw` | Bypass connection tracking | Performance tuning |
| `security` | SELinux labels | SELinux |

### The 5 Built-in Chains (packet flow order)

```
                              INCOMING PACKET
                                    │
                                    ▼
                            ┌───────────────┐
                            │  PREROUTING    │ ← nat, mangle, raw
                            └───────┬───────┘
                                    │
                              Routing Decision
                              ┌─────┴─────┐
                              │            │
                     For this host?    Forward?
                              │            │
                              ▼            ▼
                       ┌──────────┐  ┌──────────┐
                       │  INPUT    │  │ FORWARD   │ ← filter, mangle
                       └────┬─────┘  └──────┬────┘
                            │               │
                       Local Process         │
                            │               │
                            ▼               │
                       ┌──────────┐         │
                       │  OUTPUT   │ ←──────┘
                       └────┬─────┘  filter, nat, mangle, raw
                            │
                            ▼
                       ┌──────────────┐
                       │ POSTROUTING   │ ← nat, mangle
                       └──────┬───────┘
                              │
                              ▼
                        OUTGOING PACKET
```

### Common Targets (Actions)
| Target | What It Does | Example Use |
|--------|-------------|-------------|
| `ACCEPT` | Allow the packet | Firewall allow rules |
| `DROP` | Silently discard | Firewall block rules |
| `REJECT` | Discard + send error | User-friendly block |
| `DNAT` | Change destination IP/port | kube-proxy Service → Pod |
| `SNAT` | Change source IP | Outbound NAT |
| `MASQUERADE` | SNAT with auto source IP | Pod → external traffic |
| `REDIRECT` | Redirect to local port | **Istio sidecar interception** |
| `RETURN` | Stop processing chain | Fall through |

### How kube-proxy Uses iptables
```bash
# kube-proxy creates chains like:
# KUBE-SERVICES → KUBE-SVC-XXXX → KUBE-SEP-YYYY

# Example: Service 10.96.0.10:80 → Pod 10.1.2.3:8080
-A KUBE-SERVICES -d 10.96.0.10/32 -p tcp --dport 80 -j KUBE-SVC-XXXX
-A KUBE-SVC-XXXX -m statistic --mode random --probability 0.5 -j KUBE-SEP-YYYY
-A KUBE-SEP-YYYY -p tcp -j DNAT --to-destination 10.1.2.3:8080
```

### How Istio Uses iptables
```bash
# Istio creates these chains in the pod's network namespace:
# ISTIO_INBOUND → ISTIO_IN_REDIRECT (inbound to Envoy port 15006)
# ISTIO_OUTPUT → ISTIO_REDIRECT (outbound to Envoy port 15001)

# Redirect ALL inbound TCP traffic to Envoy
-A ISTIO_INBOUND -p tcp -j ISTIO_IN_REDIRECT
-A ISTIO_IN_REDIRECT -p tcp -j REDIRECT --to-ports 15006

# Redirect ALL outbound TCP traffic to Envoy (except from Envoy itself, UID 1337)
-A ISTIO_OUTPUT -m owner --uid-owner 1337 -j RETURN
-A ISTIO_OUTPUT -p tcp -j ISTIO_REDIRECT
-A ISTIO_REDIRECT -p tcp -j REDIRECT --to-ports 15001
```

---

## Theory: conntrack

**Connection tracking (conntrack)** is the kernel module that tracks the state of network connections. It's how iptables knows that a packet is part of an ESTABLISHED connection.

### States
| State | Description |
|-------|-------------|
| `NEW` | First packet of a connection |
| `ESTABLISHED` | Part of an already-seen connection |
| `RELATED` | Related to an established connection (e.g., FTP data) |
| `INVALID` | Doesn't match any known connection |

### Why It Matters for Istio
- conntrack table has a MAX size (`nf_conntrack_max`)
- At 1M pods with high RPS, you can exhaust the conntrack table → packets dropped
- Symptoms: random connection failures, "nf_conntrack: table full" in dmesg
- **Fix**: Increase `nf_conntrack_max` (default ~65536, set to 1M+ at scale)

```bash
# Check current conntrack table size
cat /proc/sys/net/netfilter/nf_conntrack_max

# Check current entries
cat /proc/sys/net/netfilter/nf_conntrack_count

# Increase max
sysctl -w net.netfilter.nf_conntrack_max=1048576
```

---

## Theory: IPVS

**IP Virtual Server (IPVS)** is a Linux kernel module for L4 load balancing. It's an alternative to iptables for kube-proxy.

### iptables vs IPVS for kube-proxy

| Feature | iptables | IPVS |
|---------|----------|------|
| Lookup complexity | O(n) — linear chain traversal | O(1) — hash table |
| 10,000 services | Noticeable latency | No impact |
| Load balancing | Random (statistic module) | rr, wrr, lc, wlc, sh, dh, sed, nq |
| Connection tracking | Built-in | Uses conntrack |
| At 1M pods | **Unacceptable** — rules become huge | **Required** at scale |

```bash
# Check IPVS rules
ipvsadm -Ln

# kube-proxy in IPVS mode creates virtual servers:
# TCP  10.96.0.10:80 rr
#   -> 10.1.2.3:8080    Masq  1  0  0
#   -> 10.1.2.4:8080    Masq  1  0  0
```

---

## Theory: Packet Analysis Tools

### tcpdump
```bash
# Capture all traffic on eth0
tcpdump -i eth0 -n

# Capture only port 80 traffic
tcpdump -i eth0 port 80 -n

# Capture traffic between two IPs
tcpdump -i eth0 host 10.0.0.1 and host 10.0.0.2

# Save to file for Wireshark analysis
tcpdump -i eth0 -w capture.pcap

# Show packet contents in ASCII
tcpdump -i eth0 -A port 80
```

### ss (Socket Statistics)
```bash
# Show all TCP connections
ss -tlnp

# Show all listening sockets
ss -lntp

# Show connections to a specific port
ss -tnp dst :8080

# Show socket memory usage
ss -m
```

---

## Lab 1: Network Namespaces

> Run all commands inside the Docker container from Prerequisites.

```bash
#!/bin/bash
# lab-netns.sh — Network Namespace Hands-On Lab

echo "=== Lab 1: Network Namespace Fundamentals ==="

# Step 1: Create two network namespaces (simulating two pods)
echo "[Step 1] Creating namespaces 'pod-a' and 'pod-b'..."
ip netns add pod-a
ip netns add pod-b
ip netns list

# Step 2: Verify isolation — each namespace has only loopback
echo "[Step 2] Checking interfaces in each namespace..."
echo "pod-a interfaces:"
ip netns exec pod-a ip addr show
echo "pod-b interfaces:"
ip netns exec pod-b ip addr show

# Step 3: Create a veth pair to connect them
echo "[Step 3] Creating veth pair..."
ip link add veth-a type veth peer name veth-b

# Step 4: Move each end to its namespace
echo "[Step 4] Moving veth ends to namespaces..."
ip link set veth-a netns pod-a
ip link set veth-b netns pod-b

# Step 5: Assign IP addresses
echo "[Step 5] Assigning IPs..."
ip netns exec pod-a ip addr add 10.0.0.1/24 dev veth-a
ip netns exec pod-b ip addr add 10.0.0.2/24 dev veth-b

# Step 6: Bring interfaces up
echo "[Step 6] Bringing interfaces up..."
ip netns exec pod-a ip link set veth-a up
ip netns exec pod-b ip link set veth-b up
ip netns exec pod-a ip link set lo up
ip netns exec pod-b ip link set lo up

# Step 7: Test connectivity!
echo "[Step 7] Pinging pod-b (10.0.0.2) from pod-a..."
ip netns exec pod-a ping -c 3 10.0.0.2

# Step 8: Verify routing tables are isolated
echo "[Step 8] Routing tables:"
echo "pod-a:"
ip netns exec pod-a ip route
echo "pod-b:"
ip netns exec pod-b ip route

# Step 9: Verify iptables are isolated
echo "[Step 9] iptables in pod-a (empty — isolated!):"
ip netns exec pod-a iptables -L -n

# Step 10: Run a process in the namespace (simulating a container)
echo "[Step 10] Starting a web server in pod-b..."
ip netns exec pod-b python3 -m http.server 8080 &
sleep 1
echo "Curling from pod-a to pod-b:8080..."
ip netns exec pod-a curl -s http://10.0.0.2:8080 | head -5

# Cleanup
kill %1 2>/dev/null
ip netns delete pod-a
ip netns delete pod-b
echo "=== Lab 1 Complete ==="
```

### Key Takeaways
- Each network namespace is a complete, isolated copy of the network stack
- This is EXACTLY how pods are isolated in Kubernetes
- veth pairs are the "cables" connecting namespaces
- iptables rules inside one namespace don't affect another

---

## Lab 2: iptables

```bash
#!/bin/bash
# lab-iptables.sh — iptables Deep Dive Lab

echo "=== Lab 2: iptables Fundamentals ==="

# Create a namespace to experiment in (don't mess with host iptables)
ip netns add iptables-lab
ip netns exec iptables-lab ip link set lo up

echo "[Step 1] Default iptables rules (empty):"
ip netns exec iptables-lab iptables -L -n -v --line-numbers

echo "[Step 2] Listing all tables:"
for table in filter nat mangle raw; do
  echo "--- Table: $table ---"
  ip netns exec iptables-lab iptables -t $table -L -n -v
done

# Step 3: Create rules similar to what Istio creates
echo "[Step 3] Creating Istio-like iptables rules..."

# Create custom chains (like Istio does)
ip netns exec iptables-lab iptables -t nat -N ISTIO_INBOUND
ip netns exec iptables-lab iptables -t nat -N ISTIO_IN_REDIRECT
ip netns exec iptables-lab iptables -t nat -N ISTIO_OUTPUT
ip netns exec iptables-lab iptables -t nat -N ISTIO_REDIRECT

# Redirect inbound traffic to Envoy's inbound port (15006)
ip netns exec iptables-lab iptables -t nat -A PREROUTING -p tcp -j ISTIO_INBOUND
ip netns exec iptables-lab iptables -t nat -A ISTIO_INBOUND -p tcp --dport 22 -j RETURN
ip netns exec iptables-lab iptables -t nat -A ISTIO_INBOUND -p tcp -j ISTIO_IN_REDIRECT
ip netns exec iptables-lab iptables -t nat -A ISTIO_IN_REDIRECT -p tcp -j REDIRECT --to-ports 15006

# Redirect outbound traffic to Envoy's outbound port (15001)
ip netns exec iptables-lab iptables -t nat -A OUTPUT -p tcp -j ISTIO_OUTPUT
# Don't redirect Envoy's own traffic (UID 1337) — prevents infinite loop!
ip netns exec iptables-lab iptables -t nat -A ISTIO_OUTPUT -m owner --uid-owner 1337 -j RETURN
# Don't redirect traffic to localhost
ip netns exec iptables-lab iptables -t nat -A ISTIO_OUTPUT -d 127.0.0.1/32 -j RETURN
# Redirect everything else to Envoy
ip netns exec iptables-lab iptables -t nat -A ISTIO_OUTPUT -p tcp -j ISTIO_REDIRECT
ip netns exec iptables-lab iptables -t nat -A ISTIO_REDIRECT -p tcp -j REDIRECT --to-ports 15001

echo "[Step 4] Final Istio-like iptables rules:"
ip netns exec iptables-lab iptables -t nat -L -n -v --line-numbers

echo ""
echo "=== Understanding the rules ==="
echo "1. ALL inbound TCP → ISTIO_INBOUND chain"
echo "2. Port 22 (SSH) is excluded → RETURN (skip interception)"
echo "3. Everything else → REDIRECT to port 15006 (Envoy inbound)"
echo "4. ALL outbound TCP → ISTIO_OUTPUT chain"
echo "5. Traffic FROM UID 1337 (Envoy) → RETURN (prevents loop)"
echo "6. Traffic TO localhost → RETURN (local communication)"
echo "7. Everything else → REDIRECT to port 15001 (Envoy outbound)"

# Cleanup
ip netns delete iptables-lab
echo "=== Lab 2 Complete ==="
```

### Key Takeaways
- iptables `nat` table is where Service routing and Istio interception happens
- Custom chains keep rules organized (Istio creates 4 custom chains)
- UID-based bypass (1337) prevents Envoy from intercepting its own traffic
- `REDIRECT` target changes the destination to a local port (this is how traffic goes to the sidecar)

---

## Lab 3: Bridges & veth Pairs

```bash
#!/bin/bash
# lab-bridge-veth.sh — Building a Mini Container Network

echo "=== Lab 3: Building a Container Network from Scratch ==="

# This lab builds the EXACT networking setup that Docker/K8s uses:
# Multiple namespaces connected via a bridge with NAT for external access

# Step 1: Create the bridge (like docker0 or cni0)
echo "[Step 1] Creating bridge 'mesh-br0'..."
ip link add mesh-br0 type bridge
ip addr add 10.10.0.1/24 dev mesh-br0
ip link set mesh-br0 up

# Step 2: Create 3 "pods" (namespaces)
for i in 1 2 3; do
  echo "[Step 2.$i] Creating pod-$i..."
  
  # Create namespace
  ip netns add pod-$i
  
  # Create veth pair
  ip link add veth-pod$i type veth peer name eth0-pod$i
  
  # Move one end to the namespace
  ip link set eth0-pod$i netns pod-$i
  
  # Attach other end to bridge
  ip link set veth-pod$i master mesh-br0
  ip link set veth-pod$i up
  
  # Configure IP inside namespace
  ip netns exec pod-$i ip addr add 10.10.0.$((i+1))/24 dev eth0-pod$i
  ip netns exec pod-$i ip link set eth0-pod$i up
  ip netns exec pod-$i ip link set lo up
  
  # Set default route to bridge
  ip netns exec pod-$i ip route add default via 10.10.0.1
done

# Step 3: Test pod-to-pod communication
echo "[Step 3] Testing pod-to-pod communication..."
echo "pod-1 → pod-2:"
ip netns exec pod-1 ping -c 2 10.10.0.3
echo "pod-1 → pod-3:"
ip netns exec pod-1 ping -c 2 10.10.0.4

# Step 4: Enable IP forwarding (required for routing between namespaces and external)
echo "[Step 4] Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1

# Step 5: Set up NAT for external access (like MASQUERADE in K8s)
echo "[Step 5] Setting up NAT..."
iptables -t nat -A POSTROUTING -s 10.10.0.0/24 ! -o mesh-br0 -j MASQUERADE

# Step 6: Verify the network
echo "[Step 6] Network topology:"
echo "Bridge (mesh-br0): $(ip addr show mesh-br0 | grep inet)"
for i in 1 2 3; do
  echo "pod-$i: $(ip netns exec pod-$i ip addr show eth0-pod$i | grep inet)"
done

echo ""
echo "=== What we just built ==="
echo "This is EXACTLY how Docker bridge networking works:"
echo "  mesh-br0 = docker0 bridge"
echo "  veth-pod1/eth0-pod1 = veth pair connecting container to bridge"
echo "  MASQUERADE = how pods reach external networks"
echo "  IP forwarding = needed for packets to traverse between namespaces"

# Step 7: Explore ARP table on the bridge
echo "[Step 7] ARP table (bridge learned MAC addresses):"
ip netns exec pod-1 ip neigh show

# Cleanup
for i in 1 2 3; do
  ip netns delete pod-$i
done
ip link delete mesh-br0
iptables -t nat -D POSTROUTING -s 10.10.0.0/24 ! -o mesh-br0 -j MASQUERADE
echo "=== Lab 3 Complete ==="
```

### Key Takeaways
- A bridge + veth pairs is the foundation of container networking
- This is literally what `docker0` and Flannel's `cni0` are
- IP forwarding (`ip_forward=1`) must be enabled for cross-namespace routing
- MASQUERADE provides outbound NAT for pods to reach external services
- Understanding this makes Kubernetes CNI plugins and Istio's traffic interception crystal clear

---

## Summary: What You Learned

| Concept | Kubernetes Equivalent | Istio Equivalent |
|---------|----------------------|------------------|
| Network Namespace | Pod network isolation | Sidecar shares pod's namespace |
| veth pair | Pod-to-node connection | Traffic path to/from sidecar |
| Bridge | CNI network (cni0) | Not directly used by Istio |
| iptables NAT | kube-proxy Service routing | `istio-init` traffic interception |
| iptables REDIRECT | — | Redirect traffic to Envoy (15001/15006) |
| conntrack | Connection tracking for Services | Connection tracking for mesh traffic |
| IPVS | kube-proxy IPVS mode | — (Envoy does its own LB) |

## Next Module

Continue to [Module 02: Container Networking →](../02-container-networking/)

# Module 02: Container Networking

> **Why this matters**: Before understanding Istio, you need to see how containers network WITHOUT a service mesh. This module shows you what Docker does under the hood — it's the same Linux primitives from Module 01, just automated.

## Table of Contents
- [Theory: How Docker Creates Container Networks](#theory-how-docker-creates-container-networks)
- [Theory: Docker's iptables Rules](#theory-dockers-iptables-rules)
- [Theory: Container Network Models](#theory-container-network-models)
- [Lab: Inspect Docker Networking](#lab-inspect-docker-networking)

---

## Theory: How Docker Creates Container Networks

When you run `docker run`, here's what happens at the networking level:

```
Step 1: Create a network namespace for the container
        └─ This is the container's isolated network stack

Step 2: Create a veth pair
        └─ One end goes in the container namespace (eth0)
        └─ Other end stays in the host namespace (vethXXXXXX)

Step 3: Attach host-side veth to the docker0 bridge
        └─ Container is now connected to the bridge network

Step 4: Assign IP from the bridge subnet (172.17.0.0/16)
        └─ Container gets 172.17.0.X

Step 5: Set default route via the bridge IP (172.17.0.1)
        └─ Container can reach anything via the bridge

Step 6: iptables MASQUERADE for outbound traffic
        └─ Container → external uses host IP (SNAT)

Step 7: iptables DNAT for port mapping (-p 8080:80)
        └─ External:8080 → Container:80
```

### Visual Architecture
```
┌──────────────────────────────────────────────────────────────┐
│                        HOST MACHINE                           │
│                                                               │
│  ┌─────────────────────────────────────────────┐             │
│  │              docker0 bridge                   │            │
│  │              172.17.0.1/16                    │            │
│  └──────┬──────────────┬──────────────┬─────────┘            │
│         │              │              │                       │
│    vethAAA        vethBBB        vethCCC                      │
│         │              │              │                       │
│  ┌──────┴──────┐ ┌─────┴──────┐ ┌────┴───────┐             │
│  │ Container 1  │ │ Container 2 │ │ Container 3 │            │
│  │ eth0:        │ │ eth0:       │ │ eth0:       │            │
│  │ 172.17.0.2   │ │ 172.17.0.3  │ │ 172.17.0.4  │           │
│  └─────────────┘ └─────────────┘ └─────────────┘            │
│                                                               │
│  iptables NAT:                                                │
│  - MASQUERADE: 172.17.0.0/16 → host IP (outbound)           │
│  - DNAT: host:8080 → 172.17.0.2:80 (port mapping)           │
│                                                               │
│  eth0: 192.168.1.100 ──── Physical Network                   │
└──────────────────────────────────────────────────────────────┘
```

---

## Theory: Docker's iptables Rules

Docker creates several iptables rules automatically. Understanding these is critical because **Istio adds its own rules on top**.

### NAT Table Rules
```bash
# POSTROUTING: MASQUERADE for outbound traffic from containers
-A POSTROUTING -s 172.17.0.0/16 ! -o docker0 -j MASQUERADE

# PREROUTING + OUTPUT: DNAT for port mappings
# docker run -p 8080:80 creates:
-A DOCKER -p tcp --dport 8080 -j DNAT --to-destination 172.17.0.2:80
```

### Filter Table Rules
```bash
# FORWARD: Allow traffic between containers on the same bridge
-A FORWARD -i docker0 -o docker0 -j ACCEPT

# FORWARD: Allow established connections from containers to external
-A FORWARD -i docker0 ! -o docker0 -j ACCEPT
-A FORWARD -o docker0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
```

### Docker Network Isolation
```bash
# By default, Docker allows inter-container communication
# This can be disabled with --icc=false
# Each Docker network creates its OWN bridge and iptables rules

# Custom networks use built-in DNS (container name resolution)
# The default bridge network does NOT — containers must use IP addresses
```

---

## Theory: Container Network Models

### 1. Bridge Mode (Default)
```
Container ←→ veth ←→ docker0 bridge ←→ host eth0 ←→ external
```
- Each container gets its own IP on the bridge subnet
- Port mapping needed for external access
- Containers on the same bridge can communicate directly

### 2. Host Mode (`--network host`)
```
Container shares host's network namespace (no isolation!)
```
- Container uses the host's IP and ports directly
- No NAT overhead, fastest performance
- No port mapping needed
- **Istio sidecar cannot work in host mode** (no iptables interception)

### 3. None Mode (`--network none`)
```
Container gets only loopback — completely isolated
```
- No network access at all
- Useful for security-critical batch jobs

### 4. Overlay Mode (Docker Swarm / K8s)
```
Container ←→ veth ←→ bridge ←→ VXLAN tunnel ←→ remote host ←→ bridge ←→ container
```
- Cross-host container communication
- Uses VXLAN encapsulation (L2 over L3)
- Similar to Flannel's VXLAN backend in Kubernetes

---

## Lab: Inspect Docker Networking

> Run these commands on your macOS/Linux machine with Docker installed.

```bash
#!/bin/bash
# lab-container-net.sh — Inspect Docker Networking Internals

echo "=== Container Networking Deep Dive Lab ==="

# Step 1: Start two containers
echo "[Step 1] Starting two nginx containers..."
docker run -d --name web1 -p 8081:80 nginx:alpine
docker run -d --name web2 -p 8082:80 nginx:alpine
sleep 2

# Step 2: Inspect the docker0 bridge
echo "[Step 2] Docker bridge interface:"
docker network inspect bridge | grep -A 5 "Subnet"

# Step 3: Find the container network namespaces
echo "[Step 3] Container network details:"
echo "web1:"
docker inspect web1 --format '{{.NetworkSettings.IPAddress}} {{.NetworkSettings.MacAddress}}'
echo "web2:"
docker inspect web2 --format '{{.NetworkSettings.IPAddress}} {{.NetworkSettings.MacAddress}}'

# Step 4: Look at the veth pairs on the host
echo "[Step 4] veth interfaces on host:"
ip link show type veth 2>/dev/null || echo "(Run on Linux to see veth pairs)"

# Step 5: Inspect iptables rules Docker created
echo "[Step 5] Docker iptables NAT rules:"
sudo iptables -t nat -L -n 2>/dev/null | grep -A 20 DOCKER || echo "(Run on Linux to see iptables)"

# Step 6: Test container-to-container communication
echo "[Step 6] web1 pinging web2..."
WEB2_IP=$(docker inspect web2 --format '{{.NetworkSettings.IPAddress}}')
docker exec web1 ping -c 2 $WEB2_IP 2>/dev/null || \
  docker exec web1 wget -q -O- http://$WEB2_IP 2>/dev/null | head -3

# Step 7: Inspect from inside the container
echo "[Step 7] Network view from INSIDE web1:"
docker exec web1 ip addr show 2>/dev/null || \
  docker exec web1 ifconfig 2>/dev/null
echo "Routes inside web1:"
docker exec web1 ip route 2>/dev/null || \
  docker exec web1 route -n 2>/dev/null

# Step 8: DNS resolution (only works on custom networks)
echo "[Step 8] Creating custom network with DNS..."
docker network create mesh-net
docker run -d --name web3 --network mesh-net nginx:alpine
docker run -d --name web4 --network mesh-net nginx:alpine
sleep 1
echo "web3 resolving web4 by name:"
docker exec web3 ping -c 2 web4 2>/dev/null || echo "DNS resolution works on custom networks"

# Step 9: Cross-network isolation
echo "[Step 9] web1 (bridge) trying to reach web3 (mesh-net)..."
WEB3_IP=$(docker inspect web3 --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}')
docker exec web1 ping -c 1 -W 1 $WEB3_IP 2>/dev/null && \
  echo "CONNECTED (unexpected)" || echo "ISOLATED (expected — different networks!)"

# Step 10: Port mapping trace
echo "[Step 10] Port mapping: localhost:8081 → web1:80"
curl -s http://localhost:8081 | head -5
echo "The port mapping was done via iptables DNAT rule"

# Cleanup
echo "[Cleanup] Removing containers and network..."
docker rm -f web1 web2 web3 web4 2>/dev/null
docker network rm mesh-net 2>/dev/null

echo ""
echo "=== Key Takeaways ==="
echo "1. Docker creates a veth pair per container (just like we did manually in Module 01)"
echo "2. The docker0 bridge connects all default-network containers"
echo "3. iptables DNAT handles port mapping (-p 8080:80)"
echo "4. iptables MASQUERADE handles outbound NAT"
echo "5. Custom networks get DNS resolution; default bridge does not"
echo "6. Different Docker networks are isolated (like K8s NetworkPolicy)"
echo ""
echo "=== Lab Complete ==="
```

---

## Connection to Kubernetes and Istio

| Docker Concept | Kubernetes Equivalent | Istio Change |
|---------------|----------------------|--------------|
| docker0 bridge | CNI bridge (cni0) | No change to bridge |
| Container namespace | Pod namespace | Sidecar shares same namespace |
| Port mapping (DNAT) | kube-proxy Service rules | Istio replaces with Envoy routing |
| Container DNS | CoreDNS | Istio DNS proxy (optional) |
| Network isolation | NetworkPolicy | AuthorizationPolicy |
| docker networks | K8s namespaces + NetworkPolicy | Istio Sidecar resource |

### The Key Insight

In plain Docker/K8s, traffic goes:
```
App → kernel (iptables) → network → destination
```

With Istio, traffic goes:
```
App → iptables REDIRECT → Envoy sidecar → mTLS → network → Envoy sidecar → App
```

Istio **intercepts** the normal flow by adding iptables `REDIRECT` rules that send all traffic through the Envoy sidecar first. This is why understanding iptables from Module 01 is essential!

## Next Module

Continue to [Module 03: Kubernetes Networking →](../03-kubernetes-networking/)

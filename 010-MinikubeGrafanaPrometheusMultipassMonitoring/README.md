# Lab 10 — Prometheus & Grafana on Minikube (Monitor K8s + Multipass VM)

Deploy the kube-prometheus-stack Helm chart on Minikube to monitor cluster nodes and containers, and add a Multipass VM to the same Grafana dashboard.

> Use placeholders for any credentials. Keep TLS settings appropriate for lab use only.

## Prerequisites

- Ubuntu 20.04 host (>= 2 vCPU, 8 GB RAM)
- Docker, Docker Compose
- Minikube installed and running
- Helm v3 installed
- Multipass installed

## Setup

1) Start Minikube and set kubectl alias
```bash
minikube start
minikube status
alias k="kubectl"
```

2) Install Helm (if needed)
```bash
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```

3) Deploy Metrics Server (enable insecure TLS for Minikube lab)
```bash
wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Edit components.yaml to add:
#   - --kubelet-insecure-tls
#   - --kubelet-preferred-address-types=InternalIP
kubectl -n kube-system apply -f components.yaml
kubectl top nodes   # verify metrics are available
```

4) Add Prometheus community repo
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

5) Deploy kube-prometheus-stack (Prometheus + Grafana)
```bash
helm install prometheus-grafana prometheus-community/kube-prometheus-stack -f values.yaml
```

6) Access Grafana
```bash
kubectl -n default port-forward svc/prometheus-grafana 8888:80
kubectl get secret prometheus-grafana -o=jsonpath="{.data.admin-password}" | base64 -d
```
Open `http://localhost:8888`, username `admin`, password from the command above.

7) Add dashboard variables (example)
- In Grafana → Dashboard settings → Variables, create:
  - `Node`: Query `label_values(kubernetes_io_hostname)`
  - `Container`: Query `label_values(container)`
  - `Namespace`: Query `label_values(namespace)`
  - `interval`: Interval values `1m,10m,30m,1h,6h,12h,1d,7d,14d,30d`

8) Create a panel for pod status (example PromQL)
```promql
sum(kube_pod_status_phase{pod=~"^$Container.*",namespace=~"$Namespace"}) by (phase)
```
Change visualization to a bar gauge and save the dashboard (e.g., “Container Health Status”).

9) Add a Multipass VM to monitoring (optional)

- Launch a VM with node exporter or suitable exporter:
  ```bash
  multipass launch --name mon-vm --mem 2G --disk 10G
  multipass shell mon-vm
  # install and run node_exporter or Prometheus agent as desired
  ```
- Scrape the VM by adding a scrape job in Prometheus values or ConfigMap to include the VM’s IP and node exporter port.

## Validation

- `kubectl top nodes` returns metrics.
- `helm list` shows `prometheus-grafana` release.
- Grafana UI accessible at `http://localhost:8888`; dashboards display node/pod metrics.
- (Optional) Multipass VM metrics appear in Prometheus targets and Grafana panels.

## Cleanup

```bash
helm uninstall prometheus-grafana
kubectl delete -n kube-system -f components.yaml
minikube delete
multipass delete --purge mon-vm || true
```

## Troubleshooting

- **Metrics server errors**: Ensure `--kubelet-insecure-tls` and `--kubelet-preferred-address-types=InternalIP` are set for Minikube.
- **Grafana login**: Reset password from the `prometheus-grafana` secret; ensure port-forward uses the correct service name.
- **Missing VM metrics**: Confirm node exporter is running on the VM and Prometheus scrape config includes the VM IP/port.

## References

- https://minikube.sigs.k8s.io/docs/start/
- https://helm.sh/docs/intro/install/
- https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack

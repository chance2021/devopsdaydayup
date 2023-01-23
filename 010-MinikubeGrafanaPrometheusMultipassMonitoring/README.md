# Project Name: Deploy Prometheus/Grafana on Minikube and Monitor The Health of Containers and VMs

## Project Goal
In this lab, we will deploy the **Prometheus-Grafana** **Helm** chart on **Minikube**, and then set up a **dashboard** to monitor the health of the containers in the Minikube cluster, as well as a VM created by **Multipass**.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Project Steps](#project_steps)
   - [Monitor Kuberentes Nodes and Containers](#k8s)
   - [Monitor VMs](#vm)
   - [Alert Configuration](#alert)
3. [Post Project](#post_project)
4. [Troubleshooting](#troubleshooting)
5. [Reference](#reference)

## <a name="prerequisites">Prerequisites</a>
- Ubuntu 20.04 OS (Minimum 2 core CPU/8GB RAM/30GB Disk)
- Docker(see installation guide [here](https://docs.docker.com/get-docker/))
- Docker Compose(see installation guide [here](https://docs.docker.com/compose/install/))
- Minikube (see installation guide [here](https://minikube.sigs.k8s.io/docs/start/))
- Helm (see installation guide [here](https://helm.sh/docs/intro/install/)
- Multipass (see installation guide [here](https://multipass.run/install))

## <a name="project_steps">Project Steps</a>
### <a name="k8s">Monitor Kuberentes Nodes and Containers</a>
#### 1. Start Minikube
You can install the **Minikube** by following the instruction in the [Minikube official website](https://minikube.sigs.k8s.io/docs/start/). Once it is installed, **start** the Minikube by running below command:
```
minikube start
minikube status
```
Once the Minikube starts, you can download the **kubectl** from [k8s official website](https://kubernetes.io/docs/tasks/tools/)
```
minikube kubectl
```
Then, when you run the command `kubectl get node`, you should see below output:
```
NAME       STATUS   ROLES           AGE     VERSION
minikube   Ready    control-plane   4m37s   v1.25.3
```
#### 2. Enable Minikube Dashboard
You can also enable your **Minikube dashboard** by running below command:
```
minikube dashboard
```
A Kuberentes Dashboard will pop out in your browser immediately. You can explore all Minikube resources in this UI website.

#### 3. Install Helm v3.x
Run the following commands to install **Helm v3.x**:
> ref: https://helm.sh/docs/intro/install/
```
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```

#### 4. Deploy Metrics Server
In order to collect more metrics from the cluster, you should install **metrics server** on the cluster first. You can download the manifest file as follows:
```
wget https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```
Then you need to **update the yaml file** by **adding** below section to **turn off the TLS verification** (more detail please see the [**Issue 1**](#issue1) in the **troubleshooting section** below)
```
apiVersion: apps/v1
kind: Deployment
metadata:
...
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      containers:
      - args:
        - ...
        - --kubelet-insecure-tls
        - --kubelet-preferred-address-types=InternalIP
...
```
Lastly, **apply** the manifest:
```
kubectl -n kube-system apply -f components.yaml
```
Once the Pod is ready, you can run below command to test out if the metric server is working.
```
kubectl top node
```
You should be able to see below result if it is working fine
```
$ kubectl top nodes
NAME       CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
minikube   622m         7%     2411Mi          15%  
```
#### 5. Add Helm Repo
Once Helm is set up properly, **add** the **repo** as follows:
```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm search repo prometheus-community
```
#### 6. Deploy Prometheus Helm Chart
**Install** Prometheus Helm Chart by running below command:
```
helm install prometheus-grafana prometheus-community/kube-prometheus-stack -f values.yaml
```

#### 7. Configure Grafana Dashboard Manually
Once the deployment is settle, you can **port-forward** to the Grafana service to access the portal from your local:
```
kubectl -n default port-forward svc/prometheus-grafana 8888:80
```
Open your **brower** and then type the URL: [http://localhost:8888](http://localhost:8888). You should see the **Grafana login portal**. You can retrieve the **admin password** by running below command in another terminal:
```
kubectl get secret prometheus-grafana -o=jsonpath="{.data.admin-password}"|base64 -d
```
Enter the username (**admin**) and the password you got above (e.g. **prom-operator**), then you should be logged in the Grafana welcome board. </br>
Go to the **Dashboards** section in the left navigation lane, and click **+New dashboard** to open a new dashboard. Follow below steps to add some **variables** before creating a panel.</br>
a. Click **Dashboard settings**(the gear icon) in the top right </br>
b. Go to **Variables** section </br>
c. Click **Add variable** and add below variables </br>

**Node** </br>
---
- **Select variable type**: Query
- **Name**: Node
- Label: <leave it blank>
- Description: Cluster Nodes
- Show on dashboard: Label and value (Default)
- **Data source**: Prometheus
- **Query**: label_values(kubernetes_io_hostname)
- Regex: <leave it blank>
- Sort: Disabled (Default)
- Refresh: On dashboard load (Default)
- Multi-value: Unselect (Default)
- **Include All option**: Selected
- **Custom all value**: .\*

Click **Apply** to save the change</br>

**Container**
---
- **Select variable type**: Query
- **Name**: Container
- Label: <leave it blank>
- Description: Containers in the Cluster
- Show on dashboard: Label and value (Default)
- **Data source**: Prometheus
- **Query**: label_values(container)
- Regex: <leave it blank>
- Sort: Disabled (Default)
- Refresh: On dashboard load (Default)
- Multi-value: Unselect (Default)
- **Include All option**: Selected
- **Custom all value**: .\*

Click **Apply** to save the change</br>

**Namespace**
---
- **Select variable type**: Query
- **Name**: Namespace
- Label: <leave it blank>
- Description: Namespace in the Cluster
- Show on dashboard: Label and value (Default)
- **Data source**: Prometheus
- **Query**: label_values(namespace)
- Regex: <leave it blank>
- Sort: Disabled (Default)
- Refresh: On dashboard load (Default)
- Multi-value: Unselect (Default)
- **Include All option**: Selected
- **Custom all value**: .\*

Click **Apply** to save the change</br>

**interval**
---
- **Select variable type**: Interval
- **Name**: interval
- Label: <leave it blank>
- Description: Interval
- **Data source**: Prometheus
- **Values**: 1m,10m,30m,1h,6h,12h,1d,7d,14d,30d
- Auto Option: Enable (Default)
- Step count: 1 (Default)
- Min interval: 2m (Default)
Click **Apply** to save the change</br>
Click **Save** to save the dashboard. Name it as **Container Health Status** </br>
Once you go back to the Dashboard, you will see the **Node**/**Container**/**Namespace**/**Interval** sections are available in the top left with dropdown menu for choosing. </br>
</br>
</br>
Now we are going to add a new **Panel**. Click **Add Panel** in the top right and click **Add a new panel** area. In the section **A**, type below query in the **Enter a PromQL query** field:
```
sum(kube_pod_status_phase{pod=~"^$Container.*",namespace=~"default"}) by (phase)
```
and click **Run queries** to execute the query. Make sure to choose **All** in top **Container** dropdown menu. You should see a line chart in above display area. </br>
</br>
In order to make the graph more readable, we can change the type of charts. Just expanding the **Time series** section in the top right and search for **bar gauge** to apply. </br>
</br>
Before saving the change, go to **Panel options** section in the right lane and type the name in **Title** field, for example, **Pod Status in Default Namespace**. And click **Apply** to save the change.</br>
</br>
</br>
Next, we will create a **panel** to monitor the **top 5 memory intense Pods**. Again, click **Add panel** and then choose **Add a new panel**. Copy and paste below query in the query field:
```
topk(5,avg(container_memory_usage_bytes{}) by (pod) /1024/1024/1024)
```
and click **Run queries** to execute the query.Expanding the **Time series** section in the top right and search for **Bar gauge** to apply. You can also change the layout orientation in **Bar gauge** -> **Orientation** section.
![Top 5 Memory Intense Pods](images/top-5-memory-intense-pod.png)

#### 8. Configure Dashboard by Importing Json file
Instead of manually configuring the dashboard, you can also **import the pre-defined dashboard from a json file**. </br>
In the Grafana Home page, go to **Dashboards** and click **Import**. Click **Upload JSON file** and choose **pod-health-status.json** under `devopsdaydayup/010-MinikubeGrafanaPrometheusMonitoring` folder. Then you should see the dashboard imported. You can adjust some queries/graph/setting as your needs.

#### 9. Download Dashboard Template
A variety of dashboard templates are available to meet different needs in [**Grafana Labs**](https://grafana.com/grafana/dashboards/). you can go to the [website](https://grafana.com/grafana/dashboards/) and search for any dashboard you like, and just need to copy the **ID** and paste to **Grafana website** -> **Dashboard** -> **Import** -> **Import via grafana.com** and click **Load** to load the template from the website.
![Template ID](images/template-id.png)
![Template Import](images/template-import.png)
#### 10. Find Help from Your AI Friend!
You can also take advanage of your AI friend (e.g. [ChatGPT](https://chat.openai.com/chat)) to generate a query as needed.
![chatgpg](images/chatgpg.png)

### <a name="vm">Monitor VMs</a>
You can use Prometheus to monitor VMs outside of the Kubernetes cluster in addition to containers. Below are the steps to do so.
#### 1. [Option] Deploy a test VM
If you don't want to install **node exporter** in your local machine directly, you can just spin up a fresh new VM by [multipass](https://multipass.run/install). If you are using Ubunut, you can run below commands to create a new VM via `multipass`:
```
snap install multipass
multipass launch
```
After deploying the VM, access it to obtain its IP address. This IP address will later be configured on the Prometheus server, allowing it to collect metrics from the VM.
```
multipass list
multipass shell <VM Name>
sudo apt update
sudo apt install net-tools -y
ifconfig
exit
```
You can update the **IP address** into `values.prometheus-only.yaml` file under below section:
```
      - job_name: multipass-vm
        static_configs:
          - targets:
            - 10.53.115.53:9100       <------Update this IP address
```
#### 2. Install Node Exporter
To monitor VMs with Prometheus, you must install the [node exporter](https://github.com/prometheus/node_exporter/releases) on each VM you want to monitor.
```
wget https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.5.0.linux-amd64.tar.g
cd node_exporter-*.*-amd64
./node_exporter
```
#### 3. Deploy Prometheus Helm Chart
To monitor the VM, which is not part of the K8s cluster, you can deploy [another Prometheus Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus) in the existing Minikube cluster. However, you may need to uninstall the previous deployment to avoid port conflict issues, if the default port has not been changed.
```
helm -n default uninstall prometheus-grafana
```
Then you can deploy the new Helm Chart:
```
helm install prometheus prometheus-community/prometheus -f values.prometheus-only.yaml
```
Once the Pod is up and running, you can **port forward** the **prometheus-server** to your local port to be access
```
kubectl -n default port-forward prometheus-server 9080:80
```
Open your browser and go to [http://localhost:9080](http://localhost:9080). Type below query in **Expression** field and click **Execute** to run the query:
```
(1 - (node_memory_MemAvailable_bytes{job="multipass-vm"} / (node_memory_MemTotal_bytes{job="multipass-vm"})))* 100
```
To view the memory usage history of the multipass VM, click the **Graph** tab and a graph will appear.
![prometheus-expression](images/prometheus-expression.png)

#### 4. Deploy Grafana Helm Chart
To enhance the visual appeal of our metrics, we will implement a Grafana for displaying them.
```
helm repo add grafana https://grafana.github.io/helm-charts
helm install grafana grafana/grafana 
```
Get your `admin` user password by running:
```
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```
The Grafana server can be **accessed via port 80** on the following DNS name from within your cluster:
```
export POD_NAME=$(kubectl get pods --namespace monitoring -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
kubectl --namespace monitoring port-forward $POD_NAME 3000
```
**Login** with the password from above and the username: `admin` in [http://localhost:3000](http://localhost:3000) via your browser. Go to **Configuration** (gear icon in the left lane) -> **Data sources** -> Click **Add data source** -> Choose **Prometheus**. In the URL, enter `http://prometheus-server` and then **Save & test** the change. </br>
Go to **Explorer** and type below query in the PromQL query field

```
(1 - (node_memory_MemAvailable_bytes{job="multipass-vm"} / (node_memory_MemTotal_bytes{job="multipass-vm"})))* 100

```
The graph will appear as shown below.
![grafana-query](images/grafana-query.png)
One useful node expertor dashboard template is available in [this website](https://grafana.com/grafana/dashboards/15172-node-exporter-for-prometheus-dashboard-based-on-11074/) or in `vm-health-status.json` file under the same folder as this README.

### <a name="alert">Alert Manager</a>
The next crucial step in setting up the monitoring system is to properly configure **alerts**. The alert configuration will be handled by the **Alert Manager service**, which will then forward the alerts to various messaging platforms, including but not limited to Slack, Telegram, Discord, and Microsoft Teams. In our laboratory, we will utilize **Slack** as the messaging platform. Participants can either create their own Slack channel (see [here](https://api.slack.com/messaging/webhooks) how to create a Slack webhook) or contact me at **chance.chen21@gmail.com** to join the existing one. </br>
### 1. Update Configuration
We need to update Prometheus/Alert Manager with **Slack info**, as well as **Alert rules**. Here is the example that we have added in `values.prometheus-only.yaml` file:
```
serverFiles:
...
  # The following are the alert rules for specific conditions
  alerting_rules.yml:
    groups:
    - name: Test Instances
      rules:
      - alert: VM_High_Memory_Usage
        expr: 100 * (node_memory_MemTotal_bytes{job="multipass-vm"} - node_memory_MemAvailable_bytes{job="multipass-vm"}) / node_memory_MemTotal_bytes{job="multipass-vm"} > 60
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "High memory usage on VM {{ $labels.instance }}"
          description: "Memory usage on VM {{ $labels.instance }} is at {{ $value }}%, which exceeds the threshold of 60%."
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: page
        annotations:
          description: '{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 5 minutes.'
          summary: 'Instance {{ $labels.instance }} down'
# The following is the receiver configuration. In the lab, we are using Slack.
alertmanager:
  config:
    global:
      resolve_timeout: 1m
      slack_api_url: 'https://hooks.slack.com/services/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'

    templates:
    - '/etc/alertmanager/*.tmpl'

    receivers:
    - name: '#slack-notification'
      slack_configs:
      - channel: 'alertmanager-testing'
        send_resolved: true

    route:
      group_wait: 10s
      group_interval: 1m
      receiver: '#slack-notification'
      repeat_interval: 1h
``` 
#### 2. Re-deploy Prometheus
Then, you can update the Prometheus Helm Deployment by running following command:
```
helm upgrade prometheus prometheus-community/prometheus -f values.prometheus-only.yaml

```

#### 3. Test
After completing the deployment, use the **Prometheus UI** to verify that the alert rule is in place. To access the UI, **port forward** the Prometheus service.
```
kubectl port-forward svc/prometheus-server 8888:80
```
Go to **Alerts** tab in the top and you should see 2 **Inactive** alerts there
![alert-rules-1](images/alert-rules-1.png)
To trigger the alert, navigate to the VM being monitored and run the command below to increase the RAM usage to 95%.
```
sudo apt update
sudo apt install stress-ng -y
stress-ng --vm 1 --vm-bytes 95% --vm-method all --verify -t 10m -v
```
Please wait a few minutes and you will receive a notification in the designated Slack channel.
![slack](images/slack.png)

## <a name="post_project">Post Project</a>
Stop Multipass VM if using
```
multipass stop <VM_name>
```
Stop Minikube
```
minikube stop
```
## <a name="troubleshooting">Troubleshooting</a>
### <a name=issue1>Issue 1: Error from server (ServiceUnavailable): the server is currently unable to handle the request (get nodes.metrics.k8s.io)</a>
When deploying metrics server in the cluster, the deployment won't be ready and showing below error
```
E0112 15:02:25.912192       1 scraper.go:140] "Failed to scrape node" err="Get \"https://192.168.49.2:10250/metrics/resource\": x509: cannot validate certificate for 192.168.49.2 because it doesn't contain any IP SANs" node="minikube"
```
When you run `kubectl top node` below error occurs:
```
Error from server (ServiceUnavailable): the server is currently unable to handle the request (get nodes.metrics.k8s.io)
```
Solution:
Add below command section in the deployment manifest yaml file to disable the TLS verification
```
command:
- --kubelet-insecure-tls
- --kubelet-preferred-address-types=InternalIP
```
Above are all steps to deploy/setup Premotheus-Grafana in a Kubernetes cluster.


> ref: https://thospfuller.com/2020/11/29/easy-kubernetes-metrics-server-install-in-minikube-in-five-steps/

## <a name="reference">Reference</a>
- [Prometheus Overview](https://prometheus.io/docs/introduction/overview/)</br>
- [Grafana Github README](https://github.com/grafana/helm-charts/blob/main/charts/grafana/README.md)</br>
- [Grafana Awesome Alert](https://awesome-prometheus-alerts.grep.to/)</br>
- [Prometheus Queries Example Official](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [Prometheus Queries Example 1](https://www.opsramp.com/guides/prometheus-monitoring/prometheus-alerting/)</br>
- [Prometheus Queries Example 2](https://sysdig.com/blog/prometheus-query-examples/)</br>
- [Prometheus Queries Example 3](https://sysdig.com/blog/getting-started-with-promql-cheatsheet/)</br>
- [Prometheus Queries Example 4](https://www.containiq.com/post/promql-cheat-sheet-with-examples)
- [Node Exporter Installation](https://prometheus.io/docs/guides/node-exporter/)
- [Step-by-step guide to setting up Prometheus Alertmanager with Slack, PagerDuty, and Gmail](https://grafana.com/blog/2020/02/25/step-by-step-guide-to-setting-up-prometheus-alertmanager-with-slack-pagerduty-and-gmail/)
- [Alerting Rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [Defining Recording Rules](https://prometheus.io/docs/prometheus/latest/configuration/recording_rules/)
- [Setup Alertmanager](https://ashish.one/blogs/setup-alertmanager/)
- [Alert Script](https://gist.github.com/cherti/61ec48deaaab7d288c9fcf17e700853a)
```
url=prometheus-2-alertmanager.monitoring.svc:9093/api/v2/alerts
startsAt=`date --iso-8601=seconds`
endsAt=`date --iso-8601=seconds`
curl -XPOST $url -H "Content-Type: application/json" -d '[{"status": "firing","labels": {"alertname": "my_cool_alert","service": "curl","severity": "warning","instance": "0"},"annotations": {"summary": "This is a summary","description": "This is a description."},"generatorURL": "http://prometheus.int.example.net/<generating_expression>","startsAt": "2023-01-15T01:05:36+00:00"}]'

curl -XPOST $url -H "Content-Type: application/json" -d '[{"status": "firing","labels": {"alertname": "my_cool_alert","service": "curl","severity": "warning","instance": "0"},"annotations": {"summary": "This is a summary","description": "This is a description."},"generatorURL": "http://prometheus.int.example.net/<generating_expression>","startsAt": "'`date --iso-8601=seconds`'"}]'

curl -XPOST -H "Content-Type: application/json" $url -d '[{"status": "resolved","labels": {"alertname": "my_cool_alert","service": "curl","severity": "warning","instance": "0"},"annotations": {"summary": "This is a summary","description": "This is a description."},"generatorURL": "http://prometheus.int.example.net/<generating_expression>","startsAt": "2020-07-23T01:05:36+00:00","endsAt": "2020-07-23T01:05:38+00:00"}]'
```
- [Alert Script 2](https://gist.github.com/cherti/61ec48deaaab7d288c9fcf17e700853a)
- [Alert Script 3](https://gist.github.com/carinadigital/fd2960fdccd77dbdabc849656c43a070)
- [stress-ng USAGE](https://stackoverflow.com/questions/45317515/stress-ng-ram-testing-commands)
- [Multipass Commandline](https://multipass.run/docs/launch-command)


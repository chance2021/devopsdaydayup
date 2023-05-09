# Kubernetes Onboarding

## Setup kubectl
### Ubuntu
1. **Download** the latest release with the command:
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
```
2. **Install** kubectl
```
sudo apt update
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```
3. Check version
```
kubectl version --client
```
4. Create `.kube` folder under your home directory if doesn't exist:
```
mkdir ~/.kube
```
5. Paste your **kubeconfig** file into `.kube` folder and name as `config`
### Mac
1. **Download** the latest release:
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
```
2. Make the kubectl binary **executable**
```
chmod +x ./kubectl
```
3. **Move** the kubectl binary to a file location on your system `PATH`:
```
sudo mv ./kubectl /usr/local/bin/kubectl
sudo chown root: /usr/local/bin/kubectl
```
4. Check version:
```
kubectl version --client
```
5. Create `.kube` folder under your home directory if doesn't exist:
```
mkdir ~/.kube
```
6. Paste your **kubeconfig** file into `.kube` folder and name as `config`

## Useful Utilities
### kubectl autocomplete
```
source <(kubectl completion bash) # set up autocomplete in bash into the current shell, bash-completion package should be installed first.
echo "source <(kubectl completion bash)" >> ~/.bashrc # add autocomplete permanently to your bash shell.
alias k=kubectl
complete -o default -F __start_kubectl k
```
### grep
1. Search for a key word
```
$ kubectl get pod -A|grep jenkins
test-jenkins    jenkins-0                          0/2     Completed   0  
```
2. `-i`: Case insensitive search
```
$ kubectl get pod -A|grep -i JEnkins
test-jenkins    jenkins-0                          1/2     Running   2 (6d14h ago)   14d
```
3. `-v`: Invert the sense of matching, to select non-matching lines
```
$ k get pod -A|grep -v Running
NAMESPACE       NAME                               READY   STATUS    RESTARTS         AGE
keycloak        keycloak-0                         0/1     Pending   0                17d
keycloak        keycloak-postgresql-0              0/1     Pending   0                17d
keycloak        keycloak20-postgresql15-0          0/1     Pending   0  
```
4. `-e`: Specifies expression to match multiple key words
```
$ k get pod -A|grep -ie jenkins -e keycloak
keycloak        keycloak-0                         0/1     Pending   0                17d
keycloak        keycloak-postgresql-0              0/1     Pending   0                17d
keycloak        keycloak20-postgresql15-0          0/1     Pending   0                17d
test-jenkins    jenkins-0                          1/2     Running   3 (33s ago) 
```
5. `-R`: Search recursively for a pattern in the directory
```
$ grep -R jenkins ./*
./002-JenkinsCICD/github-workflow.yaml:#  trigger-jenkins-cicd:
./002-JenkinsCICD/README.md:![JenkinsPipeline](images/jenkinspipeline.png)
```
6. `-C NUM`: Print NUM lines of output context
```
$ k describe pod keycloak-0|grep Image -C 2
Init Containers:
  download-plugins:
    Image:      ubuntu
    Port:       <none>
    Host Port:  <none>
--
Containers:
  keycloak:
    Image:       docker.io/bitnami/keycloak:16.1.0-debian-10-r0
    Ports:       8080/TCP, 8443/TCP, 9990/TCP
    Host Ports:  0/TCP, 0/TCP, 0/TCP
```
7. `-A NUM`: Print NUM lines of trailing context after matching lines
```
$ k describe pod keycloak-0|grep Image -A 2
    Image:      ubuntu
    Port:       <none>
    Host Port:  <none>
--
    Image:       docker.io/bitnami/keycloak:16.1.0-debian-10-r0
    Ports:       8080/TCP, 8443/TCP, 9990/TCP
    Host Ports:  0/TCP, 0/TCP, 0/TCP
```
8. `-B NUM`: Print NUM lines of leading context before matching lines.
```
$ k describe pod keycloak-0|grep Image -B 2
Init Containers:
  download-plugins:
    Image:      ubuntu
--
Containers:
  keycloak:
    Image:       docker.io/bitnami/keycloak:16.1.0-debian-10-r0
```
9. `man grep` for more information

### kubectx
> ref: https://github.com/ahmetb/kubectx
**kubectx** is a tool to switch between contexts (clusters) on kubectl faster. \n
**kubens** (`alias ns=kubens`) is a tool to switch between Kubernetes namespaces (and configure them for kubectl) easily.

### kube-ps1
> ref: https://github.com/jonmosco/kube-ps1
A script that lets you add the current Kubernetes context and namespace configured on kubectl to your Bash/Zsh prompt strings (i.e. the $PS1).

### krew
> Installation ref: https://krew.sigs.k8s.io/docs/user-guide/setup/install/
> Usage ref: https://itnext.io/kubernetes-the-krew-plugins-manager-and-useful-kubectl-plugins-list-8143d65c6c48
> Awesome kubectl plugin ref: https://github.com/ishantanu/awesome-kubectl-plugins

Warning: These plugins are not audited for security by the Krew maintainers.

Krew itself is a kubectl plugin that is installed and updated via Krew (yes, Krew self-hosts).
- community-images
- tail
- log
- topology
- watch
- kutall
- status
- pod-dive
- janitor

### tmux
ref: https://tmuxcheatsheet.com/
- tmux new -s <session_name>
- tmux attach -t <session_name>
- ctrl+b % (Split pane with horizontal layout)
- ctrl+b “  (Split pane with vertical layout)
- ctrl+b <up arrow>   (Move to upper pane)
- ctrl+b <down arrow> (Move to lower pane)
- ctrl+b :set mouse on (Enable mouse mode) 
> Note: tmux session will be kept in the server until it is deleted or the server is rebooted.

## Common Usage Scenarios
### 1. Check Pod Log
```
kubectl logs <podName> -n <namespace> -c <container_name>
```
Example 1: Check the logs by pod's name
```
k get pod|grep -i keycloak
k logs keycloak-0
```
Example 2: Check the logs for the previous pod
```
k logs --previous keycloak-0
```
Example 3: Check the last lines of the logs
```
k logs -f keycloak-0
k logs --tail=10 keycloak-0
```
Example 4: Check the logs by pods' label
```
k get pod --show-labels|grep keycloak
k logs -f -l app.kubernetes.io/component=keycloak
```
### 2. Access A Pod
```
kubectl exec -it <podName> -n <namespace> -- /bin/bash
```
Example 1: Access to a pod
```
k exec -it keycloak-0 -- bash
```

### 3. Check Resources
> Note: You need to make sure you have deployed [metrics server](https://github.com/kubernetes-sigs/metrics-server). Otherwise you may receive error `Metrics API not available` 
```
kubectl top pod -n <namespace> [--sort-by=cpu|memory]
```
Example 1: Check a Pod's resource usage
```
k top pod keycloak-0
```
Example 2: Rank the Top 5 Pods with the highest CPU consumption
```
k top pod -A --sort-by=cpu|head -6
```
Example 3: Rank the Top 5 Pods with the highest Memory consumption
```
k top pod -A --sort-by=memory|head -6
```
Example 4: Check Nodes Resource Consumption
```
k top nodes
```

### 4. Merge Multiple Kubeconfig Files
1. Backup your existing config
```
cp ~/.kube/config ~/.kube/config.bak 
```
2. Merge the two config files together into a new config file 
```
KUBECONFIG=~/.kube/config:/path/to/new/config kubectl config view --flatten > /tmp/config 
```
3. Replace your old config with the new merged config 
```
mv /tmp/config ~/.kube/config 
```
4. (optional) Delete the backup once you confirm everything worked ok 
```
rm ~/.kube/config.bak
```

### 5. Debug Nodes
> ref: https://kubernetes.io/docs/tasks/debug/debug-cluster/kubectl-node-debug/ 

Example 1: Deploy a Pod to a Node that you want to troubleshoot
```
kubectl debug node/mynode -it --image=ubuntu
```
Note: The Node's filesystem is mounted at `/host` in the Pod.
- /host/var/log/kubelet.log
- /host/var/log/kube-proxy.log
- /host/var/log/kube-proxy.log

Ensure to delete the Pod after the troubleshooting.

Example 2: Create a copy of the mypod changing the command of mycontainer
```
kubectl debug mypod -it --copy-to=my-debugger --container=mycontainer -- bash
```

Example 3: Create a debug container named debugger using a custom automated debugging image.
```
kubectl debug --image=myproj/debug-tools -c debugger mypod
```

## k9s
1. Install k9s in your local machine (ref: https://k9scli.io/topics/install/)
2. Useful Commands (ref: https://k9scli.io/topics/commands/) k9s -c pod ?




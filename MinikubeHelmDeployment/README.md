# Project Name: Helm Deployment in K8s 

# Project Goal
In this article, you will learn how to deploy a Jenkins via Helm Chart in K8s

# Table of Contents
1. [Prerequisites](#prerequisites)
2. [Project Steps](#project_steps)
3. [Post Project](#post_project)
4. [Troubleshooting](#troubleshooting)
5. [Reference](#reference)

# <a name="prerequisites">Prerequisites</a>
- Ubuntu 20.04 OS (Minimum 2 core CPU/8GB RAM/30GB Disk)
- Docker(see installation guide [here](https://docs.docker.com/get-docker/))
- Docker Compose(see installation guide [here](https://docs.docker.com/compose/install/))
- Minikube (see installation guide [here](https://minikube.sigs.k8s.io/docs/start/))

# <a name="project_steps">Project Steps</a>

## 1. Start Minikube
You can install the minikube by following the instruction in the [official website](https://minikube.sigs.k8s.io/docs/start/). Once it is installed, start the minikube by running below command:
```
minikube start
```
Once the Minikube starts, you can download the kubectl used by minikube and alias the commend to faciliate the operation:
```
minikube kubectl
alias km="minikube kubectl --"
```
Then, when you run the command `km get node`, you should see below output:
```
NAME       STATUS   ROLES           AGE     VERSION
minikube   Ready    control-plane   4m37s   v1.25.3
```
Or if you already have `kubectl` installed, you can use `kubectl` directly, as the Minikube installation will modify the `~/.kube/config` file and you will access the miniokube the same as other existing clusters if you have any.
```
alias k="kubectl"
k get node
```
## 2. Enable Minikube Dashboard
You can also enable your Minikube dashboard by running below command:
```
minikube dashboard
```
You should see a Kuberentes Dashboard page pop out in your browser. You can explore all Minikube resources in this UI website.

## 3. Install Helm v3.x
Run the following commands to install Helm v3.x:
> Refer to https://helm.sh/docs/intro/install/
```
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```

## 4. Add Helm Repo
Once Helm is set up properly, add the repo as follows:
```
helm repo add jenkins https://charts.jenkins.io
helm repo update
```

## 5. Install Jenkins Chart
```
helm install jenkins jenkins/jenkins
```

## 6. Access Jenkins Website
Check if the Jenkins pod is in `Running` state
```
k get pod
```
If so, forward the port to your local and then you can access the Jenkins website
```
kubectl --namespace default port-forward svc/jenkins 8080:8080
```
Open your browser and type `http://0.0.0.0:8080`
```
> Note: You can retrieve the password by running following command. The username is `admin`.
```
kubectl exec --namespace default -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo
```

# <a name="post_project">Post Project</a>

# <a name="troubleshooting">Troubleshooting</a>

# <a name="reference">Reference</a>
[Bitnami Get Started with Bitnami Charts using Minikube](https://docs.bitnami.com/kubernetes/get-started-kubernetes/)</br>
[Jenkins Helm Chart](https://artifacthub.io/packages/helm/jenkinsci/jenkins)</br>
[Jenkins Configuration As Code Plugin](https://github.com/jenkinsci/configuration-as-code-plugin/tree/master/demos)</br>
[Running Jenkins on Kubernetes](https://cloud.google.com/solutions/jenkins-on-container-engine)</br>
[Jenkins Configuration as Code](https://jenkins.io/projects/jcasc/)</br>

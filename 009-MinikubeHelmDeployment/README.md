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
- Helm (see installation guide [here](https://helm.sh/docs/intro/install/)

# <a name="project_steps">Project Steps</a>

## 1. Start Minikube
You can install the **Minikube** by following the instruction in the [Minikube official website](https://minikube.sigs.k8s.io/docs/start/). Once it is installed, start the minikube by running below command:
```
minikube start
minikube status
```
Once the Minikube starts, you can download the **kubectl** used by Minikube:
```
minikube kubectl
alias k="minikube kubectl --"
```
Then, when you run the command `kubectl get node` or `k get node`, you should see below output:
```
NAME       STATUS   ROLES           AGE     VERSION
minikube   Ready    control-plane   4m37s   v1.25.3
```
Or if you already have **kubectl** installed (can be downloaded from [k8s official website](https://kubernetes.io/docs/tasks/tools/)), you can use **kubectl** directly, as the Minikube installation will modify the `~/.kube/config` file and you will have the access to the Miniokube cluster, as well as other existing clusters if you have any.
```
alias k="kubectl"
k get node
```
## 2. Enable Minikube Dashboard
You can also enable your **Minikube dashboard** by running below command:
```
minikube dashboard
```
You should see a Kuberentes Dashboard page pop out in your browser immediately. You can explore all Minikube resources in this UI website.

## 3. Install Helm v3.x
Run the following commands to install **Helm v3.x**:
> ref: https://helm.sh/docs/intro/install/
```
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```

## 4. Add Helm Repo
Once Helm is set up properly, **add** the **repo** as follows:
```
helm repo add jenkins https://charts.jenkins.io
helm repo update
```

## 5. Install Jenkins Helm Chart
Helm uses a packaging format called **charts**. A **chart** is a collection of files that describe a related set of Kubernetes resources, such as deployment, statefulset, secret, configmap, etc.. We are going to download/install the chart from above **jenkins** repo:

```
helm install jenkins jenkins/jenkins 
```
You can check the logs by running below command:
```
minikube logs
```

## 6. Access Jenkins Website
Now, you have deployed a Jenkins service in the Minikube. You can check if the Jenkins pod is in `Running` state
```
k get pod
```
If so, forward the port to your local and then you can access the Jenkins website
```
kubectl --namespace default port-forward svc/jenkins 8080:8080
```
Open your **browser** and type `http://0.0.0.0:8080`
> Note: You can retrieve the password by running following command. The username is `admin`.
```
kubectl exec --namespace default -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo
```

# <a name="post_project">Post Project</a>
Delete Minikube
```
minikube delete
```

# <a name="troubleshooting">Troubleshooting</a>

# <a name="reference">Reference</a>
[Bitnami Get Started with Bitnami Charts using Minikube](https://docs.bitnami.com/kubernetes/get-started-kubernetes/)</br>
[Jenkins Helm Chart](https://artifacthub.io/packages/helm/jenkinsci/jenkins)</br>
[Jenkins Configuration As Code Plugin](https://github.com/jenkinsci/configuration-as-code-plugin/tree/master/demos)</br>
[Running Jenkins on Kubernetes](https://cloud.google.com/solutions/jenkins-on-container-engine)</br>
[Jenkins Configuration as Code](https://jenkins.io/projects/jcasc/)</br>
[Create a Public Helm Charte Repository](https://medium.com/@mattiaperi/create-a-public-helm-chart-repository-with-github-pages-49b180dbb417)
[Create a Public Helm Charte Repository 2](https://www.opcito.com/blogs/creating-helm-repository-using-github-pages)

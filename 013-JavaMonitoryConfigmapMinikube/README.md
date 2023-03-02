# Project Name: Develop a Java Application in K8s for Monitoring ConfigMap Modifications and Content Changes


## Project Goal: 
In this lab, you will learn how to develop a Java application that interacts with the Kubernetes API to monitor changes to a file that is mounted by a ConfigMap. 

It is important to note that the file mounted by the ConfigMap is mounted as a symbolic link, so your Java code should read the link instead of the file directly.
## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Project Steps](#project_steps)
3. [Post Project](#post_project)
4. [Troubleshooting](#troubleshooting)
5. [Reference](#reference)

## <a name="prerequisites">Prerequisites</a>
- Ubuntu 20.04 OS (Minimum 2 core CPU/8GB RAM/30GB Disk)
- Docker(see installation guide [here](https://docs.docker.com/get-docker/))
- Docker Compose(see installation guide [here](https://docs.docker.com/compose/install/))
- Minikube (see installation guide [here](https://minikube.sigs.k8s.io/docs/start/))

## <a name="project_steps">Project Steps</a>

### 1. Build Image
Run below command to build the image:
```
eval $(minikube docker-env)
docker build -t java-monitor-file:v2.0 .
```
### 2. Deploy ConfigMap
```
kubectl apply -f configmap.yaml
```

### 3. Deploy Pod
```
kubectl apply -f pod.yaml
```

### 4. Verification
Now you can modify the configmap to see if the activity will be captured in the log:
```
kubectl logs -f configmap-demo-pod

# Open Another Terminal to modify the ConfigMap
kubectl edit cm game-demo

# Update anything within below section
data:
  game.properties: "enemy.types=aliens123456789876543,monsters\nplayer.maximum-lives=5
    \   \n"
```

Then wait for about 1 min and you should see below message in the log
```
```

## <a name="post_project">Post Project</a>
Stop Minikube
```
minikube stop
```

## <a name="troubleshooting">Troubleshooting</a>
### Issue 1: How to Dockerize a Java Application
Run a Docker container and install java/mvn package:
```
docker pull ubuntu
docker run -it --name ubuntu-java-build ubuntu bash

# Install Java
wget https://download.java.net/java/GA/jdk13.0.1/cec27d702aa74d5a8630c65ae61e4305/9/GPL/openjdk-13.0.1_linux-x64_bin.tar.gz
tar -xvf openjdk-13.0.1_linux-x64_bin.tar.gz
mv jdk-13.0.1 /opt/
JAVA_HOME='/opt/jdk-13.0.1'
PATH="$JAVA_HOME/bin:$PATH"
export PATH
java -version

# Install mvn
wget https://mirrors.estointernet.in/apache/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz
tar -xvf apache-maven-3.6.3-bin.tar.gz
mv apache-maven-3.6.3 /opt/
M2_HOME='/opt/apache-maven-3.6.3'
PATH="$M2_HOME/bin:$PATH"
export PATH
mvn -version

# Open another terminal and copy `src/main/java/FileMonitor.java` and `pom.xml` into the container
docker cp src/main/java/FileMonitor.java ubuntu-java-build:/
docker cp pom.xml ubuntu-java-build:/

# Go back to the container and run below command to compile the java code
mvn clean package

# You should be able to see a file called `file-monitor-1.0.0.jar` under `target` folder`. You can copy it into your host
exit
docker cp ubuntu-java-build:/target/file-monitor-1.0.0.jar .
```
ref: https://www.digitalocean.com/community/tutorials/install-maven-linux-ubuntu

## <a name="reference">Reference</a>
- [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [AliCloud Build an Image for a Java app via Dockerfile](https://static-aliyun-doc.oss-cn-hangzhou.aliyuncs.com/download%2Fpdf%2F60719%2FBest_Practices_reseller_en-US.pdf)
- [Pushing directly to the in-cluster Docker daemon (docker-env)](https://minikube.sigs.k8s.io/docs/handbook/pushing/#1-pushing-directly-to-the-in-cluster-docker-daemon-docker-env)

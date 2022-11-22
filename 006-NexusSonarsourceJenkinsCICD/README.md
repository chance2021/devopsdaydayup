# Project Name: 

# Project Goal

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

# <a name="project_steps">Project Steps</a>

## 1. Step 1
docker-compose build
docker-compose up -d

# To test
curl http://0.0.0.0:8081/nexus/service/local/status

Default credentials are: admin / admin123


It can take some time (2-3 minutes) for the service to launch in a new container. You can tail the log to determine once Nexus is ready:
$ docker logs -f nexus

## 6. Create a Jenkins Pipeline
a. In the Jenkins portal, click **"New Item"** in the left navigation lane, and type the item name (i.g. first-project) and select **"Pipeline"**. Click **"OK"** to configure the pipeline.</br>
b. Go to **"Pipeline"** section and select **"Pipeline script from SCM"** in the **"Definition"** field</br>
c. Select **"Git"** in **"SCM"** field</br>
d. Add `https://github.com/chance2021/devopsdaydayup.git` in **"Repository URL"** field</br>
e. Select your github credential in **"Credentials"**</br>
f. Type `*/main` in **"Branch Specifier"** field</br>
g. Type `006-NexusSonarsourceJenkinsCICD/Jenkinsfile` in **"Script Path"**</br>
h. Unselect **"Lightweight checkout"**</br>


Manage Jenkins -> Gloabl Tool Configuration -> Maven -> Name "m3" , check "Install automatically", version "3.8.6" -> Click "Save"

Add nexus in credential (admin/admin123)

# <a name="post_project">Post Project</a>

# <a name="troubleshooting">Troubleshooting</a>
## Issue 1: Fail to maven build
Below error occurs when running `mvn package -DskipTests=true`:
```
[ERROR] Failed to execute goal on project cargo-tracker: Could not resolve dependencies for project net.java:cargo-tracker:war:1.0-SNAPSHOT: Failed to collect dependencies at org.glassfish.jersey.media:jersey-media-moxy:jar:2.0 -> org.eclipse.persistence:org.eclipse.persistence.moxy:jar:2.5.0-M13: Failed to read artifact descriptor for org.eclipse.persistence:org.eclipse.persistence.moxy:jar:2.5.0-M13: Could not transfer artifact org.eclipse.persistence:org.eclipse.persistence.moxy:pom:2.5.0-M13 from/to maven-default-http-blocker (http://0.0.0.0/): Blocked mirror for repositories: [primefaces (http://repository.primefaces.org, default, releases+snapshots), eclipselink.repository (http://download.eclipse.org/rt/eclipselink/maven.repo, default, releases+snapshots)] -> [Help 1]
```
**Solution:**
Change Maven version to 3.3.9 in Jenkins

# <a name="reference">Reference</a>
[Integrating Ansible Jenkins CICD Process](https://www.redhat.com/en/blog/integrating-ansible-jenkins-cicd-process) </br>


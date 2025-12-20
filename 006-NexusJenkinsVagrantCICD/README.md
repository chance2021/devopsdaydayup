# Lab 6 — Jenkins to Nexus to Tomcat on Vagrant

Build a Java app with Jenkins, publish the WAR to Nexus, and deploy it to Tomcat running inside a Vagrant VM.

> Replace all credentials with your own (e.g., `jenkins-user`, `YOUR_NEXUS_PASSWORD`). Do not commit secrets.

## Prerequisites

- Ubuntu 20.04 host (>= 2 vCPU, 8 GB RAM)
- Docker and Docker Compose
- Vagrant and VirtualBox with VT-x/AMD-V enabled

## Architecture

- Docker Compose starts Jenkins and Nexus.
- Jenkins pipeline builds a WAR and uploads to a Nexus Maven hosted repo.
- Vagrant VM runs Tomcat 9; you download the WAR from Nexus and deploy it to Tomcat.

## Setup

1) Start Jenkins and Nexus

```bash
docker-compose build
docker-compose up -d
```

2) Configure Nexus

```bash
# Get initial admin password
docker exec $(docker ps --filter name=nexus_1 -q) cat /nexus-data/admin.password
```

- Login at `http://0.0.0.0:8081` as `admin` with the password above.
- Complete the wizard, set a new admin password, enable anonymous access.
- Create a Maven hosted repo:
  - **Name**: `maven-nexus-repo`
  - **Version policy**: Mixed
  - **Deployment policy**: Allow redeploy
- Create a user for Jenkins:
  - **ID**: `jenkins-user`
  - **Password**: set your own
  - **Roles**: `nx-admin`

3) Configure Jenkins

- Go to `http://0.0.0.0:8080` → **Manage Jenkins → Manage Credentials → System → Global** → **Add Credentials**:
  - Kind: Username with password
  - Username: `jenkins-user`
  - Password: your Nexus password
  - ID: `nexus`
- Create a pipeline job:
  - Definition: Pipeline script from SCM
  - SCM: Git
  - Repository URL: your fork (e.g., `https://github.com/<YOUR_USER>/devopsdaydayup.git`)
  - Credentials: your GitHub credential
  - Branch: `*/main`
  - Script Path: `006-NexusJenkinsVagrantCICD/Jenkinsfile`
  - Uncheck **Lightweight checkout**
- Install Maven under **Manage Jenkins → Global Tool Configuration**:
  - Name: `m3`
  - Install automatically: checked
  - Version: 3.8.6

4) Run the pipeline

- In the Jenkins job, click **Build Now**. The pipeline builds the WAR and uploads to `maven-nexus-repo`.
- Verify in Nexus (**Browse → maven-nexus-repo**) that the artifact exists.

5) Launch Tomcat VM with Vagrant

```bash
vagrant up
```

6) Deploy the WAR to Tomcat

```bash
vagrant ssh
cd /var/lib/tomcat9/webapps/
sudo wget http://<HOST_IP>:8081/repository/maven-nexus-repo/sparkjava-hello-world/sparkjava-hello-world/1.0/sparkjava-hello-world-1.0.war
```

Wait ~2 minutes for Tomcat to explode the WAR:
```bash
ls /var/lib/tomcat9/webapps
```

Access the app at:
```
http://0.0.0.0:8088/sparkjava-hello-world-1.0/hello
```

## Validation

- Jenkins pipeline succeeds.
- Nexus shows the WAR under `maven-nexus-repo`.
- Tomcat serves the app at the URL above.

## Cleanup

```bash
docker-compose down -v
vagrant destroy -f
```

## Troubleshooting

- **Maven build failures**: Adjust Maven version (e.g., 3.3.9) if dependency resolution fails.
- **WAR build errors**: Ensure `web.xml` and plugin versions are correct; see Spring WAR packaging notes.
- **VT-x disabled**: Enable virtualization in BIOS/UEFI for VirtualBox (VT-x/AMD-V).

## References

- https://maven.apache.org/guides/getting-started/maven-in-five-minutes
- https://www.fosstechnix.com/how-to-upload-artifact-to-nexus-using-jenkins/
- https://gist.github.com/wpscholar/a49594e2e2b918f4d0c4 (Vagrant cheat sheet)

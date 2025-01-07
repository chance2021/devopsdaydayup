# Continuous Integration (CI) Pipeline for Dockerized Java Application

This project demonstrates a **Continuous Integration (CI)** pipeline using **GitHub Actions** to build and push a Docker image for a Java application. The pipeline performs the following tasks:

1. **Build the Java application** using Maven.
2. **Build a Docker image** from the application.
3. **Tag the Docker image** with the current Git commit hash.
4. **Scan the Docker image** for security vulnerability.
5. **Push the Docker image** to **GitHub Container Registry (GHCR)**.

---

**Table of Contents**

- [Continuous Integration (CI) Pipeline for Dockerized Java Application](#continuous-integration-ci-pipeline-for-dockerized-java-application)
  - [Prerequisites](#prerequisites)
  - [Project Structure](#project-structure)
  - [Pipeline Workflow](#pipeline-workflow)
    - [Trigger Conditions](#trigger-conditions)
  - [Pipeline Steps](#pipeline-steps)
  - [Setup and Usage](#setup-and-usage)
    - [Step 1: Configure Secrets](#step-1-configure-secrets)
    - [Step 2: Define the Workflow](#step-2-define-the-workflow)
    - [Step 3: Add the Dockerfile](#step-3-add-the-dockerfile)
    - [Step 4: Push Changes to GitHub](#step-4-push-changes-to-github)
    - [Step 5: Verify the Pipeline](#step-5-verify-the-pipeline)
    - [Step 6: Validate the Output](#step-6-validate-the-output)
  - [Next Steps](#next-steps)

---

## Prerequisites

Before setting up the pipeline, ensure the following:

1. A **GitHub repository** containing:
   - A Java project with a `pom.xml`.
   - A `Dockerfile` in the folder `020-GithubActionJavaDockerfileCI`.

2. **GitHub Secrets**:
   - **`YOUR_GITHUB_TOKEN`**: A personal access token (PAT) with the required permissions to push images to **GitHub Container Registry (GHCR)**. Please ensure the token has **write:packages** and **read:packages** permissions for GitHub Container Registry.

3. **Docker CLI** (Optional): To verify the Docker image locally.

---

## Project Structure

The project should follow this structure:

```plaintext
devopsdaydayup/
├── .github/
│   └── workflows/
│       └── ci-docker-build.yml    # GitHub Actions CI workflow
├── 020-GithubActionJavaDockerfileCICD/
│   ├── Dockerfile                 # Dockerfile for the 
│   ├── src/                      # Java source files
│   └── pom.xml                   # Maven configuration 
```

## Pipeline Workflow

### Trigger Conditions

The pipeline triggers when:
- Changes are pushed to any branch.
- Files in the `020-GithubActionJavaDockerfileCI` folder are modified.
- The workflow can be manually dispatched as well.

## Pipeline Steps
1. Checkout Code: Fetch the latest code from the repository.
2. Set Up Docker: Configure Docker for building and pushing images.
3. Get Git Commit Hash: Dynamically tag the Docker image with the current Git commit hash.
4. Build Docker Image: Build the image from the Dockerfile.
5. Scan Docker Image: Scan the image for the security vulnerability.
6. Push Image to GHCR: Push the tagged Docker image to GitHub Container Registry.

## Setup and Usage

### Step 1: Configure Secrets
1. Go to your GitHub repository.
2. Navigate to Settings > Secrets and Variables > Actions.
3. Add the following secret:
- YOUR_GITHUB_TOKEN: A personal access token (PAT) with write:packages and read:packages permissions for GitHub Container Registry.
- To generate a PAT:
  - Go to your GitHub profile.
  - Navigate to Settings > Developer Settings > Personal Access Tokens.
  - Generate a new token with the necessary permissions and copy it.

### Step 2: Define the Workflow

Create a workflow file at `.github/workflows/ci-docker-build.yml` 

Note: You can copy this file from `020-GithubActionJavaDockerfileCI` folder to `.github/workflows` folder.

### Step 3: Add the Dockerfile

Ensure the Dockerfile `020-GithubActionJavaDockerfileCI` folder exists.

### Step 4: Push Changes to GitHub

Push the code to your repository:

```
git add .
git commit -m "Add CI pipeline for Docker build"
git push
```
Note: You have to make some change under `020-GithubActionJavaDockerfileCI` folder in order to trigger the GitHub action pipeline.

### Step 5: Verify the Pipeline
1.	Navigate to the Actions tab in your GitHub repository.
2.	Select the workflow CI Pipeline - Build and Push Docker Image.
3.	Monitor the pipeline’s execution and ensure all steps pass successfully.

### Step 6: Validate the Output
1. After the pipeline runs, the Docker image will be available in GitHub Container Registry:
```
ghcr.io/<repository_owner>/current-time-app:<commit-hash>
```

2. Verify the image locally:
```
docker pull ghcr.io/<repository_owner>/current-time-app:<commit-hash>
docker run --rm ghcr.io/<repository_owner>/current-time-app:<commit-hash>
```

## Next Steps
- Extend the pipeline to include a CD (Continuous Deployment) process.
- Deploy the built Docker image to a cloud platform, such as Azure Functions.
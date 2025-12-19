# Lab 18 — Azure DevOps CI/CD for Java Web App (WAR to Web App)

Build a Java web application with Maven and deploy the WAR to an Azure Web App for Linux using an Azure DevOps multi-stage pipeline (`java-cicd-v0.0.1.yaml`).

> Update service connection names, file paths, and pool details to match your Azure DevOps project before running. Do not check real secrets into source control.

## Prerequisites

- Azure subscription and an existing Web App for Linux (Tomcat) or permissions to create one
- Azure DevOps project with:
  - Service connection for Azure (`azureSubscription` in the pipeline)
  - Feed for Universal Packages (or adjust the publish/download tasks)
  - Agent pool (self-hosted or Microsoft-hosted). If you use Microsoft-hosted agents, replace the hardcoded JDK/Maven paths with setup tasks.
- Java 11 and Maven available on the build agent

## Pipeline Overview

- **Build stage**: packages the app with Maven, stages the WAR from `helloworld/target`, and publishes it as a Universal Package.
- **Deploy stage**: downloads the package from the feed and deploys it to the Azure Web App via `AzureWebApp@1`.

## Setup

1) Clone the repo and open the pipeline file:
```bash
git clone https://github.com/chance2021/devopsdaydayup.git
cd devopsdaydayup/018-AzureDevOpsJavaWebAppCICD
```

2) Edit `java-cicd-v0.0.1.yaml`:
- Set `pool.name` to your agent pool.
- Update `azureSubscription`, `resourceGroup`, and `appName` to match your Web App.
- Fix file paths if needed (e.g., `mavenPomFile: 'helloworld/pom.xml'` and `Dockerfile` paths if you add container packaging).
- Replace hardcoded JDK/Maven locations with `JavaToolInstaller@0` / `Maven@4` setup tasks if you are not using a custom agent image.
- Adjust feed names (`projectName`, `feedName`, `packageName`) or switch to `PublishBuildArtifacts@1` if you prefer pipeline artifacts.

3) Create/confirm an Azure Web App for Linux (Tomcat) that will host the WAR.

4) Commit the pipeline file to your Azure DevOps repo and create a pipeline pointing to `018-AzureDevOpsJavaWebAppCICD/java-cicd-v0.0.1.yaml` (triggers are disabled; run manually).

## Run the pipeline

Queue the pipeline manually. The build stage should produce a WAR and publish it. The deploy stage downloads the package and pushes it to the configured Web App.

## Validation

- Pipeline stages succeed in Azure DevOps.
- Azure Portal → Web App → Deployment Center shows the new deployment.
- Browse the Web App URL and verify the PrimeFaces Todo app loads.

## Cleanup

- Remove the pipeline and artifacts/feed entries if no longer needed.
- Delete the Web App/resource group to stop charges if this was a sandbox.

## Troubleshooting

- **JDK/Maven path errors**: Use installer tasks instead of hardcoded paths, or point to the correct tool locations on your agent.
- **Feed permissions**: Ensure the build and release stages can publish/download the Universal Package (scope the feed to the project or grant permissions).
- **Deployment fails**: Confirm the Web App type is Linux with Tomcat and `appName/resourceGroup` values match the deployed resource.

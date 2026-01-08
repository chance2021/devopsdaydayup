# DevOpsDaydayup Labs
Test

Hands-on labs that teach DevOps practices across CI/CD, IaC, Kubernetes, observability, and cloud platforms. Every lab is runnable end-to-end with clearly marked prerequisites, placeholders for secrets, validation steps, cleanup, and troubleshooting tips.

- Topics: Docker, Kubernetes, Helm, Terraform, Vault, Jenkins, GitLab, GitHub Actions, Azure, monitoring/observability, and more.
- Contributions welcome—see [CONTRIBUTING.md](CONTRIBUTING.md) and follow the lab template for consistency.
- Security first—no real secrets. Use placeholders like `YOUR_GITHUB_TOKEN` and see [SECURITY.md](SECURITY.md).

## How to Use These Labs (Learn First, Then Compare)

- Pick a single lab that matches your interest and read its goal first.
- Try to complete the lab on your own before running any provided automation scripts—this is where the learning happens.
- If you get stuck, consult the lab README or peek at the automation (Jenkinsfiles, GitHub Actions, Terraform, shell scripts) to spot what you missed.
- After finishing, compare your approach with the provided scripts/manifests to see differences and alternatives.
- Automation is there to verify and repeat quickly, but rely on it only after you’ve attempted the lab yourself.
- Questions or feedback? Connect on LinkedIn: https://www.linkedin.com/in/chance-chen/ (feel free to add and discuss).

## Getting Started

1. Clone the repo: `git clone https://github.com/chance2021/devopsdaydayup.git`
2. Pick a lab folder (e.g., `024-ArgoCICD`) and read its `README.md`.
3. Export secrets as environment variables or store them in a secret manager. Never commit real credentials.
4. Run the lab steps in order, verify using the provided validation checks, then perform cleanup.

## Lab Catalog

| # | Lab | Path |
| --- | --- | --- |
| 1 | Deploy ELK to monitor a VM | 001-ELKMonitoring |
| 2 | Jenkins CI/CD pipeline | 002-JenkinsCICD |
| 3 | GitLab CI/CD pipeline | 003-GitlabCICD |
| 4 | Deploy a Docker container with Terraform | 004-TerraformDockerDeployment |
| 5 | Jenkins CI/CD pulling secrets from Vault | 005-VaultJenkinsCICD |
| 6 | Jenkins CI/CD deploying Java from Nexus | 006-NexusJenkinsVagrantCICD |
| 7 | Vault authentication with FreeIPA | 007-VaultFreeIPAVagrantIAM |
| 8 | Jenkins via Ansible role | 008-AnsibleVagrantJenkinsDeployment |
| 9 | Helm chart deployment on Minikube | 009-MinikubeHelmDeployment |
| 10 | Prometheus/Grafana on Minikube | 010-MinikubeGrafanaPrometheusMultipassMonitoring |
| 11 | Read-only kubeconfig creation | 011-KinDKubeconfigRBACConfiguration |
| 12 | CronJob backup for Vault | 012-CronjobVaultBackupHelmMinikube |
| 13 | Java app on Kubernetes with ConfigMap reload | 013-JavaMonitoryConfigmapMinikube |
| 14 | Vault sidecar injector | 014-VaultInjectorMinikube |
| 15 | Remove large files from Git history | 015-GitRemoveLargeFile |
| 16 | Azure Function deployment with Terraform | 016-AzureFunctionTerraform |
| 17 | Azure Key Vault integration | 017-AzureLogicalAppTerraform |
| 18 | Azure DevOps Java web app CI/CD | 018-AzureDevOpsJavaWebAppCICD |
| 19 | Terraform + Azure DevOps workflow | 019-TerraformAzureDevOpsWorkflow |
| 20 | Dockerized Java app CI on GitHub Actions | 020-GithubActionJavaDockerfileCI |
| 21 | Deploy Docker image to Azure Function via GitHub Actions | 021-GithubActionDockerImageFunctionCD |
| 22 | Actions Runner Scale Set (ARC) on Minikube | 022-ActionRunnerSaleSetMinitkube |
| 23 | Secure CI with GitHub Actions, Vault, Artifactory, SonarQube | 023-SecureCIGitHubActionVaultArtifactorySonarQube |
| 24 | Argo Events → Workflows → Argo CD → Rollouts | 024-ArgoCICD |

Additional topics:
- AKS: `aks/aks-upgrade`, `aks/backup-solution-velero`
- Keycloak: `keycloak-integration`
- Helm on Oracle Cloud: `HelmOracleCloudK8s`
- Terraform on Oracle Cloud: `TerraformOracleCloudVM`
- Learning notes and scripts: `python/`, `linux/`, `cloud/`, `docs/`

## Lab Template

Use `README.md.template` as a starting point and include: Title, Overview, Prerequisites, Architecture/Diagram (when helpful), Setup, Steps, Validation, Cleanup, Troubleshooting, References. Keep instructions copy-pasteable and note tested versions.

## Contributing & Support

- Contributions are welcome—see [CONTRIBUTING.md](CONTRIBUTING.md).
- Code of Conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- Security reports: [SECURITY.md](SECURITY.md)
- License: [LICENSE](LICENSE)

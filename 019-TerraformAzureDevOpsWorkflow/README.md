# Lab 19 — Azure DevOps Workflow for Terraform Workspaces

Use a parameterized Azure DevOps pipeline to detect which Terraform workspaces changed and run per-environment stages automatically.

Pipeline file: `019-TerraformAzureDevOpsWorkflow/azuredevops-pipeline.yaml`

## Prerequisites

- Azure DevOps project with an agent pool (self-hosted or Microsoft-hosted)
- Git repository containing your Terraform workspaces (e.g., `dev/dev01/cc`) and shared modules
- Terraform installed on the build agent (adjust `tf_version` variable if you add an installer task)

## How the pipeline works

- `parameters.listWorkspaces` defines environments and the paths to watch.
- `setWorkspaceStage` compares the current branch with `origin/master` (or the previous commit on master) and sets `isChange=true` when files under a workspace path or its module path changed.
- A Terraform plan stage is generated for each environment/location pair and only runs when `isChange=true`.
- The sample plan job currently echoes a placeholder command; replace it with real `terraform init/plan` steps.

## Setup

1) Clone the repo and open the pipeline file:
```bash
git clone https://github.com/chance2021/devopsdaydayup.git
cd devopsdaydayup/019-TerraformAzureDevOpsWorkflow
```

2) Customize `azuredevops-pipeline.yaml`:
- Update `parameters.listWorkspaces` to match your directory layout and module paths.
- Set `pool_name` to your agent pool.
- Add Terraform init/plan/apply commands in `terraform_plan_job_*` (and optionally a gated apply stage).
- If you use remote state or Azure storage backends, inject the service connection/credentials as variables or variable groups.

3) Commit the pipeline file to your Azure DevOps repo and create a pipeline referencing it (triggers are enabled for all branches and the listed paths; adjust as needed).

## Validation

- Push a change under a watched workspace path; only the related plan stage should run.
- A change outside those paths should skip the per-environment plan stages.

## Cleanup

- Delete the pipeline run and any temporary state files/artifacts if you added them.
- Remove the pipeline from Azure DevOps when finished.

## Troubleshooting

- **No stages run**: Ensure the branch comparison targets the correct default branch (`origin/master` vs `origin/main`) and that `paths.include` matches your repo layout.
- **Agent not found**: Update `pool_name` to a pool available in your project.
- **Terraform authentication issues**: Configure backend credentials/service connections and avoid hardcoding secrets in the YAML.

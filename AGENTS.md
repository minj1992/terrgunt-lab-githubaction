# Repository Guidelines

## Project Structure & Module Organization
This is a **Terragrunt** project that manages AWS infrastructure. The structure follows a standard multi-environment layout:
- **`infrastructure/`**: Contains environment-specific configurations (`dev/`, etc.) and the root `terragrunt.hcl`.
- **`infrastructure/modules/`**: Contains reusable Terraform modules.
- **`infrastructure/terragrunt.hcl`**: Global configuration for backend and provider generation.
- **`env.hcl`**: Environment-specific variables (e.g., `region`, `environment`).

### Configuration Flow
1. **Child `terragrunt.hcl`**: Located in a resource directory (e.g., `infrastructure/dev/ec2/`), it includes the root config and defines `source` and `inputs`.
2. **Root `terragrunt.hcl`**: Generates `backend.tf` and `provider.tf` on-the-fly.
3. **Variable Injection**: Terragrunt maps `inputs` blocks to `TF_VAR_` environment variables for Terraform modules.

## Build, Test, and Development Commands
Use **Terragrunt** to manage the infrastructure:
- **Initialize**: `terragrunt init`
- **Plan**: `terragrunt plan`
- **Apply**: `terragrunt apply`
- **Destroy**: `terragrunt destroy`
- **Run in environment**: `cd infrastructure/dev/ec2 && terragrunt plan`

### CI/CD
The **GitHub Actions** workflow (`deploy.yml`) handles deployments via `workflow_dispatch`. It requires `aws_access_key_id`, `aws_secret_access_key`, `environment`, `region`, and `command`.

## Coding Style & Naming Conventions
- **HCL**: Follow standard Terraform/Terragrunt HCL formatting.
- **Auto-generated files**: Do **not** manually edit `backend.tf` or `provider.tf`; they are managed by Terragrunt's `generate` blocks.
- **State Key**: Automatically follows the directory structure using `path_relative_to_include()`.

## Commit & Pull Request Guidelines
- Follow the simple "first commit" style for now, but aim for descriptive messages as the project grows.
- Ensure all infrastructure changes are planned and reviewed via `terragrunt plan`.

# Terragrunt Deployment & Variable Injection Flow

This document explains how values flow from **GitHub Actions** through **Terragrunt** and finally into **Terraform Modules**.

---

## 1. Sequential Deployment Flow (Text-Based Diagram)

```text
[ USER TRIGGER ]
      |
      v
[ GITHUB ACTIONS WORKFLOW ] (deploy.yml)
      |-- Inputs: AWS_ACCESS_KEY, AWS_SECRET, ENVIRONMENT, REGION
      |-- env: AWS_DEFAULT_REGION = input.region
      |
      v
[ STEP: Terragrunt Init/Plan/Apply ] (Executed in: infrastructure/dev/ec2/)
      |
      |-- 1. LOAD: infrastructure/dev/ec2/terragrunt.hcl (The "Child" config)
      |      |
      |      |-- 2. CALL: find_in_parent_folders() -> finds infrastructure/terragrunt.hcl (The "Root" config)
      |      |-- 3. CALL: read_terragrunt_config("env.hcl") -> loads environment-specific locals
      |      |
      v      v
[ ROOT terragrunt.hcl PROCESSES ]
      |-- 4. GENERATE: backend.tf (S3 & DynamoDB with dynamic names)
      |-- 5. GENERATE: provider.tf (AWS provider with region from env.hcl)
      |-- 6. MERGE: All 'inputs' from Root + Child + env.hcl
      |
      v
[ TERRAFORM EXECUTION ]
      |-- 7. INJECT: Terragrunt sets environment variables: TF_VAR_instance_name, TF_VAR_ami_id, etc.
      |-- 8. RUN: terraform init / plan / apply
      |
      v
[ AWS INFRASTRUCTURE ]
      |-- 9. CREATE: EC2 Instance with tags and properties
```

---

## 2. Detailed Step-by-Step Breakdown

### Step 1: GitHub Actions Input (The Starting Point)
When you trigger the workflow, you provide:
- **AWS Credentials**: Passed as secrets or direct inputs.
- **Environment**: This determines which directory Terragrunt runs in (e.g., `infrastructure/dev/ec2`).
- **Region**: Overrides the default region for the AWS provider.

### Step 2: Directory Context
Terragrunt command is run inside the specific resource directory:
`cd infrastructure/dev/ec2 && terragrunt plan`
This is critical because Terragrunt looks for a `terragrunt.hcl` in the **current working directory**.

### Step 3: Loading Configurations
1.  **Child `terragrunt.hcl`**: This file defines the `source` (where the Terraform code is) and its own `locals` and `inputs`.
2.  **Parent `terragrunt.hcl`**: Loaded via `include`. This file contains the "Global" logic like S3 backend creation and provider generation.
3.  **`env.hcl`**: Loaded via `read_terragrunt_config`. It provides environment-specific context (like `environment = "dev"`).

### Step 4: Variable Injection ("The Magic")
Terragrunt collects everything in the `inputs = { ... }` blocks and passes them to Terraform as **Environment Variables**.
- If you have `inputs = { instance_type = "t3.micro" }`, Terragrunt runs Terraform with `TF_VAR_instance_type="t3.micro"`.
- This is how your Terraform module's `variable "instance_type" {}` gets its value without using a `.tfvars` file.

### Step 5: Backend & Provider Generation
The `generate` blocks in the root `terragrunt.hcl` create actual `.tf` files on the fly:
- **`backend.tf`**: Automatically configures S3/DynamoDB for state locking.
- **`provider.tf`**: Configures the AWS provider with the region fetched from `env.hcl`.

---

## 3. GitHub Actions Configuration Options

### Option A: Manual Inputs (Current Setup)
Use `workflow_dispatch` to manually select the environment and region.
```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: "Select Environment"
        required: true
        type: choice
        options: ["dev", "prod"]
      region:
        description: "Select Region"
        default: "us-east-1"
```

### Option B: GitHub Environments (Recommended for Production)
You can link secrets and variables to specific GitHub Environments (`dev`, `prod`).
1.  In GitHub Repo Settings -> Environments -> Create "dev".
2.  Add `AWS_ACCESS_KEY_ID` as a secret inside the "dev" environment.
3.  In your YAML:
    ```yaml
    jobs:
      deploy:
        environment: ${{ github.event.inputs.environment }}
    ```

---

## 4. Key Functions Summary
- `find_in_parent_folders()`: Recursively looks up the directory tree for a file (usually the root `terragrunt.hcl`).
- `read_terragrunt_config()`: Imports variables from another `.hcl` file so you can reuse them.
- `get_aws_account_id()`: Used in the root config to make the S3 bucket name globally unique.
- `path_relative_to_include()`: Ensures that if you are in `dev/ec2`, your S3 state key is also `dev/ec2/terraform.tfstate`.

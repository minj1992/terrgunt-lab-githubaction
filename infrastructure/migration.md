# Terragrunt to Terraform Migration Guide

This document outlines the process of migrating from a Terragrunt-managed infrastructure to standard Terraform.

## 1. Migration Overview

Terragrunt is a thin wrapper that provides extra tools for keeping your configurations DRY (Don't Repeat Yourself). Standard Terraform requires these configurations to be explicit in each module or environment.

### Key Changes
- **Provider & Backend**: Replace Terragrunt `generate` blocks with explicit `provider.tf` and `backend.tf` files.
- **Remote State**: Replace Terragrunt `remote_state` with a standard Terraform `backend` block.
- **Inputs**: Replace Terragrunt `inputs` with `variables.tf` and `terraform.tfvars`.
- **DRY Logic**: Replace `read_terragrunt_config` and `find_in_parent_folders` with local variables or workspace-based configurations.

## 2. Workflow Comparison

### Terragrunt Workflow
```text
[ terragrunt.hcl ] 
       |
       |--- (Includes) ---> [ Root terragrunt.hcl ]
       |                          |
       |                   (Generates files)
       |                          |
       |                   [ provider.tf ]
       |                   [ backend.tf  ]
       |
       |--- (Passes Inputs) ---> [ Terraform Module ]
                                        |
                                 (Executes plan/apply)
                                        |
                                [ AWS Infrastructure ]
```

### Standard Terraform Workflow
```text
[ main.tf ] <----------- [ Module Sources ]
    |
    |--- (References) -> [ variables.tf ]
    |
    |--- (Configures) -> [ backend.tf   ]
    |
    |--- (Values from) -> [ terraform.tfvars ]
    |
    |--- (Executes) ----> [ AWS Infrastructure ]
```

## 3. Full File Side-by-Side Comparison

### Root Configuration Comparison

| Terragrunt (`infrastructure/terragrunt.hcl`) | Standard Terraform Equivalent |
| :--- | :--- |
| ```hcl
locals {
  # Automatically load environment variables 
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Common variables
  aws_region = get_env("TG_REGION", local.env_vars.locals.region)
  project    = "simple-ec2-project"
  owner      = "devops-team"
}

# The generate block creates a provider.tf file
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
}
EOF
}

# The remote_state block configures the S3 backend
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "${local.project}-terraform-state-${get_aws_account_id()}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = "${local.project}-lock-table"
  }
}

# Global inputs passed to all modules
inputs = merge(
  {
    aws_region = local.aws_region
    tags = {
      Project = local.project
      Owner   = local.owner
    }
  },
  local.env_vars.locals
)
``` | ```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "simple-ec2-project-terraform-state-123456789012"
    key            = "dev/ec2/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "simple-ec2-project-lock-table"
  }
}

# provider.tf
provider "aws" {
  region = "us-east-1"
}

# variables.tf (Global Variables)
variable "aws_region" {
  default = "us-east-1"
}

variable "tags" {
  type = map(string)
  default = {
    Project = "simple-ec2-project"
    Owner   = "devops-team"
    Environment = "dev"
    Department  = "it-operations"
  }
}
``` |

### Environment Module Comparison (EC2)

| Terragrunt (`infrastructure/dev/ec2/terragrunt.hcl`) | Standard Terraform (`infrastructure/dev/ec2/main.tf`) |
| :--- | :--- |
| ```hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/ec2"
}

locals {
  # Load environment-specific variables
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  instance_name = "web-server-${local.env_vars.locals.environment}"
  instance_type = "t3.micro"
  ami_id        = "ami-0c55b159cbfafe1f0" 
}

inputs = {
  instance_name = local.instance_name
  instance_type = local.instance_type
  ami_id        = local.ami_id
}
``` | ```hcl
module "ec2" {
  source = "../../modules/ec2"

  instance_name = var.instance_name
  instance_type = var.instance_type
  ami_id        = var.ami_id
  
  # Inherited from global variables
  aws_region    = var.aws_region
  tags          = var.tags
}

# variables.tf
variable "instance_name" { type = string }
variable "instance_type" { type = string }
variable "ami_id"        { type = string }
variable "aws_region"    { type = string }
variable "tags"          { type = map(string) }

# terraform.tfvars
instance_name = "web-server-dev"
instance_type = "t3.micro"
ami_id        = "ami-0c55b159cbfafe1f0"
``` |

### 3.1 Variable Mapping Flow

#### Terragrunt Mapping
In Terragrunt, values defined in the `inputs` block are automatically passed as environment variables (`TF_VAR_...`) to the underlying Terraform module.

```text
[ terragrunt.hcl ]                 [ Terraform Module ]
inputs = {                         variable "instance_name" { ... }
  instance_name = "web-server"  =>  (Automatically matched by name)
}                                  }
```

#### Standard Terraform Mapping
In standard Terraform, the mapping is explicit and follows a three-step chain.

```text
1. [ terraform.tfvars ]            2. [ variables.tf ]            3. [ main.tf ]
instance_name = "web-server"  =>   variable "instance_name" {} =>  module "ec2" {
                                                                     instance_name = var.instance_name
                                                                   }
```

### 3.2 Verifying with Terraform Console
You can verify these mappings by running `terraform console` in your environment directory:

```bash
# To see the value of a variable
> var.instance_name
"web-server-dev"

# To see all variables
> var
{
  "ami_id" = "ami-0c55b159cbfafe1f0"
  "instance_name" = "web-server-dev"
  "instance_type" = "t3.micro"
  ...
}
```

## 4. Migration Steps

1.  **Extract Providers**: Create a `provider.tf` in each environment directory using the configuration from the root `terragrunt.hcl`.
2.  **Define Backends**: Create a `backend.tf` in each environment, explicitly defining the S3 bucket and key (which was previously handled by `${path_relative_to_include()}`).
3.  **Convert Inputs to Variables**: For each `inputs` block in `terragrunt.hcl`, create a corresponding `variable` in `variables.tf` and a value in `terraform.tfvars`.
4.  **Replace Source**: Call the modules directly using `module` blocks in a `main.tf` file instead of the `terraform { source = "..." }` block.
5.  **State Migration**: If the infrastructure is already deployed, you may need to run `terraform init -migrate-state` to ensure Terraform recognizes the existing state in S3.

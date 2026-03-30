locals {
  # Automatically load environment variables from env.hcl
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Common variables
  aws_region = local.env_vars.locals.region
  project    = "simple-ec2-project"
  owner      = "devops-team"
}

# The generate block creates a provider.tf file in each module
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
# Terragrunt automatically creates the S3 bucket and DynamoDB table if they don't exist
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

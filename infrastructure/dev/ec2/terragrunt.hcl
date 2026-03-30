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

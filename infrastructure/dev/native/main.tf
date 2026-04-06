provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    # These must be provided via -backend-config or initialized manually
  }
}

variable "aws_region" {
  default = "us-east-1"
}

variable "aws_account_id" {
  description = "AWS Account ID for the S3 bucket"
}

module "ec2" {
  source = "../../modules/ec2"

  instance_name = "web-server-dev"
  instance_type = "t3.micro"
  ami_id        = "ami-0ec10929233384c7f"
}

# This moved block tells Terraform that the existing instance
# in the state (aws_instance.example) now lives inside the module.
# This avoids destroying and recreating the resource.
moved {
  from = aws_instance.example
  to   = module.ec2.aws_instance.example
}

# Match existing outputs in the root module
output "instance_id" {
  value = module.ec2.instance_id
}

output "public_ip" {
  value = module.ec2.public_ip
}

provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    # These must be provided via -backend-config or initialized manually
    # bucket         = "simple-ec2-project-terraform-state-<ACCOUNT_ID>"
    # key            = "dev/ec2/terraform.tfstate"
    # region         = "us-east-1"
    # encrypt        = true
    # dynamodb_table = "simple-ec2-project-lock-table"
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

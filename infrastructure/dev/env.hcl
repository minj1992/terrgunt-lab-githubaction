locals {
  environment = "dev"
  region      = "us-east-1"
  # Common tags for all resources in this environment
  env_tags = {
    Environment = "dev"
    Department  = "it-operations"
  }
}

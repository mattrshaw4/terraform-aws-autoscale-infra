# terraform.tfvars
#
# Explicit values for this deployment.
# All variables have defaults — this file makes the intent
# visible and version-controlled. No guessing what was deployed.

project_name = "autoscale-infra"
environment  = "dev"
aws_region   = "us-east-1"

vpc_cidr = "10.0.0.0/16"

public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
availability_zones  = ["us-east-1a", "us-east-1b"]

# providers.tf

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "autoscale-infra-tfstate-859493431963"
    key          = "autoscale-infra/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project    = "autoscale-infra"
      ManagedBy  = "terraform"
      Repository = "github.com/mattrshaw4/terraform-aws-autoscale-infra"
    }
  }
}

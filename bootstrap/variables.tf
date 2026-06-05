# bootstrap/variables.tf

variable "project_name" {
  description = "Short project identifier — used to build the S3 bucket name"
  type        = string
  default     = "autoscale-infra"
}

variable "environment" {
  description = "Deployment environment — used in resource tags"
  type        = string
  default     = "bootstrap"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

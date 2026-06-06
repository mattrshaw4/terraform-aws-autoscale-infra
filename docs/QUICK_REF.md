# terraform-aws-autoscale-infra Quick Reference

## Common Commands
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
terraform destroy -var-file="terraform.tfvars"

## Project Structure
- main.tf         - Core autoscaling resources
- security_groups.tf - SG rules
- variables.tf    - Input variable declarations
- outputs.tf      - Output values
- locals.tf       - Local value expressions
- providers.tf    - AWS provider config
- terraform.tfvars - Variable values (not committed)
- bootstrap/      - S3 backend bootstrap

## Conventions
- Region: us-east-1
- State backend: S3
- Resource tagging: Project=autoscale-infra, Owner=matt
- Never hardcode AMI IDs - use data "aws_ami" source block
- AL2023 uses dnf not yum, curl not wget

## Key AWS Resources
- [Add your ASG name here]
- [Add your Launch Template name here]
- [Add your ALB name here]

# outputs.tf
#
# These values get stored in remote state after apply.
# Later phases reference them directly — no hardcoding IDs.

output "vpc_id" {
  description = "VPC ID — referenced by security groups, ALB, and ASG in later phases"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of public subnet IDs — used by ALB and ASG in later phases"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  value       = aws_subnet.public[*].cidr_block
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "availability_zones" {
  description = "Availability zones in use"
  value       = aws_subnet.public[*].availability_zone
}

output "alb_security_group_id" {
  description = "ALB security group ID — referenced by the load balancer in Phase 5"
  value       = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  description = "EC2 security group ID — referenced by the launch template in Phase 4"
  value       = aws_security_group.ec2.id
}



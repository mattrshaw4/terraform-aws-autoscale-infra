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

output "launch_template_id" {
  description = "Launch template ID"
  value       = aws_launch_template.main.id
}

output "autoscaling_group_name" {
  description = "ASG name — used for CloudWatch alarms in Phase 6"
  value       = aws_autoscaling_group.main.name
}

output "ami_id" {
  description = "Amazon Linux 2023 AMI ID resolved at plan time"
  value       = data.aws_ami.al2023.id
}

output "alb_dns_name" {
  description = "ALB DNS name — open this in your browser after apply"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ALB ARN — referenced by CloudWatch alarms in Phase 6"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "Target group ARN — referenced by CloudWatch alarms in Phase 6"
  value       = aws_lb_target_group.main.arn
}

output "cloudwatch_cpu_high_alarm" {
  description = "High CPU alarm name — fires scale-out above 70% for 4 minutes"
  value       = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}

output "cloudwatch_cpu_low_alarm" {
  description = "Low CPU alarm name — fires scale-in below 20% for 4 minutes"
  value       = aws_cloudwatch_metric_alarm.cpu_low.alarm_name
}



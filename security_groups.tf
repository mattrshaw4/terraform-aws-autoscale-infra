# security_groups.tf
#
# Two security groups. Two very different jobs.
# This layered model means EC2 instances are never exposed
# directly to the internet - all traffic flows through the ALB.

# ─────────────────────────────────────────
# ALB SECURITY GROUP
# ─────────────────────────────────────────

# The ALB faces the internet. It accepts HTTP and HTTPS
# from anywhere. This is intentional - it's the front door.
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer - public internet traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound - ALB forwards to EC2 instances"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

# ─────────────────────────────────────────
# EC2 SECURITY GROUP
# ─────────────────────────────────────────

# EC2 instances accept traffic on port 80 from the ALB
# security group only - not from the internet directly.
#
# This is the key line: security_groups = [aws_security_group.alb.id]
# It references the ALB's security group as the source, not a CIDR.
# Even if someone discovers an instance's public IP, they can't
# reach it - the SG rule rejects anything not coming from the ALB.
resource "aws_security_group" "ec2" {
  name        = "${local.name_prefix}-ec2-sg"
  description = "Security group for EC2 instances - ALB traffic only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB only - no direct internet access"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All outbound - for package updates and AWS API calls"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2-sg"
  })
}

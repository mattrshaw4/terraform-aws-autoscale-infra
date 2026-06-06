# iam.tf
#
# IAM role and instance profile for EC2 instances.
# Grants SSM Session Manager access — no SSH keys, no open port 22,
# no bastion host. This is the modern, secure way to access instances.

# ─────────────────────────────────────────
# IAM ROLE
# ─────────────────────────────────────────

# The trust policy defines WHO can assume this role.
# ec2.amazonaws.com means EC2 instances can assume it — not users,
# not Lambda, not anything else.
resource "aws_iam_role" "ec2_ssm" {
  name        = "${local.name_prefix}-ec2-ssm-role"
  description = "Allows EC2 instances to use SSM Session Manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# ─────────────────────────────────────────
# POLICY ATTACHMENT
# ─────────────────────────────────────────

# AmazonSSMManagedInstanceCore is an AWS managed policy.
# It grants the minimum permissions needed for SSM to function:
# - Receive and run commands from SSM
# - Send output back to CloudWatch and S3
# - Register the instance with Systems Manager
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ─────────────────────────────────────────
# INSTANCE PROFILE
# ─────────────────────────────────────────

# An instance profile is the container that holds an IAM role
# and passes it to an EC2 instance at launch.
# You can't attach an IAM role directly to EC2 — it must go
# through an instance profile. The launch template references this.
resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${local.name_prefix}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name

  tags = local.common_tags
}

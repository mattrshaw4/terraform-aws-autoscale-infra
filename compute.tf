# compute.tf

# ─────────────────────────────────────────
# AMI DATA SOURCE
# ─────────────────────────────────────────

# Never hardcode an AMI ID. They change per region and go stale.
# This data source looks up the latest Amazon Linux 2023 AMI
# at plan time — always current, always the right region.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ─────────────────────────────────────────
# LAUNCH TEMPLATE
# ─────────────────────────────────────────

# A launch template is the blueprint for every instance the ASG creates.
# Change it here and the ASG picks it up on the next scale-out event.
resource "aws_launch_template" "main" {
  name        = "${local.name_prefix}-lt"
  description = "Launch template for autoscale-infra ASG"

  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  # Attach the IAM instance profile — gives instances SSM access
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm.name
  }

  # Attach the EC2 security group from Phase 3
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2.id]
    delete_on_termination       = true
  }

  # IMDSv2 required — prevents SSRF attacks against the metadata service.
  # http_tokens = "required" forces all metadata requests to use a session token.
  # This is an AWS security best practice and CIS benchmark requirement.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # user_data runs once when the instance first boots.
  # base64encode() is required — EC2 expects base64-encoded user data.
  # AL2023 lessons applied here:
  #   - dnf not yum
  #   - curl not wget
  #   - log to /var/log/user-data.log
  #   - printf not heredoc (avoids nested heredoc issues in Terraform)
  #   - IMDSv2 two-step token fetch for metadata
  user_data = base64encode(<<-EOF
#!/bin/bash
exec > /var/log/user-data.log 2>&1

dnf update -y
dnf install -y httpd

# IMDSv2 — step 1: get session token
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# IMDSv2 — step 2: use token to fetch metadata
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Build HTML page — printf avoids nested heredoc issues
printf '<!DOCTYPE html>\n<html>\n<head><title>autoscale-infra</title></head>\n<body>\n' \
  > /var/www/html/index.html
printf '<h1>autoscale-infra is running</h1>\n' >> /var/www/html/index.html
printf '<p><strong>Instance ID:</strong> %s</p>\n' "$INSTANCE_ID" \
  >> /var/www/html/index.html
printf '<p><strong>Availability Zone:</strong> %s</p>\n' "$AZ" \
  >> /var/www/html/index.html
printf '<p><em>Served by auto-scaling infrastructure provisioned with Terraform</em></p>\n' \
  >> /var/www/html/index.html
printf '</body>\n</html>\n' >> /var/www/html/index.html

systemctl start httpd
systemctl enable httpd
EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-instance"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-volume"
    })
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-lt"
  })
}

# ─────────────────────────────────────────
# AUTO SCALING GROUP
# ─────────────────────────────────────────

# The ASG manages the fleet. It keeps the desired number of instances
# running, replaces unhealthy ones automatically, and scales in/out
# based on policies we add in Phase 6.
resource "aws_autoscaling_group" "main" {
  name = "${local.name_prefix}-asg"

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  # Spread instances across both public subnets — multi-AZ coverage
  vpc_zone_identifier = aws_subnet.public[*].id

  # EC2 health check for now — Phase 5 upgrades this to ELB
  # once the load balancer is attached
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  # Propagate tags to every instance the ASG launches
  dynamic "tag" {
    for_each = merge(local.common_tags, {
      Name = "${local.name_prefix}-instance"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

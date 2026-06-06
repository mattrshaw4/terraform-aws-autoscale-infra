# alb.tf

# ─────────────────────────────────────────
# APPLICATION LOAD BALANCER
# ─────────────────────────────────────────

# The ALB is the single entry point for all traffic.
# It sits in both public subnets — if one AZ goes down,
# the ALB continues serving from the other.
resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false
  drop_invalid_header_fields = true # Prevents HTTP desync attacks

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

# ─────────────────────────────────────────
# TARGET GROUP
# ─────────────────────────────────────────

# The target group is the list of instances receiving traffic.
# The ALB routes requests here. The health check defines what
# "healthy" means — if an instance fails it, the ALB stops
# sending it traffic until it recovers.
resource "aws_lb_target_group" "main" {
  name        = "${local.name_prefix}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2  # 2 consecutive passes = healthy
    unhealthy_threshold = 3  # 3 consecutive fails = unhealthy
    interval            = 30 # Check every 30 seconds
    timeout             = 5  # Wait 5 seconds for a response
    matcher             = "200"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tg"
  })
}

# ─────────────────────────────────────────
# LISTENER
# ─────────────────────────────────────────

# The listener watches port 80 on the ALB and forwards
# all matching traffic to the target group.
# One listener per port — add port 443 here in future
# when you add an SSL certificate.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-listener-http"
  })
}

# ─────────────────────────────────────────
# ASG ATTACHMENT
# ─────────────────────────────────────────

# Connects the ASG to the target group.
# Every instance the ASG launches is automatically registered
# here. Every instance it terminates is automatically deregistered.
# No manual intervention — the fleet manages itself.
resource "aws_autoscaling_attachment" "main" {
  autoscaling_group_name = aws_autoscaling_group.main.id
  lb_target_group_arn    = aws_lb_target_group.main.arn
}

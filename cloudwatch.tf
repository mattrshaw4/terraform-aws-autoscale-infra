# cloudwatch.tf
#
# Two alarms, two scaling policies.
# The infrastructure grows under load and shrinks when idle.
# Every idle instance you don't run is money you don't spend.

# ─────────────────────────────────────────
# SCALING POLICIES
# ─────────────────────────────────────────

# Each policy defines WHAT to do when an alarm fires.
# The alarm defines WHEN to do it.
# They are linked by the alarm_actions attribute below.

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${local.name_prefix}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.main.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1   # Add 1 instance per trigger
  cooldown               = 300 # Wait 5 minutes before scaling again
  # Cooldown prevents thrashing — if CPU spikes repeatedly,
  # the ASG waits 300s before evaluating another scale-out event
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${local.name_prefix}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.main.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1 # Remove 1 instance per trigger
  cooldown               = 300
  # ASG min_size = 1 acts as the floor — scale-in never goes below 1
}

# ─────────────────────────────────────────
# CLOUDWATCH ALARMS
# ─────────────────────────────────────────

# period (120s) x evaluation_periods (2) = 4 minutes of sustained load
# before any action fires. Prevents reacting to momentary spikes.

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name_prefix}-cpu-high"
  alarm_description   = "Scale out: avg CPU above 70% for 4 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  treat_missing_data  = "notBreaching" # Missing data never triggers scale-out

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cpu-high-alarm"
  })
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${local.name_prefix}-cpu-low"
  alarm_description   = "Scale in: avg CPU below 20% for 4 minutes"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 20
  treat_missing_data  = "notBreaching" # Missing data never triggers scale-in

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.main.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cpu-low-alarm"
  })
}

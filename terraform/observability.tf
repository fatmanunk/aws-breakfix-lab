resource "aws_sns_topic" "alerts" {
  name = "breakfix-alerts"
  tags = { Name = "breakfix-alerts" }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = "qhorton33@gmail.com"
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "breakfix-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Fires when any ALB target is unhealthy"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.app.arn_suffix
    LoadBalancer = aws_lb.app.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "breakfix-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Fires when ALB returns excessive 5xx errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count               = 2
  alarm_name          = "breakfix-high-cpu-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Fires when instance CPU exceeds 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = aws_instance.app[count.index].id
  }
}

# Reuse the existing breakfix-alerts SNS topic (already confirmed to email)
data "aws_sns_topic" "alerts" {
  name = "breakfix-alerts"
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count               = length(aws_instance.app)
  alarm_name          = "breakfix-cpu-high-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Incident 07 detector: CPU over 80% for 10 min"
  dimensions          = { InstanceId = aws_instance.app[count.index].id }
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
  ok_actions          = [data.aws_sns_topic.alerts.arn]
  tags                = { Incident = "07-cpu-saturation" }
}

resource "aws_cloudwatch_metric_alarm" "status_check" {
  count               = length(aws_instance.app)
  alarm_name          = "breakfix-statuscheck-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Incident 01 detector: instance status check failing"
  dimensions          = { InstanceId = aws_instance.app[count.index].id }
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
  tags                = { Incident = "01-ssh-ssm-unreachable" }
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
  alarm_description   = "Incident 03 detector: ALB returning 5XX"
  dimensions          = { LoadBalancer = aws_lb.app.arn_suffix }
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"
  tags                = { Incident = "03-alb-5xx" }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  alarm_name          = "breakfix-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Incident 03 detector: unhealthy targets behind ALB"
  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }
  alarm_actions      = [data.aws_sns_topic.alerts.arn]
  treat_missing_data = "notBreaching"
  tags               = { Incident = "03-unhealthy-targets" }
}

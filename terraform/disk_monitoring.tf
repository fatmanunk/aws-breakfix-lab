# Incident 06: disk exhaustion detection.
# Disk usage is not a default EC2 metric — the CloudWatch agent publishes it
# as a custom metric (CWAgent namespace), then an alarm watches it.

# Agent config stored in SSM Parameter Store
resource "aws_ssm_parameter" "cw_agent_config" {
  name = "/breakfix/cloudwatch-agent/config"
  type = "String"
  value = jsonencode({
    metrics = {
      namespace = "CWAgent"
      append_dimensions = {
        InstanceId = "$${aws:InstanceId}"
      }
      metrics_collected = {
        disk = {
          measurement                 = ["used_percent"]
          resources                   = ["/"]
          metrics_collection_interval = 60
        }
        mem = {
          measurement                 = ["mem_used_percent"]
          metrics_collection_interval = 60
        }
      }
    }
  })
  tags = { Incident = "06-disk-full" }
}

# IAM permissions for the instances to run the agent + read the config
resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# SSM association: install + configure the agent on the app instances
resource "aws_ssm_association" "cw_agent" {
  depends_on = [aws_ssm_association.cw_agent_install]
  name             = "AmazonCloudWatch-ManageAgent"
  association_name = "breakfix-cw-agent"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.app[0].id, aws_instance.app[1].id]
  }

  parameters = {
    action                        = "configure"
    mode                          = "ec2"
    optionalConfigurationSource   = "ssm"
    optionalConfigurationLocation = aws_ssm_parameter.cw_agent_config.name
    optionalRestart               = "yes"
  }
}

# Alarm on disk usage per instance
resource "aws_cloudwatch_metric_alarm" "disk_high" {
  count               = length(aws_instance.app)
  alarm_name          = "breakfix-disk-high-${count.index}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Incident 06 detector: root disk over 85%"
  dimensions = {
    InstanceId = aws_instance.app[count.index].id
    path       = "/"
  }
  alarm_actions      = [data.aws_sns_topic.alerts.arn]
  treat_missing_data = "notBreaching"
  tags               = { Incident = "06-disk-full" }
}

resource "aws_ssm_association" "cw_agent_install" {
  name             = "AWS-ConfigureAWSPackage"
  association_name = "breakfix-cw-agent-install"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.app[0].id, aws_instance.app[1].id]
  }

  parameters = {
    action = "Install"
    name   = "AmazonCloudWatchAgent"
  }
}

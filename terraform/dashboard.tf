resource "aws_cloudwatch_dashboard" "breakfix" {
  dashboard_name = "breakfix-observability"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# Break/Fix Lab — Observability\nEach widget maps to a documented incident. Alarms fire to SNS (breakfix-alerts)."
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "Incident 07 — CPU Utilization"
          region = "us-east-1"
          view   = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.app[0].id, { label = "app-0" }],
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.app[1].id, { label = "app-1" }]
          ]
          yAxis = { left = { min = 0, max = 100 } }
          annotations = { horizontal = [{ label = "alarm threshold", value = 80 }] }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "Incident 01 — Instance Status Check"
          region = "us-east-1"
          view   = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.app[0].id, { label = "app-0" }],
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", aws_instance.app[1].id, { label = "app-1" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "Incident 03 — ALB 5XX Errors"
          region = "us-east-1"
          view   = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.app.arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          title  = "Incident 03 — ALB Healthy vs Unhealthy Hosts"
          region = "us-east-1"
          view   = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.app.arn_suffix, "TargetGroup", aws_lb_target_group.app.arn_suffix, { label = "healthy" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.app.arn_suffix, "TargetGroup", aws_lb_target_group.app.arn_suffix, { label = "unhealthy" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count & Latency"
          region = "us-east-1"
          view   = "timeSeries"
          stacked = false
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app.arn_suffix, { label = "requests" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.app.arn_suffix, { label = "latency (s)", yAxis = "right" }]
          ]
        }
      },
      {
        type   = "alarm"
        x      = 12
        y      = 14
        width  = 12
        height = 6
        properties = {
          title = "All Incident Detectors — Alarm State"
          alarms = [
            "arn:aws:cloudwatch:us-east-1:287773673131:alarm:breakfix-cpu-high-0",
            "arn:aws:cloudwatch:us-east-1:287773673131:alarm:breakfix-cpu-high-1",
            "arn:aws:cloudwatch:us-east-1:287773673131:alarm:breakfix-statuscheck-0",
            "arn:aws:cloudwatch:us-east-1:287773673131:alarm:breakfix-statuscheck-1",
            "arn:aws:cloudwatch:us-east-1:287773673131:alarm:breakfix-alb-5xx",
            "arn:aws:cloudwatch:us-east-1:287773673131:alarm:breakfix-alb-unhealthy-hosts"
          ]
        }
      }
    ]
  })
}

output "dashboard_url" {
  value = "https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards/dashboard/breakfix-observability"
}

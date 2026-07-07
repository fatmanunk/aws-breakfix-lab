# Incident 08: security-group drift detection.
resource "aws_cloudwatch_event_rule" "sg_drift" {
  name        = "breakfix-sg-drift"
  description = "Incident 08 detector: security group rule changes"

  event_pattern = jsonencode({
    source      = ["aws.ec2"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ec2.amazonaws.com"]
      eventName = [
        "AuthorizeSecurityGroupIngress",
        "AuthorizeSecurityGroupEgress",
        "RevokeSecurityGroupIngress",
        "RevokeSecurityGroupEgress"
      ]
    }
  })

  tags = { Incident = "08-security-group-drift" }
}

resource "aws_cloudwatch_event_target" "sg_drift_sns" {
  rule      = aws_cloudwatch_event_rule.sg_drift.name
  target_id = "send-to-sns"
  arn       = data.aws_sns_topic.alerts.arn

  input_transformer {
    input_paths = {
      account   = "$.account"
      region    = "$.region"
      eventName = "$.detail.eventName"
      user      = "$.detail.userIdentity.arn"
      group     = "$.detail.requestParameters.groupId"
      time      = "$.time"
    }
    input_template = "\"DRIFT DETECTED (Incident 08): <eventName> on security group <group> by <user> in <account>/<region> at <time>\""
  }
}

resource "aws_sns_topic_policy" "allow_eventbridge" {
  arn = data.aws_sns_topic.alerts.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowEventBridgePublish"
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sns:Publish"
        Resource  = data.aws_sns_topic.alerts.arn
      }
    ]
  })
}

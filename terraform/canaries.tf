# Incidents 04 (outbound loss) and 05 (DNS failure): synthetic canaries.
resource "aws_s3_bucket" "canary_artifacts" {
  bucket        = "breakfix-canary-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = { Name = "breakfix-canary-artifacts" }
}

resource "aws_iam_role" "canary" {
  name = "breakfix-canary-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "canary" {
  name = "breakfix-canary-policy"
  role = aws_iam_role.canary.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetBucketLocation"]
        Resource = ["${aws_s3_bucket.canary_artifacts.arn}/*", aws_s3_bucket.canary_artifacts.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/cwsyn-*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = { StringEquals = { "cloudwatch:namespace" = "CloudWatchSynthetics" } }
      }
    ]
  })
}

resource "local_file" "canary_script" {
  filename = "${path.module}/canary/nodejs/node_modules/reachability.js"
  content  = <<-SCRIPT
    const synthetics = require('Synthetics');
    const log = require('SyntheticsLogger');
    const https = require('https');

    const reachabilityCheck = async function () {
      await new Promise((resolve, reject) => {
        const req = https.get('https://aws.amazon.com', (res) => {
          log.info('Status: ' + res.statusCode);
          if (res.statusCode >= 200 && res.statusCode < 400) {
            resolve();
          } else {
            reject(new Error('Non-2xx/3xx status: ' + res.statusCode));
          }
        });
        req.on('error', (e) => reject(new Error('Reachability failed: ' + e.message)));
        req.setTimeout(10000, () => reject(new Error('Timeout - outbound may be severed')));
      });
    };

    exports.handler = async () => {
      return await synthetics.executeStep('reachability', reachabilityCheck);
    };
  SCRIPT
}

data "archive_file" "canary" {
  type        = "zip"
  source_dir  = "${path.module}/canary"
  output_path = "${path.module}/canary.zip"
  depends_on  = [local_file.canary_script]
}

resource "aws_synthetics_canary" "reachability" {
  name                 = "breakfix-reach"
  artifact_s3_location = "s3://${aws_s3_bucket.canary_artifacts.id}/canary"
  execution_role_arn   = aws_iam_role.canary.arn
  runtime_version      = "syn-nodejs-puppeteer-9.0"
  handler              = "reachability.handler"
  zip_file             = data.archive_file.canary.output_path

  schedule {
    expression = "rate(5 minutes)"
  }

  success_retention_period = 2
  failure_retention_period = 7

  tags = { Incident = "04-05-outbound-dns" }
}

resource "aws_cloudwatch_metric_alarm" "canary_failed" {
  alarm_name          = "breakfix-reachability-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "SuccessPercent"
  namespace           = "CloudWatchSynthetics"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "Incidents 04/05 detector: DNS or outbound reachability failing"
  dimensions          = { CanaryName = aws_synthetics_canary.reachability.name }
  alarm_actions       = [data.aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"
  tags                = { Incident = "04-05-outbound-dns" }
}

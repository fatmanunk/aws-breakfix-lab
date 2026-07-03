# Trust policy - EC2 can assume the role
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "breakfix-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = { Name = "breakfix-app-role" }
}

# Least-privilege DynamoDB access - scoped to the specific table ARN only
data "aws_iam_policy_document" "dynamo_access" {
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem"
    ]
    resources = [aws_dynamodb_table.visitors.arn]
  }
}

resource "aws_iam_role_policy" "dynamo" {
  name   = "breakfix-dynamo-access"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.dynamo_access.json
}

# SSM access for management without SSH keys
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = "breakfix-app-profile"
  role = aws_iam_role.app.name
}

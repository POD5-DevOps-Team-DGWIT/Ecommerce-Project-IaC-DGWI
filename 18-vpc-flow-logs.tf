# VPC Flow Log: records every network connection in the VPC (allowed and blocked)
# and sends the records to a CloudWatch log group.

resource "aws_flow_log" "flow_log" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.vpc.id

  tags = {
    Name = "pod5_flow_log" # A label you can see in the console.
  }
}

# The CloudWatch "folder" where the records are kept.
resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "pod5_flow_log"
  retention_in_days = 7 # Delete records after 7 days, so the CloudWatch bill does not keep growing.
}

# Who may borrow the role: only the VPC Flow Logs service.
data "aws_iam_policy_document" "flow_log_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "flow_log" {
  name               = "pod5_flow_log_role"
  assume_role_policy = data.aws_iam_policy_document.flow_log_assume_role.json
}

# What the role may do once borrowed.
# There is no "logs:CreateLogGroup" on purpose: Terraform creates the log group,
# so this role must not be able to re-create it after a destroy.
data "aws_iam_policy_document" "flow_log" {
  # Write records into THIS log group only.
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      aws_cloudwatch_log_group.flow_log.arn,
      "${aws_cloudwatch_log_group.flow_log.arn}:*",
    ]
  }

  # Lookups the flow log service makes before writing.
  statement {
    effect = "Allow"

    actions = [
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flow_log" {
  name   = "pod5_flow_log_policy"
  role   = aws_iam_role.flow_log.id
  policy = data.aws_iam_policy_document.flow_log.json
}
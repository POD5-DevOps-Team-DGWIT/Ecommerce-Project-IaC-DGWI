resource "aws_flow_log" "flow_log" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.vpc.id

  tags = {
    Name = "pod5_flow_log" #Your desired name for your vpc, A label you can see on the console.
  }
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "pod5_flow_log"
  retention_in_days = 7 #Must be added, Without it, logs are kept forever and the CloudWatch bill slowly grows.
}

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

data "aws_iam_policy_document" "flow_log" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]

  }
}
#["*"] lets the role write to any log group in the AWS account. 
#Better and tighter permission is ["${aws_cloudwatch_log_group.flow_log.arn}:*"], which limits it to this one group.	Optional hardening though, and a good DevSecOps exercise.

resource "aws_iam_role_policy" "flow_log" {
  name   = "pod5_flow_log_policy"
  role   = aws_iam_role.flow_log.id
  policy = data.aws_iam_policy_document.flow_log.json
}

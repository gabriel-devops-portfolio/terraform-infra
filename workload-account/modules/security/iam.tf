############################
# Data Sources
############################
data "aws_caller_identity" "current" {}

############################
# Lambda IAM Role
############################
resource "aws_iam_role" "inspection_lambda" {
  name = "${var.env}-inspection-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "inspection_policy" {
  name = "${var.env}-inspection-controller-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ManageTGWRoutes"
        Effect = "Allow"
        Action = [
          "ec2:CreateTransitGatewayRoute",
          "ec2:DeleteTransitGatewayRoute",
          "ec2:SearchTransitGatewayRoutes"
        ]
        Resource = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:transit-gateway-route-table/*"
      },
      {
        Sid    = "ReadFirewallHealth"
        Effect = "Allow"
        Action = [
          "network-firewall:DescribeFirewall"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogging"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*",
          "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*:log-stream:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "inspection_attach" {
  role       = aws_iam_role.inspection_lambda.name
  policy_arn = aws_iam_policy.inspection_policy.arn
}

############################
# Lambda Function
############################

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "inspection_lambda" {
  name              = "/aws/lambda/${var.env}_inspection_controller"
  retention_in_days = 7

  tags = {
    Name        = "${var.env}-inspection-controller-logs"
    Environment = var.env
    Purpose     = "fail-close-enforcement"
  }
}

resource "aws_lambda_function" "inspection_controller" {
  function_name = "${var.env}_inspection_controller"
  runtime       = "python3.11"
  handler       = "inspection_controller.lambda_handler"
  role          = aws_iam_role.inspection_lambda.arn
  filename      = "${path.module}/lambda/inspection_controller.zip"

  # Lambda Configuration
  timeout     = 30
  memory_size = 128

  environment {
    variables = {
      TGW_ROUTE_TABLE_ID   = var.tgw_route_table_id
      EGRESS_ATTACHMENT_ID = var.egress_attachment_id
      FIREWALL_NAME        = var.firewall_name
    }
  }

  tags = {
    Name        = "${var.env}-inspection-controller"
    Environment = var.env
    Purpose     = "fail-close-enforcement"
  }

  depends_on = [
    aws_cloudwatch_log_group.inspection_lambda,
    aws_iam_role_policy_attachment.inspection_attach
  ]
}

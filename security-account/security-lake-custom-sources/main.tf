############################################
# Security Lake Custom Sources Integration
# Purpose: Transform Terraform State Access Logs to OCSF format
# This module only handles custom logs (Terraform State Access)
############################################

############################################
# Data Sources
############################################
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

############################################
# Local Variables
############################################
locals {
  security_account_id = data.aws_caller_identity.current.account_id
  region              = data.aws_region.current.id

  common_tags = {
    ManagedBy   = "terraform"
    Environment = "production"
    Purpose     = "security-lake-custom-sources"
    Service     = "SecurityLake"
  }

  # Reference to existing bucket (Terraform State Access Logs only)
  terraform_state_logs_bucket_name = "workload-account-terraform-state-access-logs"
}

############################################
# 1. Security Lake Custom Source - Terraform State Access
############################################
resource "aws_securitylake_custom_log_source" "terraform_state_access" {
  source_name    = "TerraformStateAccess"
  source_version = "1.0"

  event_classes = [
    "API_ACTIVITY" # OCSF class 3005
  ]

  configuration {
    crawler_configuration {
      role_arn = aws_iam_role.security_lake_crawler.arn
    }

    provider_identity {
      external_id = "terraform-state-custom-source-${local.security_account_id}"
      principal   = aws_iam_role.lambda_ocsf_transformer.arn
    }
  }
}

############################################
# 2. Lambda Function for OCSF Transformation
# transforms Terraform State Access Logs
############################################
resource "aws_lambda_function" "ocsf_transformer" {
  function_name = "SecurityLakeTerraformStateTransformer"
  description   = "Transform Terraform State access logs to OCSF format for Security Lake"
  runtime       = "python3.11"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.lambda_ocsf_transformer.arn
  timeout       = 300
  memory_size   = 512 # Reduced from 1024 since we only process text logs

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      SECURITY_LAKE_CUSTOM_SOURCE_NAME_TERRAFORM = aws_securitylake_custom_log_source.terraform_state_access.source_name
      OCSF_VERSION                               = "1.1.0"
      TERRAFORM_STATE_LOGS_BUCKET                = local.terraform_state_logs_bucket_name
    }
  }

  tags = merge(local.common_tags, {
    Name = "SecurityLakeTerraformStateTransformer"
  })
}

# Package Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda_function.zip"
}

############################################
# 4. Lambda Permissions - Allow S3 to invoke
############################################
resource "aws_lambda_permission" "allow_s3_terraform_state" {
  statement_id  = "AllowExecutionFromS3TerraformState"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ocsf_transformer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${local.terraform_state_logs_bucket_name}"
}

############################################
# 5. S3 Event Notification - Terraform State Access Logs
############################################
resource "aws_s3_bucket_notification" "terraform_state_logs" {
  bucket = local.terraform_state_logs_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.ocsf_transformer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "terraform-state/"
    filter_suffix       = ".log"
  }

  depends_on = [
    aws_lambda_permission.allow_s3_terraform_state
  ]
}

############################################
# 6. CloudWatch Log Group for Lambda
############################################
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.ocsf_transformer.function_name}"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = merge(local.common_tags, {
    Name = "SecurityLakeOCSFTransformerLogs"
  })
}

############################################
# 7. CloudWatch Alarms for Monitoring
############################################
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "SecurityLakeTerraformStateTransformer-Errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Alert when OCSF transformer has too many errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.ocsf_transformer.function_name
  }

  alarm_actions = [var.sns_topic_arn]

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "SecurityLakeTerraformStateTransformer-Throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Alert when OCSF transformer is being throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.ocsf_transformer.function_name
  }

  alarm_actions = [var.sns_topic_arn]

  tags = local.common_tags
}

############################################
# 8. IAM Role for Security Lake Crawler
############################################
resource "aws_iam_role" "security_lake_crawler" {
  name        = "SecurityLakeCrawlerRole"
  description = "Role for Security Lake to crawl custom source data"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "securitylake.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.security_account_id
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "SecurityLakeCrawlerRole"
  })
}

resource "aws_iam_role_policy" "security_lake_crawler" {
  name = "SecurityLakeCrawlerPolicy"
  role = aws_iam_role.security_lake_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glue:CreateDatabase",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions",
          "glue:CreatePartition",
          "glue:UpdatePartition"
        ]
        Resource = [
          "arn:aws:glue:${local.region}:${local.security_account_id}:catalog",
          "arn:aws:glue:${local.region}:${local.security_account_id}:database/*",
          "arn:aws:glue:${local.region}:${local.security_account_id}:table/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::aws-security-data-lake-${local.region}-${local.security_account_id}",
          "arn:aws:s3:::aws-security-data-lake-${local.region}-${local.security_account_id}/*"
        ]
      }
    ]
  })
}

############################################
# IAM Role for Lambda OCSF Transformer
# Only for Terraform State Access Logs
############################################
resource "aws_iam_role" "lambda_ocsf_transformer" {
  name        = "SecurityLakeTerraformStateTransformerRole"
  description = "Role for Lambda to transform Terraform State access logs to OCSF and send to Security Lake"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "SecurityLakeTerraformStateTransformerRole"
  })
}

############################################
# IAM Policy for Lambda - S3 Read Access (Terraform State Logs Only)
############################################
resource "aws_iam_role_policy" "lambda_s3_read" {
  name = "S3ReadPolicy"
  role = aws_iam_role.lambda_ocsf_transformer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadTerraformStateLogs"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${local.terraform_state_logs_bucket_name}",
          "arn:aws:s3:::${local.terraform_state_logs_bucket_name}/*"
        ]
      }
    ]
  })
}

############################################
# IAM Policy for Lambda - Security Lake Write Access (Terraform State Only)
############################################
resource "aws_iam_role_policy" "lambda_security_lake_write" {
  name = "SecurityLakeWritePolicy"
  role = aws_iam_role.lambda_ocsf_transformer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteToSecurityLakeTerraformState"
        Effect = "Allow"
        Action = [
          "securitylake:CreateCustomLogSource",
          "securitylake:PutCustomLogData",
          "securitylake:GetCustomLogSource"
        ]
        Resource = aws_securitylake_custom_log_source.terraform_state_access.arn
      },
      {
        Sid    = "SecurityLakeS3Write"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          "arn:aws:s3:::aws-security-data-lake-${local.region}-${local.security_account_id}/*"
        ]
      }
    ]
  })
}

############################################
# IAM Policy for Lambda - CloudWatch Logs
############################################
resource "aws_iam_role_policy" "lambda_cloudwatch_logs" {
  name = "CloudWatchLogsPolicy"
  role = aws_iam_role.lambda_ocsf_transformer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CreateLogGroup"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.security_account_id}:*"
      },
      {
        Sid    = "CreateLogStreamAndPutLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${local.region}:${local.security_account_id}:log-group:/aws/lambda/${aws_lambda_function.ocsf_transformer.function_name}:*"
        ]
      }
    ]
  })
}

############################################
# IAM Policy for Lambda - KMS Decrypt (for encrypted S3 objects)
############################################
resource "aws_iam_role_policy" "lambda_kms_decrypt" {
  name = "KMSDecryptPolicy"
  role = aws_iam_role.lambda_ocsf_transformer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DecryptS3Objects"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "s3.${local.region}.amazonaws.com"
            ]
          }
        }
      }
    ]
  })
}

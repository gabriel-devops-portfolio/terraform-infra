############################################
# Custom Log Sources for Security Lake
# Purpose: Configure non-native AWS services to send logs to Security Lake
############################################

############################################
# Network Firewall Custom Source
############################################
resource "aws_securitylake_custom_log_source" "network_firewall" {
  count = var.enable_network_firewall_logs ? 1 : 0

  source_name    = "NetworkFirewall"
  source_version = "1.0"

  configuration {
    crawler_configuration {
      role_arn = aws_iam_role.custom_source_crawler[0].arn
    }

    provider_identity {
      external_id = "network-firewall-${local.security_account_id}"
      principal   = "arn:aws:iam::${local.security_account_id}:root"
    }
  }

  event_classes = [
    "NETWORK_ACTIVITY"
  ]

  depends_on = [aws_securitylake_data_lake.main]
}

############################################
# IAM Role for Custom Source Crawler
############################################
resource "aws_iam_role" "custom_source_crawler" {
  count = var.enable_network_firewall_logs ? 1 : 0

  name        = "SecurityLakeCustomSourceCrawler"
  description = "IAM role for Security Lake custom source crawler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      },
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
    Name = "CustomSourceCrawlerRole"
  })
}

# Policy for custom source crawler
resource "aws_iam_role_policy" "custom_source_crawler" {
  count = var.enable_network_firewall_logs ? 1 : 0

  name = "CustomSourceCrawlerPolicy"
  role = aws_iam_role.custom_source_crawler[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::aws-security-data-lake-*",
          "arn:aws:s3:::aws-security-data-lake-*/*"
        ]
      },
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
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:${local.security_account_id}:*"
      }
    ]
  })
}

############################################
# CloudWatch Log Group for Network Firewall Logs
############################################
resource "aws_cloudwatch_log_group" "network_firewall" {
  count = var.enable_network_firewall_logs ? 1 : 0

  name              = "/aws/networkfirewall/flowlogs"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.security_lake_logs[0].arn

  tags = merge(local.common_tags, {
    Name      = "network-firewall-logs"
    LogSource = "NetworkFirewall"
  })
}

# KMS Key for Network Firewall logs encryption
resource "aws_kms_key" "security_lake_logs" {
  count = var.enable_network_firewall_logs ? 1 : 0

  description             = "KMS key for Security Lake custom log sources"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.security_account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:*:${local.security_account_id}:*"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "security-lake-custom-logs"
  })
}

resource "aws_kms_alias" "security_lake_logs" {
  count = var.enable_network_firewall_logs ? 1 : 0

  name          = "alias/security-lake-custom-logs"
  target_key_id = aws_kms_key.security_lake_logs[0].key_id
}

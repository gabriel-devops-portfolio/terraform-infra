############################################
# Security Account - KMS Key for Cross-Account Encryption
# Purpose: Encrypt security logs with cross-account access
############################################

############################################
# KMS Key for Security Logs
############################################
resource "aws_kms_key" "security_logs" {
  description             = "KMS key for security logs encryption with cross-account access"
  deletion_window_in_days = 30
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
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = [
              local.security_account_id,
              local.workload_account_id,
              local.management_account_id
            ]
          }
          StringLike = {
            "kms:EncryptionContext:aws:cloudtrail:arn" = [
              "arn:aws:cloudtrail:*:${local.security_account_id}:trail/*",
              "arn:aws:cloudtrail:*:${local.workload_account_id}:trail/*",
              "arn:aws:cloudtrail:*:${local.management_account_id}:trail/*"
            ]
          }
        }
      },
      {
        Sid    = "Allow VPC Flow Logs to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Security Lake to use the key"
        Effect = "Allow"
        Principal = {
          Service = "securitylake.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow workload account to use the key for encryption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.workload_account_id}:root"
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
          StringEquals = {
            "kms:ViaService" = [
              "s3.${var.region}.amazonaws.com",
              "logs.${var.region}.amazonaws.com"
            ]
          }
        }
      },
      {
        Sid    = "Allow management account to use the key"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.management_account_id}:root"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs to use the key"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.region}:${local.security_account_id}:log-group:*"
          }
        }
      },
      {
        Sid    = "Allow Athena to decrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "athena.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow OpenSearch to decrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "security-logs-kms-key"
    Purpose = "cross-account-log-encryption"
  })
}

# KMS Key Alias
resource "aws_kms_alias" "security_logs" {
  name          = "alias/security-logs"
  target_key_id = aws_kms_key.security_logs.key_id
}

############################################
# KMS Key for GuardDuty
############################################
resource "aws_kms_key" "guardduty" {
  description             = "KMS key for GuardDuty findings encryption"
  deletion_window_in_days = 30
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
        Sid    = "Allow GuardDuty to use the key"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:Encrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "guardduty-kms-key"
    Purpose = "guardduty-findings-encryption"
  })
}

# KMS Key Alias for GuardDuty
resource "aws_kms_alias" "guardduty" {
  name          = "alias/guardduty"
  target_key_id = aws_kms_key.guardduty.key_id
}

############################################
# KMS Key for Security Hub
############################################
resource "aws_kms_key" "securityhub" {
  description             = "KMS key for Security Hub findings encryption"
  deletion_window_in_days = 30
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
        Sid    = "Allow Security Hub to use the key"
        Effect = "Allow"
        Principal = {
          Service = "securityhub.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt",
          "kms:Encrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "securityhub-kms-key"
    Purpose = "securityhub-findings-encryption"
  })
}

# KMS Key Alias for Security Hub
resource "aws_kms_alias" "securityhub" {
  name          = "alias/securityhub"
  target_key_id = aws_kms_key.securityhub.key_id
}

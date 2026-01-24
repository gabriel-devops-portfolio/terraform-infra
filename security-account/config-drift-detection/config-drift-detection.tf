############################################
# AWS Config – Drift Detection (Enterprise)
############################################

############################################
# Data Sources
############################################
data "aws_caller_identity" "current" {}

############################################
# Config S3 Bucket - Use existing CloudTrail bucket
############################################
data "aws_s3_bucket" "config_logs" {
  bucket = var.config_bucket_name
}

# Note: Using existing CloudTrail bucket for Config logs
# Bucket versioning, encryption, and public access block are already configured
# resource "aws_s3_bucket_versioning" "config_logs" {
#   bucket = data.aws_s3_bucket.config_logs.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "config_logs" {
#   bucket = data.aws_s3_bucket.config_logs.id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# resource "aws_s3_bucket_public_access_block" "config_logs" {
#   bucket = data.aws_s3_bucket.config_logs.id
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# Note: Bucket policy is managed by the cross-account-roles module
# The CloudTrail bucket already has appropriate permissions for Config
# If Config-specific permissions are needed, they should be added to the
# cross-account-roles module's bucket policy, not managed here
#
# resource "aws_s3_bucket_policy" "config_logs" {
#   bucket = data.aws_s3_bucket.config_logs.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "AWSConfigBucketPermissionsCheck"
#         Effect = "Allow"
#         Principal = {
#           Service = "config.amazonaws.com"
#         }
#         Action = [
#           "s3:GetBucketAcl",
#           "s3:ListBucket"
#         ]
#         Resource = data.aws_s3_bucket.config_logs.arn
#         Condition = {
#           StringEquals = {
#             "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
#           }
#         }
#       },
#       {
#         Sid    = "AWSConfigBucketWrite"
#         Effect = "Allow"
#         Principal = {
#           Service = "config.amazonaws.com"
#         }
#         Action   = "s3:PutObject"
#         Resource = "${data.aws_s3_bucket.config_logs.arn}/*"
#         Condition = {
#           StringEquals = {
#             "s3:x-amz-acl"      = "bucket-owner-full-control"
#             "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
#           }
#         }
#       }
#     ]
#   })
# }

############################################
# Config Recorder
############################################
resource "aws_config_configuration_recorder" "this" {
  name     = "org-config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

############################################
# Config Delivery Channel
############################################
resource "aws_config_delivery_channel" "this" {
  name           = "org-config-delivery"
  s3_bucket_name = data.aws_s3_bucket.config_logs.id

  depends_on = [aws_config_configuration_recorder.this]
}

############################################
# Start Recorder
############################################
resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}

############################################
# IAM Role for AWS Config
############################################
resource "aws_iam_role" "config_role" {
  name = "AWSConfigRecorderRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "config_policy" {
  name = "ConfigPolicy"
  role = aws_iam_role.config_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          data.aws_s3_bucket.config_logs.arn,
          "${data.aws_s3_bucket.config_logs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "config:Put*"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# ===============================
# DRIFT DETECTION RULES
# ===============================
############################################

############################################
# VPC Drift
############################################
resource "aws_config_config_rule" "vpc_drift" {
  name = "vpc-configuration-drift"

  source {
    owner             = "AWS"
    source_identifier = "VPC_FLOW_LOGS_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.this]
}

############################################
# Route Table Drift - COMMENTED OUT (Invalid source identifier)
############################################
# resource "aws_config_config_rule" "route_table_drift" {
#   name = "route-table-drift"
#
#   source {
#     owner             = "AWS"
#     source_identifier = "VPC_ROUTE_TABLE_UNUSED_ROUTES_CHECK"
#   }
# }

############################################
# Security Group Drift
############################################
resource "aws_config_config_rule" "security_group_drift" {
  name = "security-group-drift"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = [aws_config_configuration_recorder.this]
}

############################################
# VPC Endpoint Drift - COMMENTED OUT (Invalid source identifier)
############################################
# resource "aws_config_config_rule" "vpce_drift" {
#   name = "vpc-endpoint-drift"
#
#   source {
#     owner             = "AWS"
#     source_identifier = "VPC_ENDPOINT_SERVICE_PRIVATE_DNS_NAME_ENABLED"
#   }
# }

############################################
# Transit Gateway Drift - COMMENTED OUT (Invalid source identifier)
############################################
# resource "aws_config_config_rule" "tgw_drift" {
#   name = "transit-gateway-drift"
#
#   source {
#     owner             = "AWS"
#     source_identifier = "EC2_TRANSIT_GATEWAY_ATTACHMENT_AUTHORIZED"
#   }
# }

############################################
# Network Firewall Drift - COMMENTED OUT (Invalid source identifier)
############################################
# resource "aws_config_config_rule" "firewall_drift" {
#   name = "network-firewall-drift"
#
#   source {
#     owner             = "AWS"
#     source_identifier = "NETWORK_FIREWALL_POLICY_DEFAULT_ACTIONS"
#   }
# }

############################################
# IAM Role Drift - COMMENTED OUT (Requires parameters)
############################################
# resource "aws_config_config_rule" "iam_role_drift" {
#   name = "iam-role-drift"
#
#   source {
#     owner             = "AWS"
#     source_identifier = "IAM_ROLE_MANAGED_POLICY_CHECK"
#   }
#
#   input_parameters = jsonencode({
#     managedPolicyArns = "arn:aws:iam::aws:policy/ReadOnlyAccess"
#   })
#
#   depends_on = [aws_config_configuration_recorder.this]
# }

############################################
# Encryption Drift (KMS) - COMMENTED OUT (Invalid source identifier)
############################################
# resource "aws_config_config_rule" "kms_drift" {
#   name = "kms-encryption-drift"
#
#   source {
#     owner             = "AWS"
#     source_identifier = "KMS_KEY_ROTATION_ENABLED"
#   }
# }

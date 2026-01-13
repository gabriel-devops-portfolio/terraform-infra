############################################
# AWS Security Lake Configuration
# Purpose: Centralized security data lake for all accounts
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
  region              = data.aws_region.current.name

  common_tags = {
    ManagedBy   = "terraform"
    Environment = "production"
    Purpose     = "security-lake"
    Service     = "SecurityLake"
  }
}

############################################
# Security Lake Data Lake
############################################
resource "aws_securitylake_data_lake" "main" {
  meta_store_manager_role_arn = aws_iam_role.security_lake_manager.arn

  configuration {
    region = local.region

    lifecycle_configuration {
      expiration {
        days = 365
      }

      transition {
        days          = 30
        storage_class = "INTELLIGENT_TIERING"
      }
    }
  }

  tags = merge(local.common_tags, {
    Name = "org-security-lake"
  })
}

############################################
# IAM Role for Security Lake Manager
############################################
resource "aws_iam_role" "security_lake_manager" {
  name        = "AWSSecurityLakeMetaStoreManager"
  description = "Role for Security Lake to manage metadata"

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
    Name = "SecurityLakeManagerRole"
  })
}

# Attach AWS managed policy for Security Lake
resource "aws_iam_role_policy_attachment" "security_lake_manager" {
  role       = aws_iam_role.security_lake_manager.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSecurityLakeMetastoreManager"
}

############################################
# AWS Log Sources - CloudTrail
############################################
resource "aws_securitylake_aws_log_source" "cloudtrail_mgmt" {
  source {
    accounts    = var.member_account_ids
    regions     = [local.region]
    source_name = "CLOUD_TRAIL_MGMT"
  }

  depends_on = [aws_securitylake_data_lake.main]
}

############################################
# AWS Log Sources - VPC Flow Logs
############################################
resource "aws_securitylake_aws_log_source" "vpc_flow" {
  source {
    accounts    = var.member_account_ids
    regions     = [local.region]
    source_name = "VPC_FLOW"
  }

  depends_on = [aws_securitylake_data_lake.main]
}

############################################
# AWS Log Sources - Security Hub Findings
############################################
resource "aws_securitylake_aws_log_source" "security_hub" {
  source {
    accounts    = var.member_account_ids
    regions     = [local.region]
    source_name = "SH_FINDINGS"
  }

  depends_on = [aws_securitylake_data_lake.main]
}

############################################
# AWS Log Sources - Route 53 Resolver
############################################
resource "aws_securitylake_aws_log_source" "route53_resolver" {
  source {
    accounts    = var.member_account_ids
    regions     = [local.region]
    source_name = "ROUTE53"
  }

  depends_on = [aws_securitylake_data_lake.main]
}

############################################
# Security Lake Subscriber - OpenSearch Integration
# Purpose: Allow OpenSearch to query OCSF-normalized security data
############################################
resource "aws_securitylake_subscriber" "opensearch" {
  subscriber_name = "opensearch-ocsf-subscriber"

  access_type = "S3"

  # Subscribe to all AWS log sources (VPC Flow, CloudTrail, Security Hub, Route 53)
  source {
    aws_log_source_resource {
      source_name    = "VPC_FLOW"
      source_version = "2.0"
    }
  }

  source {
    aws_log_source_resource {
      source_name    = "CLOUD_TRAIL_MGMT"
      source_version = "2.0"
    }
  }

  source {
    aws_log_source_resource {
      source_name    = "SH_FINDINGS"
      source_version = "1.0"
    }
  }

  source {
    aws_log_source_resource {
      source_name    = "ROUTE53"
      source_version = "1.0"
    }
  }

  subscriber_identity {
    principal   = var.opensearch_role_arn
    external_id = "opensearch-security-lake-${local.security_account_id}"
  }

  tags = merge(local.common_tags, {
    Name    = "opensearch-ocsf-subscriber"
    Purpose = "opensearch-security-lake-integration"
  })

  depends_on = [
    aws_securitylake_aws_log_source.vpc_flow,
    aws_securitylake_aws_log_source.cloudtrail_mgmt,
    aws_securitylake_aws_log_source.security_hub,
    aws_securitylake_aws_log_source.route53_resolver
  ]
}

############################################
# Amazon OpenSearch for Security Lake
# Purpose: Real-time monitoring, alerting, and visualization
############################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

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
    Purpose     = "security-monitoring"
    Service     = "OpenSearch"
  }
}

############################################
# KMS Key for OpenSearch Encryption
############################################
resource "aws_kms_key" "opensearch" {
  description             = "KMS key for OpenSearch encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "opensearch-encryption-key"
  })
}

resource "aws_kms_alias" "opensearch" {
  name          = "alias/opensearch-security-logs"
  target_key_id = aws_kms_key.opensearch.key_id
}

############################################
# Security Group for OpenSearch (VPC only)
############################################
resource "aws_security_group" "opensearch" {
  count = var.vpc_id != null ? 1 : 0

  name        = "opensearch-security-logs"
  description = "Security group for OpenSearch domain"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "opensearch-security-group"
  })
}

############################################
# Random Password for OpenSearch Admin
############################################
resource "random_password" "opensearch_admin" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store password in Secrets Manager
resource "aws_secretsmanager_secret" "opensearch_admin" {
  name        = "opensearch-admin-password"
  description = "Admin password for OpenSearch domain"

  tags = merge(local.common_tags, {
    Name = "opensearch-admin-password"
  })
}

resource "aws_secretsmanager_secret_version" "opensearch_admin" {
  secret_id     = aws_secretsmanager_secret.opensearch_admin.id
  secret_string = random_password.opensearch_admin.result
}

############################################
# Amazon OpenSearch Domain
############################################
resource "aws_opensearch_domain" "security_logs" {
  domain_name    = "security-logs"
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type            = var.opensearch_instance_type
    instance_count           = var.opensearch_instance_count
    dedicated_master_enabled = true
    dedicated_master_type    = var.opensearch_master_type
    dedicated_master_count   = 3
    zone_awareness_enabled   = var.opensearch_instance_count > 1

    dynamic "zone_awareness_config" {
      for_each = var.opensearch_instance_count > 1 ? [1] : []
      content {
        availability_zone_count = var.opensearch_instance_count
      }
    }

    warm_enabled = var.enable_warm_storage
    dynamic "warm_config" {
      for_each = var.enable_warm_storage ? [1] : []
      content {
        warm_enabled = true
        warm_type    = "ultrawarm1.medium.search"
        warm_count   = 2
      }
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.ebs_volume_size
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = aws_kms_key.opensearch.arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = "admin"
      master_user_password = random_password.opensearch_admin.result
    }
  }

  # Only deploy in VPC if private_subnet_ids is provided
  dynamic "vpc_options" {
    for_each = var.private_subnet_ids != null ? [1] : []
    content {
      subnet_ids         = var.private_subnet_ids
      security_group_ids = [aws_security_group.opensearch[0].id]
    }
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "es:*"
        Resource = "arn:aws:es:${local.region}:${local.security_account_id}:domain/security-logs/*"
      }
    ]
  })

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_index_slow.arn
    log_type                 = "INDEX_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_search_slow.arn
    log_type                 = "SEARCH_SLOW_LOGS"
  }

  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_app.arn
    log_type                 = "ES_APPLICATION_LOGS"
  }

  tags = merge(local.common_tags, {
    Name = "security-logs-opensearch"
  })

  depends_on = [
    aws_iam_service_linked_role.opensearch
  ]
}

############################################
# OpenSearch Service-Linked Role
############################################
resource "aws_iam_service_linked_role" "opensearch" {
  aws_service_name = "opensearchservice.amazonaws.com"
  description      = "Service-linked role for OpenSearch"
}

############################################
# CloudWatch Log Groups for OpenSearch
############################################
resource "aws_cloudwatch_log_group" "opensearch_index_slow" {
  name              = "/aws/opensearch/security-logs/index-slow"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "opensearch-index-slow-logs"
  })
}

resource "aws_cloudwatch_log_group" "opensearch_search_slow" {
  name              = "/aws/opensearch/security-logs/search-slow"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "opensearch-search-slow-logs"
  })
}

resource "aws_cloudwatch_log_group" "opensearch_app" {
  name              = "/aws/opensearch/security-logs/application"
  retention_in_days = 7

  tags = merge(local.common_tags, {
    Name = "opensearch-application-logs"
  })
}

# CloudWatch log resource policy for OpenSearch
resource "aws_cloudwatch_log_resource_policy" "opensearch" {
  policy_name = "opensearch-security-logs-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
        Action = [
          "logs:PutLogEvents",
          "logs:CreateLogStream"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.security_account_id}:log-group:/aws/opensearch/security-logs/*"
      }
    ]
  })
}

############################################
# IAM Role for OpenSearch Alerting to SNS
############################################
resource "aws_iam_role" "opensearch_sns" {
  name        = "OpenSearchSNSRole"
  description = "IAM role for OpenSearch to publish alerts to SNS topics"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "es.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "opensearch-sns-alerting-role"
  })
}

# IAM Policy for OpenSearch to publish to SNS
resource "aws_iam_role_policy" "opensearch_sns" {
  name = "OpenSearchSNSPolicy"
  role = aws_iam_role.opensearch_sns.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          "arn:aws:sns:${local.region}:${local.security_account_id}:soc-alerts-critical",
          "arn:aws:sns:${local.region}:${local.security_account_id}:soc-alerts-high",
          "arn:aws:sns:${local.region}:${local.security_account_id}:soc-alerts-medium"
        ]
      }
    ]
  })
}

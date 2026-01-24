############################################
# OpenSearch Domain for Jaeger Tracing
# Purpose: Distributed tracing storage backend
############################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  common_tags = {
    ManagedBy   = "terraform"
    Environment = var.environment
    Purpose     = "jaeger-tracing"
    Service     = "OpenSearch"
  }
}

############################################
# OpenSearch Domain
############################################
resource "aws_opensearch_domain" "jaeger" {
  domain_name    = "jaeger-${var.environment}"
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type            = var.instance_type
    instance_count           = var.instance_count
    dedicated_master_enabled = var.dedicated_master_enabled
    dedicated_master_type    = var.master_instance_type
    dedicated_master_count   = var.master_instance_count
    zone_awareness_enabled   = var.zone_awareness_enabled

    dynamic "zone_awareness_config" {
      for_each = var.zone_awareness_enabled ? [1] : []
      content {
        availability_zone_count = var.availability_zone_count
      }
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = var.volume_type
    volume_size = var.volume_size
    iops        = var.volume_type == "gp3" ? var.iops : null
    throughput  = var.volume_type == "gp3" ? var.throughput : null
  }

  vpc_options {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.opensearch.id]
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
    anonymous_auth_enabled         = false
    internal_user_database_enabled = false
    master_user_options {
      master_user_arn = aws_iam_role.jaeger_opensearch.arn
    }
  }

  log_publishing_options {
    cloudwatch_log_group_arn = "${aws_cloudwatch_log_group.opensearch_slow_logs.arn}:*"
    log_type                 = "SEARCH_SLOW_LOGS"
    enabled                  = true
  }

  log_publishing_options {
    cloudwatch_log_group_arn = "${aws_cloudwatch_log_group.opensearch_index_slow_logs.arn}:*"
    log_type                 = "INDEX_SLOW_LOGS"
    enabled                  = true
  }

  log_publishing_options {
    cloudwatch_log_group_arn = "${aws_cloudwatch_log_group.opensearch_error_logs.arn}:*"
    log_type                 = "ES_APPLICATION_LOGS"
    enabled                  = true
  }

  tags = merge(local.common_tags, {
    Name = "jaeger-opensearch-${var.environment}"
  })

  depends_on = [aws_iam_service_linked_role.opensearch]
}

############################################
# KMS Key for OpenSearch Encryption
############################################
resource "aws_kms_key" "opensearch" {
  description             = "KMS key for OpenSearch domain encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow OpenSearch Service"
        Effect = "Allow"
        Principal = {
          Service = "opensearch.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "opensearch-jaeger-${var.environment}"
  })
}

resource "aws_kms_alias" "opensearch" {
  name          = "alias/opensearch-jaeger-${var.environment}"
  target_key_id = aws_kms_key.opensearch.key_id
}

############################################
# Service Linked Role for OpenSearch
############################################
resource "aws_iam_service_linked_role" "opensearch" {
  aws_service_name = "es.amazonaws.com"
  description      = "Service linked role for OpenSearch"

  lifecycle {
    ignore_changes = [aws_service_name]
  }
}

############################################
# Security Group for OpenSearch
############################################
resource "aws_security_group" "opensearch" {
  name_prefix = "opensearch-jaeger-${var.environment}-"
  vpc_id      = var.vpc_id
  description = "Security group for OpenSearch Jaeger domain"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "opensearch-jaeger-${var.environment}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

############################################
# CloudWatch Log Groups
############################################
resource "aws_cloudwatch_log_group" "opensearch_slow_logs" {
  name              = "/aws/opensearch/domains/jaeger-${var.environment}/search-slow-logs"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.opensearch.arn

  tags = merge(local.common_tags, {
    Name = "opensearch-slow-logs"
  })
}

resource "aws_cloudwatch_log_group" "opensearch_index_slow_logs" {
  name              = "/aws/opensearch/domains/jaeger-${var.environment}/index-slow-logs"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.opensearch.arn

  tags = merge(local.common_tags, {
    Name = "opensearch-index-slow-logs"
  })
}

resource "aws_cloudwatch_log_group" "opensearch_error_logs" {
  name              = "/aws/opensearch/domains/jaeger-${var.environment}/error-logs"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.opensearch.arn

  tags = merge(local.common_tags, {
    Name = "opensearch-error-logs"
  })
}

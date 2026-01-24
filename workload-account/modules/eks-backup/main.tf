# EKS Backup and Restore Module
# This module provides comprehensive backup and restore capabilities for EKS clusters

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

############################
# Velero Backup Solution
############################

# S3 Bucket for Velero Backups
resource "aws_s3_bucket" "velero_backups" {
  bucket = "${var.cluster_name}-velero-backups-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-velero-backups"
    Purpose   = "EKSBackup"
    Component = "Velero"
  })
}

resource "aws_s3_bucket_versioning" "velero_backups" {
  bucket = aws_s3_bucket.velero_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero_backups" {
  bucket = aws_s3_bucket.velero_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "velero_backups" {
  bucket = aws_s3_bucket.velero_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for backup retention
resource "aws_s3_bucket_lifecycle_configuration" "velero_backups" {
  bucket = aws_s3_bucket.velero_backups.id

  rule {
    id     = "backup-lifecycle"
    status = "Enabled"

    filter {}

    expiration {
      days = var.backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

############################
# Velero IAM Role and Policy
############################

# IAM Role for Velero
resource "aws_iam_role" "velero" {
  name = "${var.cluster_name}-velero-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:velero:velero"
          "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-velero-role"
    Purpose   = "EKSBackup"
    Component = "Velero"
  })
}

# IAM Policy for Velero
resource "aws_iam_policy" "velero" {
  name        = "${var.cluster_name}-velero-policy"
  description = "Policy for Velero backup operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:CreateTags",
          "ec2:DescribeInstances",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts"
        ]
        Resource = "${aws_s3_bucket.velero_backups.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.velero_backups.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "velero" {
  role       = aws_iam_role.velero.name
  policy_arn = aws_iam_policy.velero.arn
}

############################
# EBS Snapshot Backup
############################

# IAM Role for EBS Snapshot Lambda
resource "aws_iam_role" "ebs_snapshot_lambda" {
  name = "${var.cluster_name}-ebs-snapshot-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-ebs-snapshot-lambda"
    Purpose   = "EKSBackup"
    Component = "EBSSnapshot"
  })
}

# IAM Policy for EBS Snapshot Lambda
resource "aws_iam_policy" "ebs_snapshot_lambda" {
  name        = "${var.cluster_name}-ebs-snapshot-lambda-policy"
  description = "Policy for EBS snapshot Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot",
          "ec2:CreateTags",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_snapshot_lambda" {
  role       = aws_iam_role.ebs_snapshot_lambda.name
  policy_arn = aws_iam_policy.ebs_snapshot_lambda.arn
}

############################
# ETCD Backup Configuration
############################

# S3 Bucket for ETCD Backups
resource "aws_s3_bucket" "etcd_backups" {
  bucket = "${var.cluster_name}-etcd-backups-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-etcd-backups"
    Purpose   = "EKSBackup"
    Component = "ETCD"
  })
}

resource "aws_s3_bucket_versioning" "etcd_backups" {
  bucket = aws_s3_bucket.etcd_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "etcd_backups" {
  bucket = aws_s3_bucket.etcd_backups.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "etcd_backups" {
  bucket = aws_s3_bucket.etcd_backups.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for ETCD backups
resource "aws_s3_bucket_lifecycle_configuration" "etcd_backups" {
  bucket = aws_s3_bucket.etcd_backups.id

  rule {
    id     = "etcd-backup-lifecycle"
    status = "Enabled"

    filter {}

    expiration {
      days = var.etcd_backup_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

############################
# Cross-Region Replication for DR
############################

# IAM Role for Cross-Region Replication
resource "aws_iam_role" "backup_replication" {
  count = var.enable_cross_region_backup ? 1 : 0
  name  = "${var.cluster_name}-backup-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "s3.amazonaws.com"
      }
    }]
  })

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-backup-replication-role"
    Purpose   = "EKSBackup"
    Component = "CrossRegionReplication"
  })
}

# IAM Policy for Cross-Region Replication
resource "aws_iam_role_policy" "backup_replication" {
  count = var.enable_cross_region_backup ? 1 : 0
  role  = aws_iam_role.backup_replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.velero_backups.arn,
          aws_s3_bucket.etcd_backups.arn
        ]
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.velero_backups.arn}/*",
          "${aws_s3_bucket.etcd_backups.arn}/*"
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect = "Allow"
        Resource = [
          "${var.dr_backup_bucket_arn}/*"
        ]
      },
      {
        Action = [
          "kms:Decrypt"
        ]
        Effect   = "Allow"
        Resource = var.kms_key_arn
      },
      {
        Action = [
          "kms:Encrypt"
        ]
        Effect   = "Allow"
        Resource = var.dr_kms_key_arn
      }
    ]
  })
}

############################
# Backup Monitoring and Alerting
############################

# CloudWatch Log Group for Backup Operations
resource "aws_cloudwatch_log_group" "backup_operations" {
  name              = "/aws/eks/${var.cluster_name}/backup-operations"
  retention_in_days = 30
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-backup-operations"
    Purpose   = "EKSBackup"
    Component = "Monitoring"
  })
}

# CloudWatch Metric Filter for Backup Failures
resource "aws_cloudwatch_log_metric_filter" "backup_failures" {
  name           = "${var.cluster_name}-backup-failures"
  log_group_name = aws_cloudwatch_log_group.backup_operations.name
  pattern        = "[timestamp, request_id, ERROR]"

  metric_transformation {
    name          = "BackupFailures"
    namespace     = "EKS/Backup"
    value         = "1"
    default_value = "0"

    dimensions = {
      ClusterName = var.cluster_name
    }
  }
}

# CloudWatch Alarm for Backup Failures
resource "aws_cloudwatch_metric_alarm" "backup_failure_alarm" {
  count = var.enable_backup_monitoring ? 1 : 0

  alarm_name          = "${var.cluster_name}-backup-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BackupFailures"
  namespace           = "EKS/Backup"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors backup failures for EKS cluster ${var.cluster_name}"
  alarm_actions       = var.sns_topic_arn != null ? [var.sns_topic_arn] : []

  dimensions = {
    ClusterName = var.cluster_name
  }

  tags = merge(var.tags, {
    Name      = "${var.cluster_name}-backup-failure-alarm"
    Purpose   = "EKSBackup"
    Component = "Monitoring"
  })
}

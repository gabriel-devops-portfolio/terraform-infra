############################################
# Security Account - Centralized Logging S3 Buckets
# Purpose: Store logs from all member accounts
############################################

############################################
# 1. CloudTrail Logs Bucket
############################################
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "org-cloudtrail-logs-security-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.common_tags, {
    Name    = "org-cloudtrail-logs-security"
    Purpose = "cloudtrail-centralized-logging"
  })
}

# CloudTrail Logs - Versioning
resource "aws_s3_bucket_versioning" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# CloudTrail Logs - Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.security_logs.arn
    }
  }
}

# CloudTrail Logs - Public Access Block
resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudTrail Logs - Lifecycle Policy
resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    id     = "cloudtrail-lifecycle"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 180
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555 # 7 years retention
    }
  }
}

# CloudTrail Logs - Bucket Policy
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "aws:SourceAccount" = [
              local.security_account_id,
              local.workload_account_id,
              local.management_account_id
            ]
          }
        }
      },
      {
        Sid    = "OpenSearchReadAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.opensearch.arn
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.cloudtrail_logs.arn,
          "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        ]
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.cloudtrail_logs.arn,
          "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

############################################
# 2. VPC Flow Logs Bucket
############################################
resource "aws_s3_bucket" "vpc_flow_logs" {
  bucket = "org-vpc-flow-logs-security-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.common_tags, {
    Name    = "org-vpc-flow-logs-security"
    Purpose = "vpc-flow-logs-centralized"
  })
}

# VPC Flow Logs - Versioning
resource "aws_s3_bucket_versioning" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

# VPC Flow Logs - Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.security_logs.arn
    }
  }
}

# VPC Flow Logs - Public Access Block
resource "aws_s3_bucket_public_access_block" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# VPC Flow Logs - Lifecycle Policy
resource "aws_s3_bucket_lifecycle_configuration" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  rule {
    id     = "vpc-flow-lifecycle"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}

# VPC Flow Logs - Bucket Policy
resource "aws_s3_bucket_policy" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.vpc_flow_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "aws:SourceAccount" = [
              local.workload_account_id
            ]
          }
        }
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.vpc_flow_logs.arn
      },
      {
        Sid    = "OpenSearchReadAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.opensearch.arn
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.vpc_flow_logs.arn,
          "${aws_s3_bucket.vpc_flow_logs.arn}/*"
        ]
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.vpc_flow_logs.arn,
          "${aws_s3_bucket.vpc_flow_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

############################################
# 3. Security Lake Data Bucket
############################################
resource "aws_s3_bucket" "security_lake_data" {
  bucket = "org-security-lake-data-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.common_tags, {
    Name    = "org-security-lake-data"
    Purpose = "security-lake-ocsf-format"
  })
}

# Security Lake - Versioning
resource "aws_s3_bucket_versioning" "security_lake_data" {
  bucket = aws_s3_bucket.security_lake_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Security Lake - Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "security_lake_data" {
  bucket = aws_s3_bucket.security_lake_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.security_logs.arn
    }
  }
}

# Security Lake - Public Access Block
resource "aws_s3_bucket_public_access_block" "security_lake_data" {
  bucket = aws_s3_bucket.security_lake_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Security Lake - Lifecycle Policy
resource "aws_s3_bucket_lifecycle_configuration" "security_lake_data" {
  bucket = aws_s3_bucket.security_lake_data.id

  rule {
    id     = "security-lake-lifecycle"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 730
    }
  }
}

# Security Lake - Bucket Policy
resource "aws_s3_bucket_policy" "security_lake_data" {
  bucket = aws_s3_bucket.security_lake_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecurityLakeAccess"
        Effect = "Allow"
        Principal = {
          Service = "securitylake.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.security_lake_data.arn,
          "${aws_s3_bucket.security_lake_data.arn}/*"
        ]
      },
      {
        Sid    = "AthenaAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.athena_query.arn
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.security_lake_data.arn,
          "${aws_s3_bucket.security_lake_data.arn}/*"
        ]
      },
      {
        Sid    = "OpenSearchAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.opensearch.arn
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.security_lake_data.arn,
          "${aws_s3_bucket.security_lake_data.arn}/*"
        ]
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.security_lake_data.arn,
          "${aws_s3_bucket.security_lake_data.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

############################################
# 4. Athena Query Results Bucket
############################################
resource "aws_s3_bucket" "athena_results" {
  bucket = "org-athena-query-results-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.common_tags, {
    Name    = "org-athena-query-results"
    Purpose = "athena-query-output"
  })
}

# Athena Results - Versioning
resource "aws_s3_bucket_versioning" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Athena Results - Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Athena Results - Public Access Block
resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Athena Results - Lifecycle Policy
resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "athena-results-cleanup"
    status = "Enabled"

    filter {}

    expiration {
      days = 30 # Auto-delete query results after 30 days
    }
  }
}

############################################
# S3 Bucket for -workload -Terraform State
############################################
resource "aws_s3_bucket" "terraform_state" {
  bucket = "org-workload-terraform-state-prod"

  tags = {
    Name        = "workload-terraform-state-prod"
    Environment = "prod"
    Account     = "workload"
    ManagedBy   = "terraform"
  }
}

############################################
# Versioning
############################################
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

############################################
# Server-Side Encryption
############################################
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "terraform_state" {
  bucket        = aws_s3_bucket.terraform_state.id
  target_bucket = aws_s3_bucket.terraform_state_logs.id
  target_prefix = "terraform-state/"
}

############################################
# Block ALL Public Access
############################################
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

############################################
# Access Logs Bucket
############################################
resource "aws_s3_bucket" "terraform_state_logs" {
  bucket = "workload-account-terraform-state-access-logs"

  tags = {
    Name        = "terraform-state-access-logs"
    Environment = "prod"
    Account     = "security"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "terraform_state" {
  statement {
    sid = "AllowCurrentAccountAccess"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*"
    ]
  }

  statement {
    sid = "DenyInsecureTransport"

    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = data.aws_iam_policy_document.terraform_state.json
}


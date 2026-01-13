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
        Resource = [
          "${aws_s3_bucket.cloudtrail_logs.arn}/*",
          "${aws_s3_bucket.cloudtrail_logs.arn}/terraform-state-events/*"
        ]
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
        Sid    = "AthenaQueryAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.athena_query.arn
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
    Purpose     = "terraform-state-audit-logs"
    ManagedBy   = "terraform"
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

# Block public access for logs bucket
resource "aws_s3_bucket_public_access_block" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for access logs bucket
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  rule {
    id     = "terraform-state-logs-lifecycle"
    status = "Enabled"

    filter {
      prefix = "terraform-state/"
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 180
      storage_class = "GLACIER"
    }

    expiration {
      days = 365 # Keep logs for 1 year
    }
  }
}

# Bucket policy to allow S3 log delivery
resource "aws_s3_bucket_policy" "terraform_state_logs" {
  bucket = aws_s3_bucket.terraform_state_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ServerAccessLogsPolicy"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.terraform_state_logs.arn}/terraform-state/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.terraform_state.arn
          }
        }
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.terraform_state_logs.arn,
          "${aws_s3_bucket.terraform_state_logs.arn}/*"
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

############################################
# Terraform State Bucket - Lifecycle Policy
############################################
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "terraform-state-lifecycle"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 90
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}

############################################
# CloudTrail for Terraform State Data Events
# Purpose: Capture all access to Terraform state bucket
############################################
resource "aws_cloudtrail" "terraform_state_trail" {
  name                          = "terraform-state-access-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  s3_key_prefix                 = "terraform-state-events"
  include_global_service_events = false
  is_multi_region_trail         = false
  enable_logging                = true

  event_selector {
    read_write_type           = "All"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      values = ["${aws_s3_bucket.terraform_state.arn}/*"]
    }
  }

  advanced_event_selector {
    name = "Log all Terraform state bucket events"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }

    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }

    field_selector {
      field  = "resources.ARN"
      starts_with = ["${aws_s3_bucket.terraform_state.arn}/"]
    }
  }

  tags = merge(local.common_tags, {
    Name    = "terraform-state-access-trail"
    Purpose = "audit-terraform-state-access"
  })
}

############################################
# EventBridge Rule for Terraform State Access
# Purpose: Real-time alerts to OpenSearch/Security Lake
############################################
resource "aws_cloudwatch_event_rule" "terraform_state_access" {
  name        = "terraform-state-access-detection"
  description = "Detect access to Terraform state bucket"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["s3.amazonaws.com"]
      eventName = [
        "GetObject",
        "PutObject",
        "DeleteObject",
        "CopyObject",
        "RestoreObject"
      ]
      requestParameters = {
        bucketName = [aws_s3_bucket.terraform_state.id]
      }
    }
  })

  tags = merge(local.common_tags, {
    Name    = "terraform-state-access-detection"
    Purpose = "security-monitoring"
  })
}

# EventBridge Target - Send to CloudWatch Logs for Security Lake ingestion
resource "aws_cloudwatch_log_group" "terraform_state_events" {
  name              = "/aws/events/terraform-state-access"
  retention_in_days = 365

  kms_key_id = aws_kms_key.security_logs.arn

  tags = merge(local.common_tags, {
    Name    = "terraform-state-access-events"
    Purpose = "security-lake-source"
  })
}

resource "aws_cloudwatch_event_target" "terraform_state_to_logs" {
  rule      = aws_cloudwatch_event_rule.terraform_state_access.name
  target_id = "SendToCloudWatchLogs"
  arn       = aws_cloudwatch_log_group.terraform_state_events.arn
}

# EventBridge Target - Send to SNS for immediate alerting
resource "aws_cloudwatch_event_target" "terraform_state_to_sns" {
  rule      = aws_cloudwatch_event_rule.terraform_state_access.name
  target_id = "SendToSNS"
  arn       = "arn:aws:sns:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:security-alerts-high"

  input_transformer {
    input_paths = {
      eventName    = "$.detail.eventName"
      userIdentity = "$.detail.userIdentity.principalId"
      sourceIP     = "$.detail.sourceIPAddress"
      eventTime    = "$.detail.eventTime"
      bucketName   = "$.detail.requestParameters.bucketName"
      objectKey    = "$.detail.requestParameters.key"
    }

    input_template = <<EOF
{
  "AlarmName": "Terraform State Access Detected",
  "AlarmDescription": "Someone accessed the Terraform state bucket",
  "AWSAccountId": "${data.aws_caller_identity.current.account_id}",
  "NewStateReason": "Terraform state bucket access: <eventName> by <userIdentity> from <sourceIP>",
  "EventDetails": {
    "EventName": "<eventName>",
    "UserIdentity": "<userIdentity>",
    "SourceIP": "<sourceIP>",
    "EventTime": "<eventTime>",
    "BucketName": "<bucketName>",
    "ObjectKey": "<objectKey>"
  },
  "Severity": "HIGH",
  "Resource": "s3://<bucketName>/<objectKey>"
}
EOF
  }
}

# Allow EventBridge to write to CloudWatch Logs
resource "aws_cloudwatch_log_resource_policy" "eventbridge_to_logs" {
  policy_name = "EventBridgeToCloudWatchLogsPolicy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.terraform_state_events.arn}:*"
      }
    ]
  })
}

############################################
# Athena Named Query - Terraform State Access Analysis
############################################
resource "aws_athena_named_query" "terraform_state_access" {
  name        = "terraform-state-access-analysis"
  database    = "security_lake_db"
  query       = <<-EOF
    SELECT
      eventtime,
      eventname,
      useridentity.principalid as user,
      useridentity.arn as user_arn,
      sourceipaddress,
      useragent,
      requestparameters.bucketName as bucket,
      requestparameters.key as object_key,
      responseelements.x_amz_version_id as version_id,
      errorcode,
      errormessage
    FROM cloudtrail_logs
    WHERE
      eventname IN ('GetObject', 'PutObject', 'DeleteObject', 'CopyObject')
      AND requestparameters.bucketName = '${aws_s3_bucket.terraform_state.id}'
      AND year = CAST(year(current_date) AS VARCHAR)
      AND month = CAST(month(current_date) AS VARCHAR)
    ORDER BY eventtime DESC
    LIMIT 1000;
  EOF
  description = "Query to analyze Terraform state bucket access patterns"
}

resource "aws_athena_named_query" "terraform_state_unauthorized_access" {
  name        = "terraform-state-unauthorized-access"
  database    = "security_lake_db"
  query       = <<-EOF
    SELECT
      eventtime,
      eventname,
      useridentity.principalid as user,
      sourceipaddress,
      errorcode,
      errormessage,
      requestparameters.key as object_key
    FROM cloudtrail_logs
    WHERE
      requestparameters.bucketName = '${aws_s3_bucket.terraform_state.id}'
      AND errorcode IS NOT NULL
      AND errorcode IN ('AccessDenied', 'InvalidAccessKeyId', 'SignatureDoesNotMatch')
      AND year = CAST(year(current_date) AS VARCHAR)
      AND month = CAST(month(current_date) AS VARCHAR)
    ORDER BY eventtime DESC;
  EOF
  description = "Detect unauthorized access attempts to Terraform state bucket"
}

data "aws_region" "current" {}

############################################
# Access Logs Bucket
############################################

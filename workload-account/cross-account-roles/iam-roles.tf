############################################
# Workload Account - Cross-Account IAM Roles
# Purpose: Allow security account to access workload resources
# Deploy this in the WORKLOAD account
############################################

############################################
# Data Sources
############################################
data "aws_caller_identity" "current" {}

############################################
# Local Variables
############################################
locals {
  workload_account_id = data.aws_caller_identity.current.account_id
  security_account_id = var.security_account_id # 333333444444

  common_tags = {
    ManagedBy   = "terraform"
    Environment = "production"
    Purpose     = "cross-account-security-access"
  }
}

############################################
# 1. Terraform Execution Role
# Purpose: Allow Terraform to manage workload resources
############################################
resource "aws_iam_role" "terraform_execution" {
  name        = "TerraformExecutionRole"
  description = "Role for Terraform to manage AWS resources"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${var.management_account_id}:root",
            # Add CI/CD pipeline role ARN here
            # "arn:aws:iam::${var.management_account_id}:role/GitHubActionsRole"
          ]
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "terraform-workload-account"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "TerraformExecutionRole"
  })
}

# Attach AdministratorAccess policy
resource "aws_iam_role_policy_attachment" "terraform_admin" {
  role       = aws_iam_role.terraform_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

############################################
# 2. GuardDuty Member Role
# Purpose: Allow security account to manage GuardDuty
############################################
resource "aws_iam_role" "guardduty_member" {
  name        = "GuardDutyMemberRole"
  description = "Role for security account to access GuardDuty findings"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.security_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "guardduty-member-${local.workload_account_id}"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "GuardDutyMemberRole"
    Service = "GuardDuty"
  })
}

# GuardDuty Member Policy
resource "aws_iam_role_policy" "guardduty_member" {
  name = "GuardDutyMemberPolicy"
  role = aws_iam_role.guardduty_member.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "guardduty:GetDetector",
          "guardduty:GetFindings",
          "guardduty:ListFindings",
          "guardduty:GetMemberDetectors"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# 3. Security Hub Member Role
# Purpose: Allow security account to aggregate Security Hub findings
############################################
resource "aws_iam_role" "securityhub_member" {
  name        = "SecurityHubMemberRole"
  description = "Role for security account to access Security Hub findings"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.security_account_id}:root"
        }
        Action = "sts:AssumeRole"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "securityhub.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "SecurityHubMemberRole"
    Service = "SecurityHub"
  })
}

# Security Hub Member Policy
resource "aws_iam_role_policy" "securityhub_member" {
  name = "SecurityHubMemberPolicy"
  role = aws_iam_role.securityhub_member.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "securityhub:GetFindings",
          "securityhub:BatchImportFindings",
          "securityhub:BatchUpdateFindings"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# 4. Config Authorization for Aggregator
# Purpose: Allow security account to aggregate Config data
############################################
resource "aws_config_aggregate_authorization" "security_account" {
  account_id = local.security_account_id
  region     = var.region

  tags = merge(local.common_tags, {
    Name    = "ConfigAggregatorAuthorization"
    Service = "Config"
  })
}

############################################
# 5. Security Lake Query Role
# Purpose: Allow security account to READ/QUERY data FROM this workload account
# Note: This role is assumed BY the security account to access workload resources
############################################
resource "aws_iam_role" "security_lake_query" {
  name        = "SecurityLakeQueryRole"
  description = "Role for security account to query workload account data (S3, CloudWatch, Glue)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.security_account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "SecurityLakeQueryRole"
    Service = "SecurityLake"
  })
}

# Security Lake Query Policy - Allows reading workload account resources
resource "aws_iam_role_policy" "security_lake_query" {
  name = "SecurityLakeQueryPolicy"
  role = aws_iam_role.security_lake_query.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadWorkloadS3Data"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::*",
          "arn:aws:s3:::*/*"
        ]
      },
      {
        Sid    = "QueryWorkloadGlueData"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetDatabases",
          "glue:GetTable",
          "glue:GetTables",
          "glue:GetPartition",
          "glue:GetPartitions"
        ]
        Resource = "*"
      },
      {
        Sid    = "ReadWorkloadCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      },
      {
        Sid    = "QueryAthenaWorkloadData"
        Effect = "Allow"
        Action = [
          "athena:StartQueryExecution",
          "athena:GetQueryExecution",
          "athena:GetQueryResults"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# 6. CloudWatch Logs Cross-Account Role
# Purpose: Send CloudWatch Logs to security account via subscription filters
############################################
resource "aws_iam_role" "cloudwatch_logs_sender" {
  name        = "CloudWatchLogsCrossAccountRole"
  description = "Role for sending CloudWatch Logs to security account via subscription"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "CloudWatchLogsCrossAccountRole"
    Service = "CloudWatch"
  })
}

# CloudWatch Logs Cross-Account Policy
resource "aws_iam_role_policy" "cloudwatch_logs_sender" {
  name = "CloudWatchLogsCrossAccountPolicy"
  role = aws_iam_role.cloudwatch_logs_sender.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords"
        ]
        Resource = "arn:aws:kinesis:${var.region}:${local.security_account_id}:stream/*"
      },
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = "arn:aws:firehose:${var.region}:${local.security_account_id}:deliverystream/*"
      }
    ]
  })
}

############################################
# 7. VPC Flow Logs Role
# Purpose: Send VPC Flow Logs to security account S3 bucket
############################################
resource "aws_iam_role" "vpc_flow_logs" {
  name        = "VPCFlowLogsRole"
  description = "Role for VPC Flow Logs to write to security account S3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "VPCFlowLogsRole"
    Service = "VPCFlowLogs"
  })
}

# VPC Flow Logs Policy - Updated to send to S3
resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "VPCFlowLogsPolicy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DeliverLogsToS3"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::org-vpc-flow-logs-security-${local.security_account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Sid    = "GetBucketLocation"
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::org-vpc-flow-logs-security-${local.security_account_id}"
      },
      {
        Sid    = "DeliverLogsToCloudWatch"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# 8. Detective Member Role
# Purpose: Allow security account to investigate security events
############################################
resource "aws_iam_role" "detective_member" {
  name        = "DetectiveMemberRole"
  description = "Role for security account to access Detective data"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.security_account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "DetectiveMemberRole"
    Service = "Detective"
  })
}

# Detective Member Policy
resource "aws_iam_role_policy" "detective_member" {
  name = "DetectiveMemberPolicy"
  role = aws_iam_role.detective_member.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "detective:GetMembers",
          "detective:ListGraphs",
          "detective:SearchGraph"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# 9. CloudTrail Role
# Purpose: Send CloudTrail logs to security account S3 bucket
############################################
resource "aws_iam_role" "cloudtrail" {
  name        = "CloudTrailRole"
  description = "Role for CloudTrail to write logs to security account S3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "CloudTrailRole"
    Service = "CloudTrail"
  })
}

# CloudTrail Policy
resource "aws_iam_role_policy" "cloudtrail" {
  name = "CloudTrailPolicy"
  role = aws_iam_role.cloudtrail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailCreateLogStream"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:*:log-stream:*"
      }
    ]
  })
}

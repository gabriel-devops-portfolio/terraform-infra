############################################
# Security Account - Cross-Account IAM Roles
# Purpose: Enable cross-account access for security services
############################################

############################################
# Data Sources
############################################
data "aws_caller_identity" "current" {}

data "aws_organizations_organization" "org" {}

############################################
# Local Variables
############################################
locals {
  # Account IDs (update these with actual values)
  security_account_id   = data.aws_caller_identity.current.account_id
  workload_account_id   = var.workload_account_id
  management_account_id = data.aws_organizations_organization.org.master_account_id

  common_tags = {
    ManagedBy   = "terraform"
    Environment = "security"
    Purpose     = "cross-account-access"
  }
}

############################################
# 1. Terraform Execution Role
# Purpose: Allow Terraform to manage resources
############################################
resource "aws_iam_role" "terraform_execution" {
  name        = "TerraformExecutionRole"
  description = "Role for Terraform to manage AWS resources with cross-account state access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${local.management_account_id}:root",
            # Add CI/CD pipeline role ARN here if using GitHub Actions, GitLab, etc.
            # "arn:aws:iam::${local.workload_account_id}:role/GitHubActionsRole"
          ]
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "terraform-security-account"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "TerraformExecutionRole"
  })
}

# Attach AdministratorAccess policy (for Terraform to manage all resources)
resource "aws_iam_role_policy_attachment" "terraform_admin" {
  role       = aws_iam_role.terraform_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

############################################
# 2. GuardDuty Organization Admin Role
# Purpose: Enable GuardDuty threat detection across organization
############################################
resource "aws_iam_role" "guardduty_admin" {
  name        = "GuardDutyOrganizationAdminRole"
  description = "Role for GuardDuty to manage organization-wide threat detection"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
    Name    = "GuardDutyOrganizationAdminRole"
    Service = "GuardDuty"
  })
}

# GuardDuty Admin Policy
resource "aws_iam_role_policy" "guardduty_admin" {
  name = "GuardDutyAdminPolicy"
  role = aws_iam_role.guardduty_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "guardduty:*",
          "organizations:DescribeOrganization",
          "organizations:ListAccounts",
          "organizations:DescribeAccount"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# 3. Security Hub Organization Admin Role
# Purpose: Aggregate security findings from all accounts
############################################
resource "aws_iam_role" "securityhub_admin" {
  name        = "SecurityHubOrganizationAdminRole"
  description = "Role for Security Hub to aggregate findings across organization"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
    Name    = "SecurityHubOrganizationAdminRole"
    Service = "SecurityHub"
  })
}

# Security Hub Admin Policy
resource "aws_iam_role_policy" "securityhub_admin" {
  name = "SecurityHubAdminPolicy"
  role = aws_iam_role.securityhub_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "securityhub:*",
          "organizations:DescribeOrganization",
          "organizations:ListAccounts",
          "organizations:DescribeAccount"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# 4. Config Aggregator Role
# Purpose: Aggregate Config compliance data from all accounts
############################################
resource "aws_iam_role" "config_aggregator" {
  name        = "ConfigAggregatorRole"
  description = "Role for AWS Config to aggregate compliance data"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "ConfigAggregatorRole"
    Service = "Config"
  })
}

# Config Aggregator Policy
resource "aws_iam_role_policy" "config_aggregator" {
  name = "ConfigAggregatorPolicy"
  role = aws_iam_role.config_aggregator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "config:Put*",
          "config:Get*",
          "config:List*",
          "config:Describe*",
          "config:BatchGet*",
          "config:Select*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "organizations:ListAccounts",
          "organizations:DescribeAccount",
          "organizations:DescribeOrganization"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# 5. Security Lake Role
# Purpose: Collect and normalize security logs in OCSF format
############################################
resource "aws_iam_role" "security_lake" {
  name        = "SecurityLakeRole"
  description = "Role for Security Lake to collect security logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "securitylake.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "SecurityLakeRole"
    Service = "SecurityLake"
  })
}

# Security Lake Policy
resource "aws_iam_role_policy" "security_lake" {
  name = "SecurityLakePolicy"
  role = aws_iam_role.security_lake.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "glue:*",
          "lakeformation:*"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# 6. Security Lake Subscriber Role
# Purpose: Allow querying Security Lake data
############################################
resource "aws_iam_role" "security_lake_subscriber" {
  name        = "SecurityLakeSubscriberRole"
  description = "Role for Security Lake subscribers (Athena, OpenSearch)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "athena.amazonaws.com",
            "opensearchservice.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "SecurityLakeSubscriberRole"
    Service = "SecurityLake"
  })
}

# Security Lake Subscriber Policy
resource "aws_iam_role_policy" "security_lake_subscriber" {
  name = "SecurityLakeSubscriberPolicy"
  role = aws_iam_role.security_lake_subscriber.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "glue:GetTable",
          "glue:GetDatabase"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# 7. Detective Admin Role
# Purpose: Security investigation with graph analysis
############################################
resource "aws_iam_role" "detective_admin" {
  name        = "DetectiveOrganizationAdminRole"
  description = "Role for Detective to analyze security data"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "detective.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name    = "DetectiveOrganizationAdminRole"
    Service = "Detective"
  })
}

# Detective Admin Policy
resource "aws_iam_role_policy" "detective_admin" {
  name = "DetectiveAdminPolicy"
  role = aws_iam_role.detective_admin.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "detective:*",
          "organizations:DescribeOrganization",
          "organizations:ListAccounts"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# 8. CloudWatch Logs Cross-Account Role
# Purpose: Receive logs from workload account
############################################
resource "aws_iam_role" "cloudwatch_logs_receiver" {
  name        = "CloudWatchLogsReceiverRole"
  description = "Role for receiving CloudWatch Logs from workload account"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.workload_account_id}:root"
        }
        Action = "sts:AssumeRole"
      },
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
    Name    = "CloudWatchLogsReceiverRole"
    Service = "CloudWatch"
  })
}

# CloudWatch Logs Receiver Policy
resource "aws_iam_role_policy" "cloudwatch_logs_receiver" {
  name = "CloudWatchLogsReceiverPolicy"
  role = aws_iam_role.cloudwatch_logs_receiver.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:${local.security_account_id}:log-group:*"
      }
    ]
  })
}

############################################
# 9. Athena Query Execution Role
# Purpose: Query security logs in Security Lake
############################################
resource "aws_iam_role" "athena_query" {
  name        = "AthenaSecurityQueryRole"
  description = "Role for running Athena queries on security logs"

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
    Name    = "AthenaSecurityQueryRole"
    Service = "Athena"
  })
}

# Athena Query Policy
resource "aws_iam_role_policy" "athena_query" {
  name = "AthenaSecurityQueryPolicy"
  role = aws_iam_role.athena_query.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "athena:*",
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:PutObject"
        ]
        Resource = "*"
      }
    ]
  })
}

############################################
# 10. OpenSearch Service Role
# Purpose: Access logs for visualization
############################################
resource "aws_iam_role" "opensearch" {
  name        = "OpenSearchSecurityRole"
  description = "Role for OpenSearch to access security logs"

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
    Name    = "OpenSearchSecurityRole"
    Service = "OpenSearch"
  })
}

# OpenSearch Policy
resource "aws_iam_role_policy" "opensearch" {
  name = "OpenSearchSecurityPolicy"
  role = aws_iam_role.opensearch.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })
}

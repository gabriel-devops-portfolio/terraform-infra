############################
# AWS Organization
############################
resource "aws_organizations_organization" "org" {
  feature_set = "ALL"

  aws_service_access_principals = [
    # Security and Compliance
    "cloudtrail.amazonaws.com",      # Organization-wide audit logging
    "config.amazonaws.com",          # Multi-account compliance monitoring
    "guardduty.amazonaws.com",       # Threat detection
    "securityhub.amazonaws.com",     # Security findings aggregation
    "securitylake.amazonaws.com",    # Security data lake
    "access-analyzer.amazonaws.com", # IAM Access Analyzer
    "detective.amazonaws.com",       # Security investigation
    "inspector2.amazonaws.com",      # Vulnerability management
    "macie.amazonaws.com",           # Sensitive data discovery

    # Identity and Access Management
    "sso.amazonaws.com", # AWS IAM Identity Center (SSO)

    # # Monitoring and Analytics
    # "athena.amazonaws.com",            # SQL queries on logs
    # "opensearchservice.amazonaws.com", # OpenSearch Service
    # # "logs.amazonaws.com",              # CloudWatch Logs

    # # Backup and Recovery
    # "backup.amazonaws.com", # AWS Backup

    # # Compute Optimizer (Cost Optimization)
    # "compute-optimizer.amazonaws.com", # Resource optimization recommendations

    # # Service Catalog (Governance)
    # "servicecatalog.amazonaws.com", # Approved product catalog

    # # RAM (Resource Access Manager)
    # "ram.amazonaws.com", # Cross-account resource sharing

    # # License Manager
    # "license-manager.amazonaws.com", # Software license tracking

    # # Firewall Manager (Network Security)
    # "fms.amazonaws.com", # Centralized firewall management

    # # Health
    # "health.amazonaws.com" # AWS Health events
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY"
  ]
}

############################
# Organizational Units
############################

# Security OU - For security and audit accounts
resource "aws_organizations_organizational_unit" "security" {
  name      = "security-ou"
  parent_id = aws_organizations_organization.org.roots[0].id
}

# Workloads OU - For application workload accounts
resource "aws_organizations_organizational_unit" "workloads" {
  name      = "workloads-ou"
  parent_id = aws_organizations_organization.org.roots[0].id
}

############################
# Security Account
############################
resource "aws_organizations_account" "security" {
  name      = "security-account"
  email     = var.security_account_email
  parent_id = aws_organizations_organizational_unit.security.id

  role_name = "OrganizationAccountAccessRole"

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "security-account"
    Environment = "security"
    Purpose     = "centralized-security-logging-audit"
    ManagedBy   = "terraform"
  }
}

############################
# Workload Account
############################
resource "aws_organizations_account" "workload" {
  name      = "workload-account"
  email     = var.workload_account_email
  parent_id = aws_organizations_organizational_unit.workloads.id

  role_name = "OrganizationAccountAccessRole"

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "workload-account"
    Environment = "production"
    Purpose     = "application-workloads-eks"
    ManagedBy   = "terraform"
  }
}

############################
# Service Control Policies (SCPs)
############################

# Deny leaving organization
resource "aws_organizations_policy" "deny_leave_org" {
  name        = "DenyLeaveOrganization"
  description = "Prevent accounts from leaving the organization"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyLeaveOrganization"
        Effect = "Deny"
        Action = [
          "organizations:LeaveOrganization"
        ]
        Resource = "*"
      }
    ]
  })
}

# Deny root account usage
resource "aws_organizations_policy" "deny_root_usage" {
  name        = "DenyRootAccountUsage"
  description = "Prevent root account usage except for specific actions"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyRootAccountUsage"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
        }
      }
    ]
  })
}

# Require MFA for sensitive actions
resource "aws_organizations_policy" "require_mfa" {
  name        = "RequireMFAForSensitiveActions"
  description = "Require MFA for IAM user/role modifications"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyIAMChangesWithoutMFA"
        Effect = "Deny"
        Action = [
          "iam:DeleteUser",
          "iam:DeleteRole",
          "iam:DeletePolicy",
          "iam:AttachUserPolicy",
          "iam:AttachRolePolicy",
          "iam:PutUserPolicy",
          "iam:PutRolePolicy"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}

# Enforce encryption in transit (HTTPS/TLS)
resource "aws_organizations_policy" "enforce_encryption_in_transit" {
  name        = "EnforceEncryptionInTransit"
  description = "Deny unencrypted S3 and ELB traffic"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyUnencryptedS3"
        Effect   = "Deny"
        Action   = "s3:*"
        Resource = "*"
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "DenyInsecureELBListeners"
        Effect = "Deny"
        Action = [
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:ModifyListener"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "elasticloadbalancing:Protocol" = ["HTTPS", "TLS"]
          }
        }
      }
    ]
  })
}

############################
# SCP Attachments
############################

# Attach deny leave org to all accounts
resource "aws_organizations_policy_attachment" "deny_leave_org_root" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = aws_organizations_organization.org.roots[0].id
}

# Attach deny root usage to workloads OU
resource "aws_organizations_policy_attachment" "deny_root_workloads" {
  policy_id = aws_organizations_policy.deny_root_usage.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# Attach require MFA to workloads OU
resource "aws_organizations_policy_attachment" "require_mfa_workloads" {
  policy_id = aws_organizations_policy.require_mfa.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

# Attach encryption in transit to all accounts
resource "aws_organizations_policy_attachment" "enforce_encryption_root" {
  policy_id = aws_organizations_policy.enforce_encryption_in_transit.id
  target_id = aws_organizations_organization.org.roots[0].id
}

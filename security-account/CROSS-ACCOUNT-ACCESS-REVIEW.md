# Security Account Cross-Account Access Review

## 📋 Executive Summary

**Review Date**: 2024-01-05
**Accounts Reviewed**:
- **Security Account**: 404068503087 (assumed based on bucket policy)
- **Workload Account**: 290793900072 (assumed based on bucket policy)
- **Management Account**: (Account IDs not yet determined)

**Overall Status**: ⚠️ **PARTIALLY CONFIGURED** - Requires immediate attention

---

## ✅ What's Currently Configured

### 1. AWS Organizations Setup
- ✅ OrganizationAccountAccessRole created in both member accounts
- ✅ Security services enabled at organization level:
  - CloudTrail, Config, GuardDuty, Security Hub, Security Lake
  - IAM Access Analyzer, Detective, Inspector, Macie
- ✅ Service Control Policies (SCPs) properly configured

### 2. Terraform State Backend (Security Account)
- ✅ S3 bucket: `org-workload-terraform-state-prod`
- ✅ Bucket policy allows TerraformExecutionRole from both accounts
- ✅ DynamoDB table for state locking
- ✅ Versioning enabled
- ✅ Encryption enabled (AES256)
- ✅ Logging enabled
- ✅ Public access blocked

### 3. AWS Config (Security Account)
- ✅ Config recorder configured
- ✅ Delivery channel to S3
- ✅ IAM role: AWSConfigRecorderRole
- ✅ Drift detection rules configured

---

## ❌ Critical Gaps - Requires Immediate Action

### 1. TerraformExecutionRole (NOT CREATED)
**Issue**: The role is referenced in bucket policies and backend configs but doesn't exist

**Impact**: Terraform cannot assume the role to access state bucket

**Required in**:
- ✅ Security Account: `arn:aws:iam::404068503087:role/TerraformExecutionRole`
- ✅ Workload Account: `arn:aws:iam::290793900072:role/TerraformExecutionRole`

**Permissions Needed**:
- S3 read/write to state bucket
- DynamoDB read/write to lock table
- Assume role from management account or CI/CD pipeline

---

### 2. GuardDuty Cross-Account Access (NOT CONFIGURED)
**Issue**: Security account cannot aggregate GuardDuty findings from workload account

**Required Roles**:

#### In Security Account:
```hcl
# GuardDuty Administrator Role
resource "aws_iam_role" "guardduty_admin" {
  name = "GuardDutyOrganizationAdminRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "guardduty.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}
```

#### In Workload Account:
```hcl
# GuardDuty Member Role
resource "aws_iam_role" "guardduty_member" {
  name = "GuardDutyMemberRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::404068503087:root"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = "guardduty-security-account"
        }
      }
    }]
  })
}
```

---

### 3. Security Hub Cross-Account Access (NOT CONFIGURED)
**Issue**: Security account cannot aggregate security findings from workload account

**Required Roles**:

#### In Security Account:
```hcl
# Security Hub Administrator Role
resource "aws_iam_role" "securityhub_admin" {
  name = "SecurityHubOrganizationAdminRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "securityhub.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}
```

#### In Workload Account:
```hcl
# Security Hub Member Role
resource "aws_iam_role" "securityhub_member" {
  name = "SecurityHubMemberRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::404068503087:root"
      }
      Action = "sts:AssumeRole"
    }]
  })
}
```

---

### 4. Config Aggregator Cross-Account Access (NOT CONFIGURED)
**Issue**: Security account cannot aggregate Config data from workload account

**Required Roles**:

#### In Security Account:
```hcl
# Config Aggregator Role
resource "aws_iam_role" "config_aggregator" {
  name = "ConfigAggregatorRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}
```

#### In Workload Account:
```hcl
# Config Authorization for Aggregator
resource "aws_config_aggregate_authorization" "security_account" {
  account_id = "404068503087"  # Security account
  region     = "us-east-1"
}
```

---

### 5. CloudTrail Cross-Account Access (NOT CONFIGURED)
**Issue**: Workload account cannot send CloudTrail logs to security account S3 bucket

**Required Resources**:

#### In Security Account:
```hcl
# CloudTrail S3 Bucket
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "org-cloudtrail-logs-security-account"
}

# Bucket Policy allowing workload account to write logs
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
            "aws:SourceAccount" = ["404068503087", "290793900072"]
          }
        }
      }
    ]
  })
}
```

#### In Workload Account:
```hcl
# CloudTrail Trail pointing to security account bucket
resource "aws_cloudtrail" "workload_trail" {
  name           = "workload-account-trail"
  s3_bucket_name = "org-cloudtrail-logs-security-account"

  # Multi-region trail
  is_multi_region_trail = true

  # Include global services (IAM, etc.)
  include_global_service_events = true

  # Enable log file validation
  enable_log_file_validation = true
}
```

---

### 6. Security Lake Cross-Account Access (NOT CONFIGURED)
**Issue**: Security Lake cannot collect logs from workload account

**Required Roles**:

#### In Security Account:
```hcl
# Security Lake Role
resource "aws_iam_role" "security_lake" {
  name = "SecurityLakeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "securitylake.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# Security Lake Subscriber Role
resource "aws_iam_role" "security_lake_subscriber" {
  name = "SecurityLakeSubscriberRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "securitylake.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}
```

#### In Workload Account:
```hcl
# Security Lake Query Access Role
resource "aws_iam_role" "security_lake_query" {
  name = "SecurityLakeQueryRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::404068503087:root"
      }
      Action = "sts:AssumeRole"
    }]
  })
}
```

---

### 7. VPC Flow Logs to Security Account (NOT CONFIGURED)
**Issue**: Workload VPC flow logs cannot be sent to security account

**Required Resources**:

#### In Security Account:
```hcl
# VPC Flow Logs S3 Bucket
resource "aws_s3_bucket" "vpc_flow_logs" {
  bucket = "org-vpc-flow-logs-security-account"
}

# Bucket Policy
resource "aws_s3_bucket_policy" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "AWSLogDeliveryWrite"
      Effect = "Allow"
      Principal = { Service = "delivery.logs.amazonaws.com" }
      Action = "s3:PutObject"
      Resource = "${aws_s3_bucket.vpc_flow_logs.arn}/*"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = ["290793900072"]
        }
      }
    }]
  })
}
```

---

### 8. KMS Key Cross-Account Access (NOT CONFIGURED)
**Issue**: Workload account cannot use security account KMS keys for encryption

**Required Resources**:

#### In Security Account:
```hcl
# KMS Key for cross-account encryption
resource "aws_kms_key" "security_logs" {
  description             = "KMS key for security logs encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::404068503087:root" }
        Action = "kms:*"
        Resource = "*"
      },
      {
        Sid = "Allow workload account to use key"
        Effect = "Allow"
        Principal = { AWS = "arn:aws:iam::290793900072:root" }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}
```

---

## 🔐 Trust Relationship Summary

### Security Account Trusts:
| Service | Trust Principal | Purpose |
|---------|----------------|---------|
| GuardDuty | guardduty.amazonaws.com | Threat detection |
| Security Hub | securityhub.amazonaws.com | Findings aggregation |
| Config | config.amazonaws.com | Compliance monitoring |
| Security Lake | securitylake.amazonaws.com | Data lake collection |
| CloudTrail | cloudtrail.amazonaws.com | Audit logging |

### Workload Account Trusts:
| Role | Trust Principal | Purpose |
|------|----------------|---------|
| GuardDutyMemberRole | arn:aws:iam::404068503087:root | Allow GuardDuty scanning |
| SecurityHubMemberRole | arn:aws:iam::404068503087:root | Send findings to Security Hub |
| SecurityLakeQueryRole | arn:aws:iam::404068503087:root | Allow log aggregation |
| TerraformExecutionRole | Management account or CI/CD | Terraform operations |

---

## 📊 Cross-Account S3 Bucket Access Matrix

### Security Account S3 Buckets:
| Bucket Name | Purpose | Workload Account Access | Encryption |
|-------------|---------|------------------------|------------|
| org-workload-terraform-state-prod | Terraform state | ✅ READ/WRITE | ✅ AES256 |
| org-cloudtrail-logs-security-account | CloudTrail logs | ✅ WRITE (via CloudTrail) | ❌ NOT CREATED |
| org-vpc-flow-logs-security-account | VPC Flow Logs | ✅ WRITE (via Log Delivery) | ❌ NOT CREATED |
| org-security-lake-data | Security Lake | ✅ READ (via Security Lake) | ❌ NOT CREATED |

---

## 🔄 Data Flow Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                      Workload Account (290793900072)               │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │
│  │  CloudTrail  │  │  VPC Flow    │  │  GuardDuty   │            │
│  │    Logs      │  │    Logs      │  │   Findings   │            │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘            │
│         │                 │                 │                       │
│         │                 │                 │                       │
│         │ (s3:PutObject)  │ (s3:PutObject)  │ (API Call)          │
│         │                 │                 │                       │
└─────────┼─────────────────┼─────────────────┼───────────────────────┘
          │                 │                 │
          │ IAM Trust       │ Bucket Policy   │ IAM Trust
          │ Relationship    │ Allows Write    │ Relationship
          │                 │                 │
          ▼                 ▼                 ▼
┌────────────────────────────────────────────────────────────────────┐
│                    Security Account (404068503087)                 │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                      S3 Buckets                               │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │  │
│  │  │  CloudTrail  │  │  VPC Flow    │  │ Security Lake│      │  │
│  │  │    Bucket    │  │    Bucket    │  │    Bucket    │      │  │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │  │
│  └─────────┼──────────────────┼──────────────────┼──────────────┘  │
│            │                  │                  │                  │
│            └──────────────────┴──────────────────┘                  │
│                               │                                     │
│  ┌────────────────────────────┼─────────────────────────────────┐  │
│  │              Security Services (Aggregators)                  │  │
│  │                            │                                   │  │
│  │  ┌──────────────┐  ┌──────▼──────┐  ┌──────────────┐        │  │
│  │  │  GuardDuty   │  │ Security Hub│  │    Athena    │        │  │
│  │  │   Admin      │  │    Admin    │  │   Queries    │        │  │
│  │  └──────────────┘  └─────────────┘  └──────────────┘        │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

---

## 📝 Action Items - Priority Order

### 🔴 CRITICAL - Must Complete Immediately
1. **Create TerraformExecutionRole in both accounts**
   - Security Account: 404068503087
   - Workload Account: 290793900072
   - Must trust management account or CI/CD pipeline

2. **Create GuardDuty cross-account roles**
   - Enable GuardDuty in both accounts
   - Designate security account as GuardDuty administrator
   - Add workload account as member

3. **Create Security Hub cross-account roles**
   - Enable Security Hub in both accounts
   - Designate security account as Security Hub administrator
   - Aggregate findings from workload account

### 🟡 HIGH PRIORITY - Complete This Week
4. **Configure CloudTrail centralized logging**
   - Create S3 bucket in security account
   - Configure bucket policy for cross-account write
   - Configure KMS key for encryption
   - Create trail in workload account pointing to security bucket

5. **Configure Config Aggregator**
   - Create aggregator in security account
   - Authorize security account in workload account
   - Verify aggregation working

6. **Configure VPC Flow Logs to security account**
   - Create S3 bucket in security account
   - Configure bucket policy
   - Update workload VPC flow logs to use security account bucket

### 🟢 MEDIUM PRIORITY - Complete This Month
7. **Deploy Security Lake**
   - Enable Security Lake in security account
   - Configure subscribers for CloudTrail, VPC Flow, Route53 logs
   - Create Athena queries for OCSF data

8. **Deploy OpenSearch for log visualization**
   - Create OpenSearch domain in security account
   - Configure index patterns for CloudTrail, VPC Flow, Security Hub
   - Create dashboards for security monitoring

9. **Configure Detective for investigation**
   - Enable Detective in security account
   - Add workload account as member
   - Configure data source (GuardDuty findings)

### 🔵 LOW PRIORITY - Complete This Quarter
10. **Deploy Macie for sensitive data discovery**
    - Enable Macie in both accounts
    - Configure classification jobs for S3 buckets
    - Integrate findings with Security Hub

11. **Deploy Inspector for vulnerability scanning**
    - Enable Inspector in both accounts
    - Configure EC2 and ECR scanning
    - Integrate findings with Security Hub

12. **Configure automated remediation**
    - Create EventBridge rules for critical findings
    - Create Lambda functions for automated response
    - Configure SNS notifications to Slack/PagerDuty

---

## 🎯 Success Criteria

- [ ] TerraformExecutionRole exists and working in both accounts
- [ ] GuardDuty administrator-member relationship established
- [ ] Security Hub aggregating findings from all accounts
- [ ] CloudTrail logs centralized in security account
- [ ] Config aggregator pulling compliance data from all accounts
- [ ] VPC Flow Logs centralized in security account
- [ ] Security Lake operational with OCSF format logs
- [ ] Athena queries working on security data
- [ ] OpenSearch dashboards displaying real-time security events
- [ ] KMS keys properly shared for cross-account encryption

---

## 📚 Next Steps

1. **Review this document** with security and operations teams
2. **Prioritize action items** based on compliance requirements
3. **Create Terraform modules** for security account infrastructure
4. **Test cross-account access** before production deployment
5. **Document runbooks** for security incident response
6. **Schedule regular reviews** of cross-account access (quarterly)

---

## 🔗 Related Documentation

- [SECURITY-SERVICES-GUIDE.md](../management-account/SECURITY-SERVICES-GUIDE.md)
- [DR-IMPLEMENTATION-COMPLETE.md](../workload-account/environments/production/DR-IMPLEMENTATION-COMPLETE.md)
- [ENTERPRISE-COMPLIANCE-ASSESSMENT.md](../ENTERPRISE-COMPLIANCE-ASSESSMENT.md)
- AWS Organizations Best Practices
- AWS Security Hub Implementation Guide
- AWS CloudTrail Best Practices

---

**Document Version**: 1.0
**Last Updated**: 2024-01-05
**Next Review Date**: 2024-04-05

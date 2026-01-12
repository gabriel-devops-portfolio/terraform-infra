# Security Account - Cross-Account Roles and Infrastructure

## 📋 Overview

This directory contains Terraform configuration for setting up comprehensive cross-account access between the **Security Account** and member accounts (Workload, Management) in your AWS Organization.

**Security Account ID**: `404068503087` (assumed)
**Primary Region**: `us-east-1`
**Purpose**: Centralized security monitoring, logging, and compliance

---

## 🏗️ Infrastructure Components

### IAM Roles (`iam-roles.tf`)
Creates 10 cross-account IAM roles:

1. **TerraformExecutionRole** - Terraform infrastructure management
2. **GuardDutyOrganizationAdminRole** - Threat detection across organization
3. **SecurityHubOrganizationAdminRole** - Centralized security findings
4. **ConfigAggregatorRole** - Compliance data aggregation
5. **SecurityLakeRole** - Security data lake in OCSF format
6. **SecurityLakeSubscriberRole** - Query Security Lake data
7. **DetectiveOrganizationAdminRole** - Security investigation
8. **CloudWatchLogsReceiverRole** - Receive logs from member accounts
9. **AthenaSecurityQueryRole** - Query security logs with SQL
10. **OpenSearchSecurityRole** - Log visualization and alerting

### S3 Buckets (`s3-buckets.tf`)
Creates 4 centralized logging buckets:

1. **org-cloudtrail-logs-security-{account-id}**
   - Purpose: CloudTrail logs from all accounts
   - Retention: 7 years
   - Lifecycle: 90d → Standard-IA, 180d → Glacier
   - Encryption: KMS (aws_kms_key.security_logs)

2. **org-vpc-flow-logs-security-{account-id}**
   - Purpose: VPC Flow Logs from workload accounts
   - Retention: 1 year
   - Lifecycle: 30d → Standard-IA, 90d → Glacier
   - Encryption: KMS (aws_kms_key.security_logs)

3. **org-security-lake-data-{account-id}**
   - Purpose: Security Lake data in OCSF format
   - Retention: 2 years
   - Lifecycle: 90d → Standard-IA
   - Encryption: KMS (aws_kms_key.security_logs)

4. **org-athena-query-results-{account-id}**
   - Purpose: Athena query output
   - Retention: 30 days (auto-cleanup)
   - Encryption: AES256

### KMS Keys (`kms.tf`)
Creates 3 KMS keys for cross-account encryption:

1. **security-logs** (alias: `alias/security-logs`)
   - Purpose: Encrypt CloudTrail, VPC Flow, Security Lake logs
   - Cross-account access: Workload, Management accounts
   - Key rotation: Enabled
   - Services: CloudTrail, VPC Flow Logs, Security Lake, Athena, OpenSearch

2. **guardduty** (alias: `alias/guardduty`)
   - Purpose: Encrypt GuardDuty findings
   - Service: GuardDuty
   - Key rotation: Enabled

3. **securityhub** (alias: `alias/securityhub`)
   - Purpose: Encrypt Security Hub findings
   - Service: Security Hub
   - Key rotation: Enabled

---

## 🚀 Deployment Guide

### Prerequisites

1. **AWS Organizations** configured with:
   - Management account
   - Security account (this account)
   - Workload account

2. **Service Access Principals** enabled in management account:
   - cloudtrail.amazonaws.com
   - config.amazonaws.com
   - guardduty.amazonaws.com
   - securityhub.amazonaws.com
   - securitylake.amazonaws.com
   - detective.amazonaws.com

3. **Terraform State Backend** configured:
   - S3 bucket: `org-workload-terraform-state-prod`
   - DynamoDB table: `terraform-locks-prod`

### Step 1: Update Variables

Edit `variables.tf` with actual account IDs:

```hcl
variable "workload_account_id" {
  default = "YOUR_WORKLOAD_ACCOUNT_ID"  # Replace 290793900072
}
```

### Step 2: Initialize Terraform

```bash
cd /path/to/security-account/cross-account-roles
terraform init
```

### Step 3: Review Plan

```bash
terraform plan
```

**Expected Resources**: 28 resources to create
- 10 IAM roles
- 10 IAM role policies
- 4 S3 buckets
- 3 KMS keys
- 1 Config authorization

### Step 4: Apply Configuration

```bash
terraform apply
```

### Step 5: Verify Deployment

Check outputs:
```bash
terraform output
```

You should see ARNs for all roles and a summary.

### Step 6: Enable Security Services

After roles are created, enable these services:

1. **GuardDuty**:
   ```bash
   aws guardduty enable-organization-admin-account \
     --admin-account-id 404068503087 \
     --region us-east-1
   ```

2. **Security Hub**:
   ```bash
   aws securityhub enable-organization-admin-account \
     --admin-account-id 404068503087 \
     --region us-east-1
   ```

3. **Security Lake**:
   ```bash
   aws securitylake enable-organization-admin-account \
     --admin-account-id 404068503087 \
     --region us-east-1
   ```

---

## 🔐 Trust Relationships

### Security Account Trusts

| Role | Trusted Principal | Purpose |
|------|-------------------|---------|
| GuardDutyOrganizationAdminRole | guardduty.amazonaws.com | Threat detection |
| SecurityHubOrganizationAdminRole | securityhub.amazonaws.com | Findings aggregation |
| ConfigAggregatorRole | config.amazonaws.com | Compliance monitoring |
| SecurityLakeRole | securitylake.amazonaws.com | Data lake collection |
| DetectiveOrganizationAdminRole | detective.amazonaws.com | Security investigation |

### Cross-Account Access

| Source Account | Target Account | Role | Permission |
|----------------|----------------|------|------------|
| Workload (290793900072) | Security (404068503087) | CloudTrail | s3:PutObject to cloudtrail-logs bucket |
| Workload (290793900072) | Security (404068503087) | VPC Flow Logs | s3:PutObject to vpc-flow-logs bucket |
| Security (404068503087) | Workload (290793900072) | GuardDutyMemberRole | Read GuardDuty findings |
| Security (404068503087) | Workload (290793900072) | SecurityHubMemberRole | Read Security Hub findings |

---

## 📊 Data Flow Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                   Workload Account (290793900072)              │
│                                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │CloudTrail│  │VPC Flow  │  │GuardDuty │  │SecurityHub│      │
│  │  Logs    │  │  Logs    │  │ Findings │  │  Findings │      │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘      │
│       │             │              │              │             │
│       │ (S3 Write)  │ (S3 Write)  │ (API Call)  │ (API Call) │
│       │             │              │              │             │
└───────┼─────────────┼──────────────┼──────────────┼─────────────┘
        │             │              │              │
        │ KMS Encrypt │ KMS Encrypt  │ IAM Trust   │ IAM Trust
        │             │              │              │
        ▼             ▼              ▼              ▼
┌────────────────────────────────────────────────────────────────┐
│                 Security Account (404068503087)                │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   S3 Buckets (Encrypted)                  │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │  │
│  │  │CloudTrail│  │VPC Flow  │  │Security  │              │  │
│  │  │  Logs    │  │  Logs    │  │  Lake    │              │  │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘              │  │
│  └───────┼──────────────┼──────────────┼────────────────────┘  │
│          │              │              │                        │
│          └──────────────┴──────────────┘                        │
│                         │                                       │
│  ┌──────────────────────┼───────────────────────────────────┐  │
│  │            Security Services (Analysis)                   │  │
│  │                     │                                     │  │
│  │         ┌───────────┼───────────┐                        │  │
│  │         │           │           │                         │  │
│  │         ▼           ▼           ▼                         │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │  │
│  │  │ Athena   │  │OpenSearch│  │Security  │              │  │
│  │  │ Queries  │  │Dashboard │  │   Hub    │              │  │
│  │  └──────────┘  └──────────┘  └────┬─────┘              │  │
│  │                                    │                     │  │
│  │                                    ▼                     │  │
│  │                            ┌───────────────┐            │  │
│  │                            │  Detective    │            │  │
│  │                            │ Investigation │            │  │
│  │                            └───────────────┘            │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

---

## 🧪 Testing Cross-Account Access

### Test 1: Terraform Role
```bash
# From management or CI/CD account
aws sts assume-role \
  --role-arn arn:aws:iam::404068503087:role/TerraformExecutionRole \
  --role-session-name test-session \
  --external-id terraform-security-account
```

### Test 2: CloudTrail Bucket Access
```bash
# From workload account, test writing to CloudTrail bucket
aws s3 cp test-log.json s3://org-cloudtrail-logs-security-404068503087/test/
```

### Test 3: GuardDuty Cross-Account
```bash
# From security account, verify GuardDuty admin status
aws guardduty list-organization-admin-accounts
```

### Test 4: Security Hub Cross-Account
```bash
# From security account, verify Security Hub admin status
aws securityhub get-administrator-account
```

---

## 📝 Outputs

After successful deployment, you'll get these outputs:

```hcl
Outputs:

terraform_execution_role_arn = "arn:aws:iam::404068503087:role/TerraformExecutionRole"
guardduty_admin_role_arn = "arn:aws:iam::404068503087:role/GuardDutyOrganizationAdminRole"
securityhub_admin_role_arn = "arn:aws:iam::404068503087:role/SecurityHubOrganizationAdminRole"
config_aggregator_role_arn = "arn:aws:iam::404068503087:role/ConfigAggregatorRole"
security_lake_role_arn = "arn:aws:iam::404068503087:role/SecurityLakeRole"
detective_admin_role_arn = "arn:aws:iam::404068503087:role/DetectiveOrganizationAdminRole"

cross_account_roles_summary = {
  terraform_execution = {
    arn = "arn:aws:iam::404068503087:role/TerraformExecutionRole"
    name = "TerraformExecutionRole"
  }
  guardduty_admin = {
    arn = "arn:aws:iam::404068503087:role/GuardDutyOrganizationAdminRole"
    name = "GuardDutyOrganizationAdminRole"
  }
  # ... more roles
}
```

---

## 🔧 Troubleshooting

### Issue: "Access Denied" when assuming role

**Solution**: Check trust policy allows your account:
```bash
aws iam get-role --role-name TerraformExecutionRole
```

### Issue: "Bucket policy doesn't allow cross-account write"

**Solution**: Verify bucket policy includes workload account ID:
```bash
aws s3api get-bucket-policy --bucket org-cloudtrail-logs-security-404068503087
```

### Issue: "KMS key access denied"

**Solution**: Check KMS key policy allows cross-account usage:
```bash
aws kms get-key-policy --key-id alias/security-logs --policy-name default
```

### Issue: "GuardDuty delegation failed"

**Solution**: Verify AWS Organizations service access:
```bash
aws organizations list-aws-service-access-for-organization
```

---

## 🔄 Update Process

To update roles or policies:

1. Modify Terraform files
2. Run `terraform plan` to review changes
3. Run `terraform apply` to apply changes
4. Verify with `terraform output`

---

## 🔗 Related Resources

- **Workload Account Roles**: `../workload-account/cross-account-roles/`
- **Security Services Guide**: `../management-account/SECURITY-SERVICES-GUIDE.md`
- **Cross-Account Access Review**: `../CROSS-ACCOUNT-ACCESS-REVIEW.md`
- **DR Implementation**: `../workload-account/environments/production/DR-IMPLEMENTATION-COMPLETE.md`

---

## 📚 AWS Documentation

- [Cross-Account Access Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_common-scenarios_aws-accounts.html)
- [GuardDuty Multi-Account](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_organizations.html)
- [Security Hub Multi-Account](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-accounts.html)
- [Security Lake](https://docs.aws.amazon.com/security-lake/latest/userguide/what-is-security-lake.html)
- [CloudTrail Organization Trails](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/creating-trail-organization.html)

---

**Last Updated**: 2024-01-05
**Terraform Version**: >= 1.5.0
**AWS Provider Version**: ~> 5.0

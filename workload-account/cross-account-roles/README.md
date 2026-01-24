# Workload Account - Cross-Account Roles

## 📋 Overview

This directory contains Terraform configuration for creating IAM roles in the **Workload Account** that allow the **Security Account** to access security services and aggregate logs/findings.

**Workload Account ID**: `555555666666` (assumed)
**Security Account ID**: `333333444444` (assumed)
**Primary Region**: `us-east-1`
**Purpose**: Enable security monitoring and log aggregation

---

## 🏗️ Infrastructure Components

### IAM Roles (`iam-roles.tf`)

Creates 8 cross-account IAM roles:

1. **TerraformExecutionRole**
   - Purpose: Terraform infrastructure management
   - Trusted: Management account
   - Permissions: AdministratorAccess
   - External ID: `terraform-workload-account`

2. **GuardDutyMemberRole**
   - Purpose: Allow security account to access GuardDuty findings
   - Trusted: Security account (333333444444)
   - Service: guardduty.amazonaws.com
   - External ID: `guardduty-member-{account-id}`

3. **SecurityHubMemberRole**
   - Purpose: Allow security account to aggregate Security Hub findings
   - Trusted: Security account (333333444444)
   - Service: securityhub.amazonaws.com

4. **ConfigAggregateAuthorization**
   - Purpose: Allow security account to aggregate Config data
   - Type: AWS Config authorization
   - Region: us-east-1

5. **SecurityLakeQueryRole**
   - Purpose: Allow security account to query logs
   - Trusted: Security account (333333444444)
   - Permissions: S3, Glue, CloudWatch Logs read access

6. **CloudWatchLogsSenderRole**
   - Purpose: Send CloudWatch Logs to security account
   - Trusted: logs.amazonaws.com
   - Permissions: CreateLogGroup, PutLogEvents in security account

7. **VPCFlowLogsRole**
   - Purpose: Send VPC Flow Logs to security account S3
   - Trusted: vpc-flow-logs.amazonaws.com
   - Permissions: CloudWatch Logs write access

8. **DetectiveMemberRole**
   - Purpose: Allow security account to investigate security events
   - Trusted: Security account (333333444444)
   - Permissions: Detective read access

---

## 🚀 Deployment Guide

### Prerequisites

1. **Security Account Infrastructure** already deployed:
   - S3 buckets for centralized logging
   - KMS keys for encryption
   - IAM roles for security services

2. **AWS Organizations** membership:
   - Workload account is member of organization
   - Security services enabled at org level

3. **Terraform State Backend** configured:
   - S3 bucket: `org-workload-terraform-state-prod`
   - DynamoDB table: `terraform-locks-prod`

### Step 1: Update Variables

Edit `variables.tf` with actual account IDs:

```hcl
variable "security_account_id" {
  default = "YOUR_SECURITY_ACCOUNT_ID"  # Replace 333333444444
}

variable "management_account_id" {
  default = "YOUR_MANAGEMENT_ACCOUNT_ID"  # Update if known
}
```

### Step 2: Initialize Terraform

```bash
cd /path/to/workload-account/cross-account-roles
terraform init
```

### Step 3: Review Plan

```bash
terraform plan
```

**Expected Resources**: 16 resources to create

- 8 IAM roles
- 7 IAM role policies
- 1 Config aggregate authorization

### Step 4: Apply Configuration

```bash
terraform apply
```

### Step 5: Verify Deployment

Check outputs:

```bash
terraform output
```

You should see ARNs for all roles.

### Step 6: Accept GuardDuty/Security Hub Invitations

After roles are created, accept invitations from security account:

1. **GuardDuty**:

   ```bash
   # Get invitation ID
   aws guardduty list-invitations

   # Accept invitation
   aws guardduty accept-invitation \
     --detector-id <your-detector-id> \
     --master-id 333333444444 \
     --invitation-id <invitation-id>
   ```

2. **Security Hub**:
   ```bash
   # Accept invitation
   aws securityhub accept-administrator-invitation \
     --administrator-id 404068503087 \
     --invitation-id <invitation-id>
   ```

---

## 🔐 Trust Relationships

### Workload Account Trusts

| Role                     | Trusted Principal                            | Purpose                       |
| ------------------------ | -------------------------------------------- | ----------------------------- |
| TerraformExecutionRole   | Management account                           | Terraform operations          |
| GuardDutyMemberRole      | Security account + guardduty.amazonaws.com   | GuardDuty findings access     |
| SecurityHubMemberRole    | Security account + securityhub.amazonaws.com | Security Hub findings access  |
| SecurityLakeQueryRole    | Security account                             | Log query access              |
| CloudWatchLogsSenderRole | logs.amazonaws.com                           | Send logs to security account |
| VPCFlowLogsRole          | vpc-flow-logs.amazonaws.com                  | VPC flow logs delivery        |
| DetectiveMemberRole      | Security account                             | Detective investigation       |

### Cross-Account Permissions

| Role                     | Target Account          | Permission              | Resource              |
| ------------------------ | ----------------------- | ----------------------- | --------------------- |
| CloudWatchLogsSenderRole | Security (404068503087) | logs:PutLogEvents       | CloudWatch Logs       |
| SecurityLakeQueryRole    | Security (404068503087) | s3:GetObject            | Security Lake bucket  |
| GuardDutyMemberRole      | Security (404068503087) | guardduty:GetFindings   | GuardDuty findings    |
| SecurityHubMemberRole    | Security (404068503087) | securityhub:GetFindings | Security Hub findings |

---

## 📊 Data Flow Architecture

```
┌────────────────────────────────────────────────────────────────┐
│              Workload Account (290793900072)                   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                Application Workloads                      │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │  │
│  │  │   EKS    │  │   RDS    │  │   VPC    │              │  │
│  │  │ Cluster  │  │ Database │  │ Resources│              │  │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘              │  │
│  └───────┼──────────────┼──────────────┼────────────────────┘  │
│          │              │              │                        │
│          │ (Logs)       │ (Logs)       │ (Flow Logs)           │
│          │              │              │                        │
│  ┌───────▼──────────────▼──────────────▼────────────────────┐  │
│  │              Security Services (Local)                    │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │  │
│  │  │CloudTrail│  │GuardDuty │  │SecurityHub│              │  │
│  │  │  (Local) │  │ (Detector)│  │ (Member) │              │  │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘              │  │
│  └───────┼──────────────┼──────────────┼────────────────────┘  │
│          │              │              │                        │
│          │              │              │                        │
│          │ IAM Role:    │ IAM Role:    │ IAM Role:            │
│          │ CloudWatch   │ GuardDuty    │ SecurityHub          │
│          │ LogsSender   │ MemberRole   │ MemberRole           │
│          │              │              │                        │
└──────────┼──────────────┼──────────────┼────────────────────────┘
           │              │              │
           │              │              │
           │ (S3 Write)   │ (API Call)   │ (API Call)
           │ KMS Encrypt  │              │
           │              │              │
           ▼              ▼              ▼
┌────────────────────────────────────────────────────────────────┐
│              Security Account (404068503087)                   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │           Centralized Security Infrastructure             │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │  │
│  │  │CloudTrail│  │  Security │  │  Security│              │  │
│  │  │  Bucket  │  │    Hub    │  │   Lake   │              │  │
│  │  │ (KMS)    │  │ (Aggregator)│ (OCSF)   │              │  │
│  │  └──────────┘  └──────────┘  └──────────┘              │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

---

## 🧪 Testing Cross-Account Access

### Test 1: Terraform Role

```bash
# From management account
aws sts assume-role \
  --role-arn arn:aws:iam::290793900072:role/TerraformExecutionRole \
  --role-session-name test-session \
  --external-id terraform-workload-account
```

### Test 2: GuardDuty Member Role

```bash
# From security account
aws sts assume-role \
  --role-arn arn:aws:iam::290793900072:role/GuardDutyMemberRole \
  --role-session-name guardduty-test \
  --external-id guardduty-member-290793900072
```

### Test 3: Security Hub Member Role

```bash
# From security account
aws sts assume-role \
  --role-arn arn:aws:iam::290793900072:role/SecurityHubMemberRole \
  --role-session-name securityhub-test
```

### Test 4: Config Aggregate Authorization

```bash
# From security account
aws configservice describe-aggregate-authorization-status \
  --account-id 290793900072 \
  --region us-east-1
```

---

## 📝 Next Steps After Deployment

### 1. Configure CloudTrail to Security Account

```bash
# Create trail pointing to security account bucket
aws cloudtrail create-trail \
  --name workload-account-trail \
  --s3-bucket-name org-cloudtrail-logs-security-404068503087 \
  --is-multi-region-trail \
  --include-global-service-events \
  --enable-log-file-validation

# Start logging
aws cloudtrail start-logging --name workload-account-trail
```

### 2. Configure VPC Flow Logs to Security Account

```hcl
# Add to your VPC module
resource "aws_flow_log" "workload_vpc" {
  vpc_id          = module.networking.vpc_id
  traffic_type    = "ALL"
  log_destination = "arn:aws:s3:::org-vpc-flow-logs-security-404068503087"
  log_destination_type = "s3"
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
}
```

### 3. Enable GuardDuty

```bash
# Enable GuardDuty detector
aws guardduty create-detector --enable

# Accept invitation from security account
aws guardduty accept-invitation \
  --detector-id <your-detector-id> \
  --master-id 404068503087 \
  --invitation-id <invitation-id>
```

### 4. Enable Security Hub

```bash
# Enable Security Hub
aws securityhub enable-security-hub

# Accept invitation from security account
aws securityhub accept-administrator-invitation \
  --administrator-id 404068503087 \
  --invitation-id <invitation-id>
```

### 5. Enable Config

```bash
# Enable Config
aws configservice put-configuration-recorder \
  --configuration-recorder name=default,roleARN=arn:aws:iam::290793900072:role/AWSConfigRecorderRole

# Start Config
aws configservice start-configuration-recorder --configuration-recorder-name default
```

---

## 📊 Outputs

After successful deployment:

```hcl
Outputs:

terraform_execution_role_arn = "arn:aws:iam::290793900072:role/TerraformExecutionRole"
guardduty_member_role_arn = "arn:aws:iam::290793900072:role/GuardDutyMemberRole"
securityhub_member_role_arn = "arn:aws:iam::290793900072:role/SecurityHubMemberRole"
security_lake_query_role_arn = "arn:aws:iam::290793900072:role/SecurityLakeQueryRole"
cloudwatch_logs_sender_role_arn = "arn:aws:iam::290793900072:role/CloudWatchLogsSenderRole"
vpc_flow_logs_role_arn = "arn:aws:iam::290793900072:role/VPCFlowLogsRole"
detective_member_role_arn = "arn:aws:iam::290793900072:role/DetectiveMemberRole"

cross_account_roles_summary = {
  terraform_execution = {
    arn = "arn:aws:iam::555555666666:role/TerraformExecutionRole"
    name = "TerraformExecutionRole"
  }
  guardduty_member = {
    arn = "arn:aws:iam::290793900072:role/GuardDutyMemberRole"
    name = "GuardDutyMemberRole"
  }
  # ... more roles
}
```

---

## 🔧 Troubleshooting

### Issue: "Access Denied" when security account assumes role

**Solution**: Check external ID in trust policy:

```bash
aws iam get-role --role-name GuardDutyMemberRole
```

### Issue: "Config aggregate authorization not found"

**Solution**: Recreate authorization:

```bash
terraform taint aws_config_aggregate_authorization.security_account
terraform apply
```

### Issue: "GuardDuty invitation not received"

**Solution**: Security account must send invitation first:

```bash
# From security account
aws guardduty invite-members \
  --detector-id <security-account-detector-id> \
  --account-ids 290793900072
```

---

## 🔗 Related Resources

- **Security Account Roles**: `../security-account/cross-account-roles/`
- **Cross-Account Access Review**: `../security-account/CROSS-ACCOUNT-ACCESS-REVIEW.md`
- **Production Environment**: `../environments/production/`
- **DR Implementation**: `../environments/production/DR-IMPLEMENTATION-COMPLETE.md`

---

## 📚 AWS Documentation

- [Cross-Account IAM Roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html)
- [GuardDuty Multi-Account](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_organizations.html)
- [Security Hub Multi-Account](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-accounts.html)
- [Config Multi-Account](https://docs.aws.amazon.com/config/latest/developerguide/aggregate-data.html)

---

**Last Updated**: 2024-01-05
**Terraform Version**: >= 1.5.0
**AWS Provider Version**: ~> 5.0

# Cross-Account Access Configuration - Quick Start Guide

## 📋 Overview

This guide provides a quick deployment path for setting up cross-account access between Security Account and Workload Account.

**Estimated Time**: 30-45 minutes
**Skill Level**: Intermediate Terraform + AWS IAM

---

## 🎯 What Gets Deployed

### Security Account Infrastructure
- **10 IAM Roles** for security services (GuardDuty, Security Hub, Config, Security Lake, etc.)
- **4 S3 Buckets** for centralized logging (CloudTrail, VPC Flow, Security Lake, Athena)
- **3 KMS Keys** for cross-account encryption (security-logs, guardduty, securityhub)

### Workload Account Infrastructure
- **8 IAM Roles** for sending logs/findings to security account
- **1 Config Authorization** for aggregating compliance data
- Integration points for CloudTrail, VPC Flow Logs, GuardDuty, Security Hub

**Total Resources**: 44 resources across both accounts

---

## 🚀 Deployment Steps

### Phase 1: Security Account Setup (20 minutes)

1. **Navigate to security account directory**:
   ```bash
   cd organization/security-account/cross-account-roles
   ```

2. **Update account IDs** in `variables.tf`:
   ```hcl
   variable "workload_account_id" {
     default = "YOUR_ACTUAL_WORKLOAD_ACCOUNT_ID"
   }
   ```

3. **Initialize and deploy**:
   ```bash
   terraform init
   terraform plan
   terraform apply -auto-approve
   ```

4. **Save outputs**:
   ```bash
   terraform output > security-account-outputs.txt
   ```

### Phase 2: Workload Account Setup (15 minutes)

1. **Navigate to workload account directory**:
   ```bash
   cd ../../workload-account/cross-account-roles
   ```

2. **Update account IDs** in `variables.tf`:
   ```hcl
   variable "security_account_id" {
     default = "YOUR_ACTUAL_SECURITY_ACCOUNT_ID"
   }

   variable "management_account_id" {
     default = "YOUR_MANAGEMENT_ACCOUNT_ID"
   }
   ```

3. **Initialize and deploy**:
   ```bash
   terraform init
   terraform plan
   terraform apply -auto-approve
   ```

4. **Save outputs**:
   ```bash
   terraform output > workload-account-outputs.txt
   ```

### Phase 3: Enable Security Services (10 minutes)

1. **Enable GuardDuty** (from security account):
   ```bash
   aws guardduty enable-organization-admin-account \
     --admin-account-id <SECURITY_ACCOUNT_ID> \
     --region us-east-1
   ```

2. **Enable Security Hub** (from security account):
   ```bash
   aws securityhub enable-organization-admin-account \
     --admin-account-id <SECURITY_ACCOUNT_ID> \
     --region us-east-1
   ```

3. **Create Config Aggregator** (from security account):
   ```bash
   aws configservice put-configuration-aggregator \
     --configuration-aggregator-name organization-aggregator \
     --organization-aggregation-source RoleArn=arn:aws:iam::<SECURITY_ACCOUNT_ID>:role/ConfigAggregatorRole,AllAwsRegions=true
   ```

4. **Accept GuardDuty Invitation** (from workload account):
   ```bash
   aws guardduty list-invitations
   aws guardduty accept-invitation \
     --detector-id <DETECTOR_ID> \
     --master-id <SECURITY_ACCOUNT_ID> \
     --invitation-id <INVITATION_ID>
   ```

5. **Accept Security Hub Invitation** (from workload account):
   ```bash
   aws securityhub accept-administrator-invitation \
     --administrator-id <SECURITY_ACCOUNT_ID> \
     --invitation-id <INVITATION_ID>
   ```

---

## ✅ Verification Checklist

### Security Account
- [ ] All 10 IAM roles created successfully
- [ ] All 4 S3 buckets created with encryption enabled
- [ ] All 3 KMS keys created with rotation enabled
- [ ] Bucket policies allow cross-account write
- [ ] KMS key policies allow cross-account encrypt/decrypt
- [ ] GuardDuty organization admin enabled
- [ ] Security Hub organization admin enabled
- [ ] Config aggregator created

### Workload Account
- [ ] All 8 IAM roles created successfully
- [ ] Config aggregate authorization created
- [ ] GuardDuty detector exists
- [ ] Security Hub enabled
- [ ] GuardDuty invitation accepted
- [ ] Security Hub invitation accepted
- [ ] CloudTrail configured to security account bucket
- [ ] VPC Flow Logs configured to security account bucket

### Cross-Account Access
- [ ] Security account can assume GuardDutyMemberRole in workload account
- [ ] Security account can assume SecurityHubMemberRole in workload account
- [ ] Workload account can write to CloudTrail bucket in security account
- [ ] Workload account can write to VPC Flow Logs bucket in security account
- [ ] Config aggregator can read from workload account
- [ ] KMS keys work for cross-account encryption

---

## 🧪 Testing Commands

### Test 1: Assume Role from Security Account
```bash
# From security account, assume role in workload account
aws sts assume-role \
  --role-arn arn:aws:iam::<WORKLOAD_ACCOUNT_ID>:role/GuardDutyMemberRole \
  --role-session-name test-session \
  --external-id guardduty-member-<WORKLOAD_ACCOUNT_ID>
```

### Test 2: Write to CloudTrail Bucket
```bash
# From workload account, test write to security account bucket
echo "test" > test-log.txt
aws s3 cp test-log.txt s3://org-cloudtrail-logs-security-<SECURITY_ACCOUNT_ID>/test/
```

### Test 3: List GuardDuty Members
```bash
# From security account
aws guardduty list-members \
  --detector-id <SECURITY_ACCOUNT_DETECTOR_ID>
```

### Test 4: Get Security Hub Administrator
```bash
# From workload account
aws securityhub get-administrator-account
```

### Test 5: Describe Config Aggregator
```bash
# From security account
aws configservice describe-configuration-aggregators \
  --configuration-aggregator-names organization-aggregator
```

---

## 🔍 What to Check If Something Fails

### Terraform Apply Fails

**Issue**: Resource already exists
```
Error: Error creating IAM Role: EntityAlreadyExists
```

**Solution**: Import existing resource or use different name
```bash
terraform import aws_iam_role.terraform_execution TerraformExecutionRole
```

### Trust Policy Errors

**Issue**: Cannot assume role
```
Error: Access Denied when assuming role
```

**Solution**: Check trust policy includes correct account ID
```bash
aws iam get-role --role-name GuardDutyMemberRole
```

### Bucket Policy Errors

**Issue**: Cannot write to bucket
```
Error: Access Denied when writing to S3 bucket
```

**Solution**: Verify bucket policy includes workload account ID
```bash
aws s3api get-bucket-policy \
  --bucket org-cloudtrail-logs-security-<SECURITY_ACCOUNT_ID>
```

### KMS Key Errors

**Issue**: Cannot encrypt with KMS key
```
Error: Access Denied (Service: AWSKMS; Status Code: 400)
```

**Solution**: Check KMS key policy allows cross-account usage
```bash
aws kms get-key-policy \
  --key-id alias/security-logs \
  --policy-name default
```

---

## 📊 Architecture Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                  MANAGEMENT ACCOUNT                              │
│                                                                   │
│  - AWS Organizations (root)                                      │
│  - Service Control Policies (SCPs)                              │
│  - Can assume TerraformExecutionRole in all accounts            │
└────────────────────────┬────────────────────────────────────────┘
                         │
           ┌─────────────┴─────────────┐
           │                           │
           ▼                           ▼
┌──────────────────────┐    ┌──────────────────────┐
│  SECURITY ACCOUNT    │    │  WORKLOAD ACCOUNT    │
│  (404068503087)      │◄───┤  (290793900072)      │
│                      │    │                      │
│  ROLES:              │    │  ROLES:              │
│  - GuardDutyAdmin    │    │  - GuardDutyMember   │
│  - SecurityHubAdmin  │    │  - SecurityHubMember │
│  - ConfigAggregator  │    │  - ConfigAuth        │
│  - SecurityLake      │    │  - SecurityLakeQuery │
│                      │    │  - CloudWatchSender  │
│  BUCKETS:            │    │  - VPCFlowLogs       │
│  - CloudTrail logs   │◄───┤  - DetectiveMember   │
│  - VPC Flow logs     │    │                      │
│  - Security Lake     │    │  SENDS TO SECURITY:  │
│  - Athena results    │    │  - CloudTrail logs   │
│                      │    │  - VPC Flow logs     │
│  KMS KEYS:           │    │  - GuardDuty finds   │
│  - security-logs     │    │  - SecurityHub finds │
│  - guardduty         │    │  - Config data       │
│  - securityhub       │    │                      │
└──────────────────────┘    └──────────────────────┘
```

---

## 📚 Important Files Created

### Security Account
```
security-account/
├── cross-account-roles/
│   ├── iam-roles.tf          # 10 IAM roles
│   ├── s3-buckets.tf         # 4 S3 buckets
│   ├── kms.tf                # 3 KMS keys
│   ├── variables.tf          # Input variables
│   ├── outputs.tf            # Output values
│   ├── providers.tf          # Terraform/AWS providers
│   └── README.md             # Detailed documentation
└── CROSS-ACCOUNT-ACCESS-REVIEW.md  # Comprehensive review
```

### Workload Account
```
workload-account/
└── cross-account-roles/
    ├── iam-roles.tf          # 8 IAM roles
    ├── variables.tf          # Input variables
    ├── outputs.tf            # Output values
    ├── providers.tf          # Terraform/AWS providers
    └── README.md             # Detailed documentation
```

---

## 🎓 Key Concepts

### Cross-Account IAM Roles
- **Trust Policy**: Defines who can assume the role (which accounts/services)
- **Permissions Policy**: Defines what the role can do (actions on resources)
- **External ID**: Additional security for third-party access

### S3 Bucket Policies
- Allow specific accounts to write objects
- Require encryption in transit (HTTPS)
- Require bucket owner gets full control

### KMS Key Policies
- Grant root account full control
- Allow specific services to encrypt/decrypt
- Allow cross-account usage via service

### Service Principal Trust
- `guardduty.amazonaws.com` - GuardDuty service
- `securityhub.amazonaws.com` - Security Hub service
- `config.amazonaws.com` - Config service
- `cloudtrail.amazonaws.com` - CloudTrail service

---

## 🔐 Security Best Practices Applied

1. ✅ **Least Privilege**: Roles have minimum permissions needed
2. ✅ **External IDs**: Used for cross-account role assumptions
3. ✅ **Encryption**: All buckets use KMS encryption
4. ✅ **Key Rotation**: KMS keys have automatic rotation enabled
5. ✅ **Versioning**: All buckets have versioning enabled
6. ✅ **Public Access**: All buckets block public access
7. ✅ **Secure Transport**: Bucket policies enforce HTTPS
8. ✅ **Lifecycle Policies**: Data transitions to cheaper storage
9. ✅ **MFA Delete**: Can be enabled on buckets if needed
10. ✅ **Access Logging**: Can be enabled for audit trail

---

## 📞 Support and Documentation

### Internal Documentation
- [CROSS-ACCOUNT-ACCESS-REVIEW.md](../security-account/CROSS-ACCOUNT-ACCESS-REVIEW.md) - Comprehensive review
- [Security Account README](../security-account/cross-account-roles/README.md) - Security account guide
- [Workload Account README](../workload-account/cross-account-roles/README.md) - Workload account guide
- [SECURITY-SERVICES-GUIDE.md](../management-account/SECURITY-SERVICES-GUIDE.md) - Security services guide

### AWS Documentation
- [Cross-Account Access Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_common-scenarios_aws-accounts.html)
- [GuardDuty Multi-Account](https://docs.aws.amazon.com/guardduty/latest/ug/guardduty_organizations.html)
- [Security Hub Multi-Account](https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-accounts.html)

---

## 🎯 Success Metrics

After successful deployment, you should achieve:

- ✅ **100% Cross-Account Access Coverage** - All required roles created
- ✅ **Centralized Security Logging** - All logs in security account
- ✅ **Automated Threat Detection** - GuardDuty running across all accounts
- ✅ **Unified Security Dashboard** - Security Hub aggregating findings
- ✅ **Compliance Monitoring** - Config aggregating compliance data
- ✅ **Encrypted Data at Rest** - All buckets using KMS encryption
- ✅ **Encrypted Data in Transit** - HTTPS enforced on all S3 access

---

**Deployment Date**: 2024-01-05
**Version**: 1.0
**Next Review**: Quarterly (2024-04-05)

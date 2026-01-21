# Enhanced AWS Organization Services - Quick Reference

## 🎯 Overview

Quick reference for the newly enabled AWS organization services: S3 Backend, AWS Backup, Compute Optimizer, and License Manager.

---

## 📦 S3 Backend Configuration

### **Backend Details**

```hcl
backend "s3" {
  bucket         = "captaingab-terraform-state"
  key            = "management-account/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-state-lock"
}
```

### **Quick Commands**

```bash
# Migrate to S3 backend
terraform init -reconfigure

# Check state location
terraform show

# Force unlock if stuck
terraform force-unlock <LOCK_ID>
```

---

## 🔄 AWS Backup Organization

### **Configuration Summary**

- **Schedule**: Daily at 2 AM UTC (`cron(0 2 ? * * *)`)
- **Retention**: 365 days
- **Cold Storage**: After 30 days
- **Cross-Region**: us-west-2 (90-day retention)
- **Target**: Resources tagged `BackupRequired=true`

### **Quick Commands**

```bash
# Tag resource for backup
aws ec2 create-tags --resources <RESOURCE-ID> --tags Key=BackupRequired,Value=true

# Check backup jobs
aws backup list-backup-jobs

# Check backup vaults
aws backup list-backup-vaults

# View organization config
aws backup describe-organization-configuration
```

### **Resource Tagging Examples**

```bash
# EC2 Instance
aws ec2 create-tags --resources i-1234567890abcdef0 --tags Key=BackupRequired,Value=true

# RDS Database
aws rds add-tags-to-resource --resource-name arn:aws:rds:us-east-1:123456789012:db:mydb --tags Key=BackupRequired,Value=true

# EBS Volume
aws ec2 create-tags --resources vol-1234567890abcdef0 --tags Key=BackupRequired,Value=true

# EFS File System
aws efs put-backup-policy --file-system-id fs-12345678 --backup-policy Status=ENABLED
```

---

## 💡 Compute Optimizer

### **Configuration Summary**

- **Status**: Active for organization
- **Member Accounts**: Included
- **Recommendations**: EC2, EBS, Lambda, Auto Scaling

### **Quick Commands**

```bash
# Check enrollment status
aws compute-optimizer get-enrollment-status

# Get EC2 recommendations
aws compute-optimizer get-ec2-instance-recommendations

# Get EBS recommendations
aws compute-optimizer get-ebs-volume-recommendations

# Get Lambda recommendations
aws compute-optimizer get-lambda-function-recommendations

# Get Auto Scaling recommendations
aws compute-optimizer get-auto-scaling-group-recommendations
```

### **Recommendation Types**

| Service          | Optimization Focus         | Potential Savings |
| ---------------- | -------------------------- | ----------------- |
| **EC2**          | Instance type right-sizing | 10-30%            |
| **EBS**          | Volume type optimization   | 5-20%             |
| **Lambda**       | Memory allocation          | 10-25%            |
| **Auto Scaling** | Instance mix optimization  | 15-35%            |

---

## 📋 License Manager

### **Configuration Summary**

- **Scope**: Organization-wide tracking
- **Type**: Instance-based counting
- **Sharing**: Cross-account enabled
- **Discovery**: Automatic

### **Quick Commands**

```bash
# List license configurations
aws license-manager list-license-configurations

# Get license usage
aws license-manager list-license-usage-for-resource --resource-arn <ARN>

# Check associations
aws license-manager list-associations-for-license-configuration --license-configuration-arn <ARN>

# Tag resources with license info
aws ec2 create-tags --resources <RESOURCE-ID> --tags Key=LicenseType,Value=BYOL
```

### **License Types**

| Tag Value         | Description                 | Use Case                |
| ----------------- | --------------------------- | ----------------------- |
| `BYOL`            | Bring Your Own License      | Customer-owned licenses |
| `LicenseIncluded` | License included in service | AWS-managed licenses    |
| `None`            | No license required         | Open source software    |

---

## 🏷️ Tag Policy Enforcement

### **Required Tags**

| Tag Key          | Required Values                                    | Applied To                        |
| ---------------- | -------------------------------------------------- | --------------------------------- |
| `BackupRequired` | `true`, `false`                                    | EC2, RDS, EBS, EFS, FSx, DynamoDB |
| `Environment`    | `production`, `staging`, `development`, `security` | All resources                     |
| `LicenseType`    | `BYOL`, `LicenseIncluded`, `None`                  | EC2, RDS                          |
| `CostCenter`     | Any value                                          | All resources                     |

### **Quick Commands**

```bash
# Check tag compliance
aws resourcegroupstaggingapi get-compliance-summary

# Get non-compliant resources
aws resourcegroupstaggingapi get-resources --tags-per-page 100

# Bulk tag resources
aws resourcegroupstaggingapi tag-resources --resource-arn-list <ARN1> <ARN2> --tags Key=Environment,Value=production
```

### **Tagging Examples**

```bash
# Complete resource tagging
aws ec2 create-tags --resources i-1234567890abcdef0 --tags \
  Key=Environment,Value=production \
  Key=BackupRequired,Value=true \
  Key=LicenseType,Value=BYOL \
  Key=CostCenter,Value=engineering

# RDS tagging
aws rds add-tags-to-resource --resource-name arn:aws:rds:us-east-1:123456789012:db:mydb --tags \
  Key=Environment,Value=production \
  Key=BackupRequired,Value=true \
  Key=LicenseType,Value=LicenseIncluded \
  Key=CostCenter,Value=database-team
```

---

## 📊 Monitoring and Alerts

### **CloudWatch Metrics to Monitor**

```bash
# Backup job failures
aws cloudwatch put-metric-alarm --alarm-name "Backup-Job-Failures" \
  --metric-name NumberOfBackupJobsFailed \
  --namespace AWS/Backup \
  --statistic Sum --period 3600 --evaluation-periods 1 \
  --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold

# License usage
aws cloudwatch put-metric-alarm --alarm-name "License-Usage-High" \
  --metric-name LicenseUsagePercentage \
  --namespace AWS/LicenseManager \
  --statistic Average --period 3600 --evaluation-periods 1 \
  --threshold 90 --comparison-operator GreaterThanThreshold
```

### **Cost Monitoring**

```bash
# Check backup costs
aws ce get-cost-and-usage --time-period Start=2026-01-01,End=2026-01-31 \
  --granularity MONTHLY --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE

# Compute Optimizer savings
aws compute-optimizer get-ec2-instance-recommendations \
  --query 'instanceRecommendations[*].recommendationOptions[0].estimatedMonthlySavings'
```

---

## 🚨 Troubleshooting

### **Common Issues**

#### S3 Backend Issues

```bash
# State lock stuck
terraform force-unlock <LOCK_ID>

# Access denied to S3
aws s3api get-bucket-policy --bucket captaingab-terraform-state

# DynamoDB table issues
aws dynamodb describe-table --table-name terraform-state-lock
```

#### Backup Issues

```bash
# Check backup job status
aws backup describe-backup-job --backup-job-id <JOB-ID>

# Verify IAM role
aws iam get-role --role-name aws-backup-service-role

# Check vault access
aws backup describe-backup-vault --backup-vault-name default
```

#### Compute Optimizer Issues

```bash
# Re-enroll if needed
aws compute-optimizer update-enrollment-status --status Active

# Check data collection
aws compute-optimizer describe-recommendation-export-jobs
```

#### License Manager Issues

```bash
# Check license configuration
aws license-manager get-license-configuration --license-configuration-arn <ARN>

# Verify resource association
aws license-manager list-usage-for-license-configuration --license-configuration-arn <ARN>
```

---

## 📈 Best Practices

### **Daily Operations**

- [ ] Monitor backup job success/failure
- [ ] Review Compute Optimizer recommendations
- [ ] Check tag compliance reports
- [ ] Monitor license usage alerts

### **Weekly Operations**

- [ ] Review backup storage costs
- [ ] Implement cost optimization recommendations
- [ ] Audit license assignments
- [ ] Update resource tags as needed

### **Monthly Operations**

- [ ] Analyze backup retention policies
- [ ] Review Compute Optimizer savings
- [ ] Audit license compliance
- [ ] Update tag policies if needed

### **Quarterly Operations**

- [ ] Test backup restoration procedures
- [ ] Review organization policies
- [ ] Audit cross-account access
- [ ] Update documentation

---

## 📞 Quick Support

### **AWS Console Links**

- **Backup**: https://console.aws.amazon.com/backup/
- **Compute Optimizer**: https://console.aws.amazon.com/compute-optimizer/
- **License Manager**: https://console.aws.amazon.com/license-manager/
- **Organizations**: https://console.aws.amazon.com/organizations/

### **Documentation Links**

- **AWS Backup**: https://docs.aws.amazon.com/backup/
- **Compute Optimizer**: https://docs.aws.amazon.com/compute-optimizer/
- **License Manager**: https://docs.aws.amazon.com/license-manager/
- **Tag Policies**: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_tag-policies.html

### **Support Contacts**

- **Technical Issues**: DevOps team
- **Cost Questions**: FinOps team
- **License Issues**: Procurement team
- **AWS Support**: Enterprise support line

---

**Last Updated**: January 21, 2026
**Version**: 1.0

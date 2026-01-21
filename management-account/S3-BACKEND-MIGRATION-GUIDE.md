# S3 B Migration Guide

## 🎯 Overview

This guide provides step-by-step instructions for migrating your Terraform state from local storage to S3 backend with DynamoDB locking, and enabling additional AWS organization services.

## 📋 Prerequisites

### 1. **Existing Infrastructure**

- ✅ AWS Organization is deployed and active
- ✅ Security account exists with S3 bucket for Terraform state
- ✅ DynamoDB table exists for state locking
- ✅ Current Terraform state is in local file

### 2. **Required Resources**

Ensure these resources exist in your **security account**:

```bash
# Check S3 bucket exists
aws s3 ls s3://captaingab-terraform-state --profile security-account

# Check DynamoDB table exists
aws dynamodb describe-table --table-name terraform-state-lock --profile security-account
```

If these don't exist, deploy them first:

```bash
cd ../security-account/backend-bootstrap
terraform init
terraform apply
```

## 🚀 Migration Steps

### Step 1: Backup Current State

```bash
cd terraform-infra/management-account

# Create backup of current state
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d-%H%M%S)
cp terraform.tfstate.backup terraform.tfstate.backup.$(date +%Y%m%d-%H%M%S)

# Verify backup
ls -la terraform.tfstate*
```

### Step 2: Update Terraform Configuration

The providers.tf has already been updated to include:

```hcl
backend "s3" {
  bucket         = "captaingab-terraform-state"
  key            = "management-account/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "terraform-state-lock"
}
```

### Step 3: Initialize S3 Backend

```bash
# Reconfigure Terraform to use S3 backend
terraform init -reconfigure

# Expected output:
# Initializing the backend...
# Do you want to copy existing state to the new backend?
#   Pre-existing state was found while migrating the previous "local" backend to the
#   newly configured "s3" backend. No existing state was found in the newly
#   configured "s3" backend. Do you want to copy this state to the new "s3"
#   backend? Enter "yes" to copy and "no" to start with an empty state.
#
#   Enter a value:yes

# Type "yes" to migrate existing state
```

### Step 4: Verify State Migration

```bash
# Check state is now in S3
aws s3 ls s3://captaingab-terraform-state/management-account/ --profile security-account

# Expected output:
# terraform.tfstate

# Verify local state is no longer used
terraform show
# Should show your existing resources from S3 state

# Check DynamoDB lock table
aws dynamodb scan --table-name terraform-state-lock --profile security-account
```

### Step 5: Plan New Services

```bash
# Review what will be added
terraform plan

# Expected new resources:
# + aws_backup_organization_configuration.org_backup
# + aws_computeoptimizer_enrollment_status.org_compute_optimizer
# + aws_licensemanager_license_configuration.organization_licenses
# + aws_licensemanager_association.organization_association
# + aws_organizations_policy.backup_policy
# + aws_organizations_policy.tag_policy
# + aws_organizations_policy_attachment.backup_policy_workloads
# + aws_organizations_policy_attachment.tag_policy_root
```

### Step 6: Apply New Configuration

```bash
# Apply the enhanced configuration
terraform apply

# Review changes carefully before confirming
# Type "yes" to proceed
```

### Step 7: Verify New Services

```bash
# Check AWS Backup organization configuration
aws backup describe-organization-configuration

# Check Compute Optimizer enrollment
aws compute-optimizer get-enrollment-status

# Check License Manager configuration
aws license-manager list-license-configurations

# Verify new policies
aws organizations list-policies --filter BACKUP_POLICY
aws organizations list-policies --filter TAG_POLICY
```

## 🔧 New Services Configuration

### 1. **AWS Backup Organization**

**What's Enabled:**

- ✅ Organization-wide backup management
- ✅ Cross-account backup monitoring
- ✅ Cross-region backup copying
- ✅ Centralized backup policies

**Backup Policy Applied to Workloads OU:**

- **Schedule**: Daily at 2 AM UTC
- **Retention**: 365 days (1 year)
- **Cold Storage**: After 30 days
- **Cross-Region**: Copy to us-west-2 (90-day retention)
- **Target Resources**: Resources tagged with `BackupRequired=true`

**Usage Example:**

```bash
# Tag resources for backup
aws ec2 create-tags --resources i-1234567890abcdef0 --tags Key=BackupRequired,Value=true
aws rds add-tags-to-resource --resource-name arn:aws:rds:us-east-1:123456789012:db:mydb --tags Key=BackupRequired,Value=true
```

### 2. **Compute Optimizer**

**What's Enabled:**

- ✅ Organization-wide resource optimization recommendations
- ✅ EC2 instance right-sizing recommendations
- ✅ EBS volume optimization suggestions
- ✅ Lambda function optimization recommendations
- ✅ Auto Scaling group recommendations

**Access Recommendations:**

```bash
# Get EC2 recommendations
aws compute-optimizer get-ec2-instance-recommendations

# Get EBS recommendations
aws compute-optimizer get-ebs-volume-recommendations

# Get Lambda recommendations
aws compute-optimizer get-lambda-function-recommendations
```

### 3. **License Manager**

**What's Configured:**

- ✅ Organization-wide license tracking
- ✅ Automatic license discovery
- ✅ Cross-account license sharing
- ✅ License compliance monitoring

**Usage Example:**

```bash
# Tag resources with license information
aws ec2 create-tags --resources i-1234567890abcdef0 --tags Key=LicenseType,Value=BYOL
aws rds add-tags-to-resource --resource-name arn:aws:rds:us-east-1:123456789012:db:mydb --tags Key=LicenseType,Value=LicenseIncluded
```

### 4. **Enhanced Tag Policy**

**Enforced Tags:**

- **BackupRequired**: `true` or `false` (required for backup-eligible resources)
- **Environment**: `production`, `staging`, `development`, `security`
- **LicenseType**: `BYOL`, `LicenseIncluded`, `None`
- **CostCenter**: Any value (required for cost allocation)

**Enforcement Scope:**

- EC2 instances, RDS databases, DynamoDB tables
- EFS and FSx file systems
- EBS volumes
- All other AWS resources (for Environment and CostCenter)

## 📊 Outputs Reference

After successful deployment, you'll have these new outputs:

### AWS Backup

```bash
terraform output backup_policy_id
terraform output backup_policy_arn
terraform output backup_organization_config
```

### Compute Optimizer

```bash
terraform output compute_optimizer_status
terraform output compute_optimizer_member_accounts_enabled
```

### License Manager

```bash
terraform output license_manager_configuration_arn
terraform output license_manager_configuration_id
```

### Tag Policy

```bash
terraform output tag_policy_id
terraform output tag_policy_arn
```

## 🔍 Verification Checklist

### ✅ S3 Backend Migration

- [ ] State file exists in S3: `s3://captaingab-terraform-state/management-account/terraform.tfstate`
- [ ] DynamoDB lock table is functional
- [ ] Local state files are backed up
- [ ] `terraform show` displays existing resources
- [ ] `terraform plan` shows no unexpected changes

### ✅ AWS Backup

- [ ] Organization configuration is active
- [ ] Backup policy is attached to Workloads OU
- [ ] Cross-account monitoring is enabled
- [ ] Cross-region backup is enabled

### ✅ Compute Optimizer

- [ ] Enrollment status is "Active"
- [ ] Member accounts are included
- [ ] Recommendations are being generated

### ✅ License Manager

- [ ] License configuration is created
- [ ] Organization association is active
- [ ] License tracking is functional

### ✅ Tag Policy

- [ ] Tag policy is attached to root (all accounts)
- [ ] Required tags are enforced
- [ ] Tag compliance is monitored

## 🚨 Troubleshooting

### Issue 1: S3 Backend Access Denied

**Error:**

```
Error: Failed to get existing workspaces: S3 bucket does not exist.
```

**Solution:**

```bash
# Verify bucket exists and you have access
aws s3 ls s3://captaingab-terraform-state --profile security-account

# Check bucket policy allows management account access
aws s3api get-bucket-policy --bucket captaingab-terraform-state --profile security-account
```

### Issue 2: DynamoDB Lock Table Issues

**Error:**

```
Error acquiring the state lock: ConditionalCheckFailedException
```

**Solution:**

```bash
# Check if lock table exists
aws dynamodb describe-table --table-name terraform-state-lock --profile security-account

# If stuck, force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

### Issue 3: AWS Backup Policy Attachment Failed

**Error:**

```
Error: error attaching policy to target: PolicyTypeNotAvailableForOrganizationException
```

**Solution:**

```bash
# Verify BACKUP_POLICY is enabled in organization
aws organizations list-roots
aws organizations describe-organization

# Enable backup policy type if needed
aws organizations enable-policy-type --root-id <ROOT_ID> --policy-type BACKUP_POLICY
```

### Issue 4: Compute Optimizer Enrollment Failed

**Error:**

```
Error: error enrolling in Compute Optimizer: OptInRequiredException
```

**Solution:**

```bash
# Enroll manually first
aws compute-optimizer update-enrollment-status --status Active --include-member-accounts

# Then run terraform apply again
terraform apply
```

## 💰 Cost Implications

### S3 Backend Storage

- **State files**: ~$0.01/month (minimal size)
- **Versioning**: ~$0.05/month (with versioning enabled)

### DynamoDB Lock Table

- **On-demand pricing**: ~$0.25/month (minimal usage)

### AWS Backup

- **Backup storage**: Varies by data volume
- **Cross-region transfer**: $0.02/GB
- **Restore operations**: $0.03/GB

### Compute Optimizer

- **Service**: FREE (no additional charges)

### License Manager

- **Service**: FREE (no additional charges)

### Tag Policies

- **Service**: FREE (no additional charges)

## 🔄 Rollback Procedure

If you need to rollback to local state:

### Step 1: Download Current State

```bash
# Download state from S3
aws s3 cp s3://captaingab-terraform-state/management-account/terraform.tfstate ./terraform.tfstate.s3backup --profile security-account
```

### Step 2: Update Backend Configuration

```hcl
# Comment out S3 backend in providers.tf
# backend "s3" {
#   bucket         = "captaingab-terraform-state"
#   key            = "management-account/terraform.tfstate"
#   region         = "us-east-1"
#   encrypt        = true
#   dynamodb_table = "terraform-state-lock"
# }
```

### Step 3: Migrate Back to Local

```bash
# Reconfigure to local backend
terraform init -reconfigure

# When prompted, choose to copy state from S3 to local
# Type "yes"
```

## 📚 Best Practices

### State Management

- ✅ Always backup state before migrations
- ✅ Use state locking to prevent concurrent modifications
- ✅ Enable S3 versioning for state file history
- ✅ Restrict access to state bucket
- ✅ Monitor state file access via CloudTrail

### Backup Management

- ✅ Tag all critical resources with `BackupRequired=true`
- ✅ Regularly test backup restoration procedures
- ✅ Monitor backup job success/failure
- ✅ Review backup costs monthly
- ✅ Implement backup retention policies

### Cost Optimization

- ✅ Review Compute Optimizer recommendations monthly
- ✅ Implement right-sizing recommendations
- ✅ Monitor license utilization
- ✅ Use tag policies for cost allocation
- ✅ Set up billing alerts

### Compliance

- ✅ Enforce consistent tagging across organization
- ✅ Monitor tag compliance regularly
- ✅ Document backup and recovery procedures
- ✅ Audit license usage quarterly
- ✅ Review organization policies annually

## 📞 Support

### During Migration

- **Technical Issues**: DevOps team
- **AWS Support**: Enterprise support line
- **State Issues**: Terraform documentation

### Post-Migration

- **Backup Issues**: AWS Backup documentation
- **Cost Optimization**: Compute Optimizer console
- **License Tracking**: License Manager console
- **Tag Compliance**: AWS Config rules

---

## ✅ Summary

After completing this migration, you'll have:

1. **✅ S3 Backend**: Centralized, secure state management with locking
2. **✅ AWS Backup**: Organization-wide backup policies and monitoring
3. **✅ Compute Optimizer**: Cost optimization recommendations across all accounts
4. **✅ License Manager**: Centralized license tracking and compliance
5. **✅ Tag Policies**: Enforced tagging standards for governance

Your AWS Organization is now enhanced with enterprise-grade backup, cost optimization, and governance capabilities while maintaining secure, centralized Terraform state management.

**Next Steps:**

1. Complete the migration following this guide
2. Configure backup monitoring and alerting
3. Review and implement Compute Optimizer recommendations
4. Set up license tracking for your software assets
5. Train teams on new tagging requirements

---

**Last Updated**: January 21, 2026
**Terraform Version**: >= 1.5.0
**AWS Provider**: ~> 5.0

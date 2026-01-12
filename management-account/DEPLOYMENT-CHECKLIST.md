# Root Account SCP - Deployment Checklist

**Date**: 2026-01-12
**Change Type**: SCP Enhancement (Low Risk)
**Validation Status**: ✅ `terraform validate` passed

---

## ✅ Pre-Deployment Verification

### Configuration Validation
- [x] Terraform syntax validated (`terraform validate`)
- [x] Terraform formatted (`terraform fmt`)
- [x] Configuration reviewed
- [x] Documentation created

### Prerequisites Check
```bash
# Verify you're in the correct account (Management Account)
aws sts get-caller-identity

# Expected: Management account ID (404068503087)
```

- [ ] Confirmed in management account
- [ ] AWS credentials are valid
- [ ] Terraform state is accessible
- [ ] No other Terraform operations in progress

---

## 🚀 Deployment Steps

### Step 1: Preview Changes
```bash
cd /Users/CaptGab/terraform-infra/management-account

# Generate plan
terraform plan -out=scp-update.tfplan

# Review the plan carefully
# Expected changes:
# ~ aws_organizations_policy.deny_root_usage (update in-place)
#   - Policy content will be updated with new exceptions
#
# Should NOT affect:
# - Other SCPs
# - Organization structure
# - Account attachments
```

**Checklist:**
- [ ] Plan shows only `deny_root_usage` policy modification
- [ ] No resources being destroyed
- [ ] No unexpected changes
- [ ] Save plan output for records

### Step 2: Notify Stakeholders (Optional)
```bash
# If you want to notify team before applying
# Send notification to:
# - Security team
# - DevOps team
# - Compliance team
```

**Notification Template:**
```
Subject: [PLANNED] Root Account SCP Enhancement - 2026-01-12

Team,

We will be enhancing the Root Account SCP to add proper break-glass
exceptions while maintaining security controls.

Timeline: [DATE/TIME]
Duration: < 5 minutes
Impact: None (normal IAM access unaffected)
Rollback: Available if needed

Changes:
- Enhanced root account restrictions
- Added billing operation exceptions
- Added account recovery exceptions
- Maintains security compliance

Documentation: /management-account/ROOT-ACCOUNT-SCP-GUIDE.md

Questions? Contact security team.
```

- [ ] Stakeholders notified (if required)
- [ ] Maintenance window scheduled (if required)

### Step 3: Apply Changes
```bash
# Apply the saved plan
terraform apply scp-update.tfplan

# Or apply directly with auto-approve (if you're confident)
# terraform apply -auto-approve
```

**During Apply:**
- Watch for any errors
- Typical apply time: < 30 seconds
- Note the completion time

**Checklist:**
- [ ] Apply completed successfully
- [ ] No errors in output
- [ ] Timestamp recorded: _______________

### Step 4: Verify Deployment
```bash
# 1. Verify policy exists
aws organizations list-policies \
  --filter SERVICE_CONTROL_POLICY \
  --query 'Policies[?Name==`DenyRootAccountUsage`]' \
  --output table

# 2. Verify attachment to Workloads OU
aws organizations list-policies-for-target \
  --target-id $(terraform output -raw workloads_ou_id) \
  --filter SERVICE_CONTROL_POLICY

# 3. Check policy content (ensure new exceptions are present)
POLICY_ID=$(aws organizations list-policies \
  --filter SERVICE_CONTROL_POLICY \
  --query 'Policies[?Name==`DenyRootAccountUsage`].Id' \
  --output text)

aws organizations describe-policy \
  --policy-id $POLICY_ID \
  --query 'Policy.Content' \
  --output text | jq .

# Look for: AllowRootAccountRecoveryAndBilling statement
```

**Checklist:**
- [ ] Policy ID matches: p-________________
- [ ] Attached to Workloads OU: ou-________________
- [ ] Policy contains both Deny and Allow statements
- [ ] Allow statement includes billing actions
- [ ] Allow statement includes account recovery actions

---

## 🧪 Post-Deployment Testing

### Test 1: Verify Root Restrictions (5 min)
```bash
# Login to workload account as root
# AWS Console → Switch to workload account (as root)

# Try to perform restricted action:
# Navigate to EC2 → Launch Instance
# Expected: Access Denied (SCP restriction)

# Or via CLI:
aws s3 ls --profile workload-root
# Expected: An error occurred (AccessDenied)
```

- [ ] ✅ Root CANNOT launch EC2 instances
- [ ] ✅ Root CANNOT list S3 buckets
- [ ] ✅ Root CANNOT create IAM users

### Test 2: Verify Allowed Actions (5 min)
```bash
# Still as root in workload account

# Try billing access:
# Navigate to: https://console.aws.amazon.com/billing/
# Expected: Success - can view billing dashboard

# Try account information:
# Navigate to: Account → Security Credentials
# Expected: Can manage MFA devices
```

- [ ] ✅ Root CAN access billing console
- [ ] ✅ Root CAN view account information
- [ ] ✅ Root CAN manage MFA devices

### Test 3: Verify Normal IAM Access (5 min)
```bash
# Login as IAM user or assume IAM role (NOT root)
# AWS Console → IAM user login

# Try normal operations:
aws s3 ls --profile iam-user
aws ec2 describe-instances --profile iam-user

# Expected: Success (IAM users/roles are NOT affected by root SCP)
```

- [ ] ✅ IAM users can perform normal operations
- [ ] ✅ IAM roles still work
- [ ] ✅ SSO/Identity Center unaffected

### Test 4: Monitoring Verification (5 min)
```bash
# Check CloudTrail for recent root activity
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=root \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --max-results 5 \
  --region us-east-1

# Verify events are being logged
```

- [ ] ✅ CloudTrail capturing root activity
- [ ] ✅ Events show correct source IP
- [ ] ✅ Deny responses logged for restricted actions

---

## 📊 Monitoring Setup

### CloudWatch Alarm (Optional but Recommended)
```bash
# Create alarm for root account login
aws cloudwatch put-metric-alarm \
  --alarm-name "Root-Account-Login-Alert" \
  --alarm-description "Alert on root account console login" \
  --metric-name RootAccountLogin \
  --namespace AWS/CloudTrail \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:SecurityAlerts

# Note: Replace YOUR_ACCOUNT_ID with your actual security account ID
```

- [ ] CloudWatch alarm created
- [ ] SNS topic configured
- [ ] Test alert sent successfully

### EventBridge Rule (Optional but Recommended)
```bash
# Create rule to detect root activity
aws events put-rule \
  --name "RootAccountActivityDetection" \
  --event-pattern '{
    "detail": {
      "userIdentity": {
        "type": ["Root"]
      },
      "eventType": ["AwsApiCall"]
    }
  }' \
  --state ENABLED \
  --description "Detect root account API activity"

# Add SNS target
aws events put-targets \
  --rule "RootAccountActivityDetection" \
  --targets "Id"="1","Arn"="arn:aws:sns:us-east-1:YOUR_ACCOUNT_ID:SecurityAlerts"
```

- [ ] EventBridge rule created
- [ ] SNS target configured
- [ ] Rule is enabled

---

## 📝 Documentation & Communication

### Update Internal Docs
- [ ] Security runbook updated
- [ ] Compliance documentation updated
- [ ] Team wiki updated with new procedures
- [ ] Break-glass procedure documented

### Notify Teams
```bash
# Post-deployment notification template
```

**Notification:**
```
Subject: [COMPLETED] Root Account SCP Enhancement

Team,

The Root Account SCP has been successfully enhanced.

Status: ✅ COMPLETE
Applied: [TIMESTAMP]
Impact: None observed
Testing: All tests passed

What Changed:
✅ Root account blocked from infrastructure operations
✅ Billing and account recovery still work
✅ IAM users/roles unaffected
✅ Break-glass procedures documented

Documentation:
📖 Full Guide: /management-account/ROOT-ACCOUNT-SCP-GUIDE.md
⚡ Quick Ref: /management-account/ROOT-ACCOUNT-SCP-QUICK-REF.md
🚨 Incidents: /security-detections/runbooks/root-account-incident.md

Action Required:
- Review documentation if you need root access
- Follow break-glass procedures for emergencies
- Report any root login alerts immediately

Questions? Contact security team.
```

- [ ] Deployment notification sent
- [ ] Documentation links shared
- [ ] Training scheduled (if needed)

---

## 🔄 Rollback Procedure (If Needed)

### If Issues Occur
```bash
# Option 1: Detach SCP temporarily
aws organizations detach-policy \
  --policy-id p-xxxxxxxx \
  --target-id ou-xxxx-xxxxxxxx

# Option 2: Revert via Terraform
cd /Users/CaptGab/terraform-infra/management-account
git revert HEAD
terraform apply

# Option 3: Emergency - disable SCP entirely
aws organizations update-policy \
  --policy-id p-xxxxxxxx \
  --description "DISABLED - Under investigation"
# Then detach from all targets
```

**Rollback Checklist:**
- [ ] Incident documented
- [ ] Rollback reason recorded
- [ ] Stakeholders notified
- [ ] Root cause analysis scheduled

---

## 📋 Completion Checklist

### Deployment
- [ ] Terraform plan reviewed
- [ ] Terraform apply completed successfully
- [ ] Policy attachment verified
- [ ] No errors in Terraform output

### Testing
- [ ] Root restrictions verified
- [ ] Allowed actions tested
- [ ] IAM access confirmed working
- [ ] CloudTrail logging verified

### Monitoring (Optional)
- [ ] CloudWatch alarms configured
- [ ] EventBridge rules created
- [ ] SNS notifications tested

### Documentation
- [ ] Internal documentation updated
- [ ] Team notified of changes
- [ ] Break-glass procedures documented
- [ ] Compliance records updated

### Post-Deployment
- [ ] Monitor for 24 hours
- [ ] Check CloudTrail for any root activity
- [ ] Verify no user complaints
- [ ] Schedule follow-up review

---

## 📞 Support Contacts

| Issue Type | Contact |
|------------|---------|
| **Terraform errors** | DevOps team |
| **Policy questions** | Security team: security@example.com |
| **Root access needed** | Follow break-glass procedure |
| **AWS Support** | Enterprise support line |
| **Emergency** | On-call via PagerDuty |

---

## 📚 Related Documentation

- **Implementation Guide**: `ROOT-ACCOUNT-SCP-GUIDE.md`
- **Quick Reference**: `ROOT-ACCOUNT-SCP-QUICK-REF.md`
- **Incident Response**: `/security-detections/runbooks/root-account-incident.md`
- **Implementation Summary**: `ROOT-ACCOUNT-IMPLEMENTATION-SUMMARY.md`

---

## ✅ Sign-Off

**Deployed By**: _______________________________
**Date/Time**: _______________________________
**Verified By**: _______________________________
**Issues Noted**: _______________________________

**Status**: ⬜ SUCCESS  ⬜ ROLLED BACK  ⬜ NEEDS ATTENTION

---

**Next Steps After Deployment:**
1. Monitor root activity for 24-48 hours
2. Review CloudTrail logs weekly
3. Test break-glass procedure quarterly
4. Update compliance documentation
5. Schedule team training on new procedures

**Well done! Your AWS environment is now more secure.** 🎉

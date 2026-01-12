# Root Account Protection SCP - Production Guide

## Overview

This Service Control Policy (SCP) implements production-grade protection against root account usage across all member accounts in your AWS Organization. It follows AWS Well-Architected Framework best practices and CIS AWS Foundations Benchmark recommendations.

## Policy Objectives

### Primary Goals
1. **Prevent routine root account usage** - Block all day-to-day operations using root credentials
2. **Enable break-glass access** - Allow critical account recovery and billing operations
3. **Maintain compliance** - Meet CIS Benchmark 1.7, 1.8, 1.9, and security frameworks
4. **Ensure business continuity** - Don't lock out legitimate emergency access

### What This Policy Does

#### ✅ ALLOWS (Root Account Exceptions)
- **Billing & Cost Management**: View and modify payment methods, billing preferences
- **Account Recovery**: Change root password, manage root MFA devices
- **Account Management**: View/update alternate contacts, account information
- **AWS Support**: Create and manage support cases for critical issues
- **Read-Only Operations**: View IAM summary, service quotas, organization structure
- **Logging**: Ensure CloudTrail and CloudWatch can track root activity

#### ❌ DENIES (Everything Else)
- All AWS service operations (EC2, S3, IAM user/role management, etc.)
- Infrastructure changes
- Resource creation/modification/deletion
- API calls outside the allowed exception list

## Architecture

```
AWS Organization Root
├── Management Account (NO SCP - manages organization)
├── Security OU
│   └── Security Account (SCP attached for consistency)
└── Workloads OU (SCP ATTACHED HERE)
    └── Workload Account(s) (Protected)
```

### Current Attachments
- ✅ Applied to: **Workloads OU** (all member accounts)
- ⚠️ Not applied to: Management Account (organization administrator)

## Break-Glass Scenarios

### When Root Access IS Required

1. **Lost Access to All IAM Users/Roles**
   - Root can reset IAM credentials
   - Policy allows: `iam:GetAccountSummary`, password changes

2. **Billing Emergencies**
   - Update payment methods before service suspension
   - Policy allows: All `aws-portal:*` and billing actions

3. **Account Recovery**
   - Restore access after credential compromise
   - Policy allows: MFA device management, password changes

4. **Critical Support Cases**
   - Some AWS Support cases require root account
   - Policy allows: All `support:*` actions

### When Root Access IS NOT Required

- ❌ Creating/managing IAM users (use IAM admin role)
- ❌ Launching EC2 instances (use workload roles)
- ❌ Managing S3 buckets (use IAM roles with permissions)
- ❌ Any infrastructure operations (use IAM Identity Center/SSO)
- ❌ Day-to-day operations (use federated identities)

## Implementation Details

### Policy Structure

```hcl
Statement 1: DENY all actions for root
Statement 2: ALLOW specific recovery/billing actions for root
```

The DENY statement blocks everything, then the ALLOW statement creates carve-outs for legitimate use cases. This "deny-by-default, allow-exceptions" model is most secure.

### Optional: IP-Based Break-Glass

Uncomment this section in the policy to allow root access ONLY from specific IP addresses:

```hcl
Condition = {
  StringLike = {
    "aws:PrincipalArn" = ["arn:aws:iam::*:root"]
  }
  NotIpAddress = {
    "aws:SourceIp" = [
      "203.0.113.0/24",    # Corporate office
      "198.51.100.0/24"    # DR site
    ]
  }
}
```

**Use Case**: Allow root login only from:
- Corporate VPN endpoints
- Secure bastion hosts
- SOC/NOC networks

## Deployment

### Prerequisites
```bash
# Verify AWS Organizations is enabled
aws organizations describe-organization

# Verify SCPs are enabled
aws organizations list-roots
```

### Apply Changes

```bash
cd management-account

# Preview changes
terraform plan

# Apply SCP
terraform apply

# Verify attachment
aws organizations list-policies-for-target \
  --target-id ou-xxxx-xxxxxxxx \
  --filter SERVICE_CONTROL_POLICY
```

### Rollback Plan

If issues occur, detach the policy immediately:

```bash
# Emergency detach
aws organizations detach-policy \
  --policy-id p-xxxxxxxx \
  --target-id ou-xxxx-xxxxxxxx

# Or via Terraform
terraform destroy -target=aws_organizations_policy_attachment.deny_root_workloads
```

## Monitoring & Detection

### CloudWatch Alarms

Create alarms for root account activity:

```bash
# Root account login alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "Root-Account-Login" \
  --alarm-description "Alert on root account console login" \
  --metric-name RootAccountUsage \
  --namespace AWS/CloudTrail \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold
```

### CloudTrail Event Pattern

Monitor these CloudTrail events:

```json
{
  "userIdentity": {
    "type": "Root",
    "arn": ["arn:aws:iam::*:root"]
  },
  "eventType": ["AwsApiCall", "AwsConsoleSignIn"]
}
```

### EventBridge Rule

```json
{
  "source": ["aws.signin"],
  "detail-type": ["AWS Console Sign In via CloudTrail"],
  "detail": {
    "userIdentity": {
      "type": ["Root"]
    }
  }
}
```

**Action**: Send to SNS → PagerDuty → Security team

## Testing

### Test Plan

1. **Verify Denial Works**
   ```bash
   # Login as root to workload account
   # Try to list S3 buckets
   aws s3 ls
   # Expected: Access Denied (SCP restriction)
   ```

2. **Verify Billing Access**
   ```bash
   # Login as root
   # Navigate to Billing Dashboard
   # Expected: Success
   ```

3. **Verify MFA Management**
   ```bash
   # Login as root
   # Go to Security Credentials
   # Enable/manage MFA device
   # Expected: Success
   ```

4. **Verify IAM Role Works**
   ```bash
   # Login via SSO/IAM user
   # Assume admin role
   aws s3 ls
   # Expected: Success (not root, not blocked)
   ```

## Compliance Mapping

| Framework | Control | Status |
|-----------|---------|--------|
| CIS AWS v1.5.0 | 1.7 - Eliminate root account usage | ✅ |
| CIS AWS v1.5.0 | 1.8 - Root MFA enabled | ✅ (allows MFA mgmt) |
| CIS AWS v1.5.0 | 1.9 - Root password rotation | ✅ (allows pwd change) |
| NIST 800-53 | AC-2 - Account Management | ✅ |
| PCI-DSS v4.0 | 7.2.1 - Access controls | ✅ |
| AWS Well-Architected | SEC02-BP04 - Centralized identity | ✅ |
| SOC 2 Type II | CC6.1 - Logical access | ✅ |

## Troubleshooting

### Issue: "Access Denied" for Legitimate Root Operation

**Symptom**: Root user blocked from required action

**Solution**:
1. Verify action is in the ALLOW list
2. If not, add to policy exceptions
3. Apply via Terraform
4. Wait 5 minutes for propagation

### Issue: Can't Attach SCP to Management Account

**Symptom**: Error attaching policy to management account

**Explanation**: This is expected and correct
- Management account should NOT have restrictive SCPs
- It needs full access to manage the organization
- Root protection should be via preventive controls (locked away credentials, MFA)

### Issue: Root Still Has Access

**Symptom**: Root can perform blocked actions

**Checks**:
```bash
# 1. Verify SCP is attached
aws organizations list-policies-for-target --target-id <account-id> \
  --filter SERVICE_CONTROL_POLICY

# 2. Check effective permissions
aws organizations describe-effective-policy \
  --policy-type SERVICE_CONTROL_POLICY \
  --target-id <account-id>

# 3. Verify you're in member account (not management account)
aws sts get-caller-identity
```

## Best Practices

### ✅ DO

1. **Store root credentials in secure vault** (1Password, LastPass Enterprise, AWS Secrets Manager)
2. **Enable root MFA** with hardware device (YubiKey)
3. **Document break-glass procedures** in runbook
4. **Monitor root login attempts** with CloudWatch + SNS
5. **Rotate root password annually** (allowed by policy)
6. **Test break-glass quarterly** with tabletop exercises
7. **Use IAM Identity Center** for all normal access
8. **Apply SCP to all member accounts** (not management account)

### ❌ DON'T

1. **Don't share root credentials** across team members
2. **Don't use root for automation** (use IAM roles)
3. **Don't apply SCP to management account** (breaks organization management)
4. **Don't remove all exceptions** (creates account lockout risk)
5. **Don't use root for daily ops** even if technically possible
6. **Don't store root credentials in code** or config files

## Security Considerations

### Defense in Depth

This SCP is ONE layer. Complete root protection requires:

```
Layer 1: Preventive - Credentials locked in vault ✅
Layer 2: Detective - CloudTrail logging ✅
Layer 3: Response - CloudWatch alarms ✅
Layer 4: Technical - SCPs (this policy) ✅
Layer 5: Administrative - Runbooks & training ✅
```

### Residual Risks

- ⚠️ **Management account root** is not protected by SCP
- ⚠️ **Billing actions** are still allowed (necessary)
- ⚠️ **Physical access** to MFA device compromises root
- ⚠️ **AWS Support** could reset root (requires verification)

### Mitigations

1. Management account: Apply compensating controls (AWS Control Tower guardrails)
2. Billing actions: Monitor with CloudTrail, alert on usage
3. MFA device: Store in secure facility, document custody chain
4. AWS Support: Enable enhanced support verification

## References

- [AWS SCP Documentation](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html)
- [CIS AWS Foundations Benchmark](https://www.cisecurity.org/benchmark/amazon_web_services)
- [AWS Root Account Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_root-user.html)
- [AWS Organizations Policy Examples](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps_examples.html)

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-01-12 | Initial production-grade SCP implementation | Security Team |

## Support

For questions or issues:
- **Security Team**: security@example.com
- **On-call**: PagerDuty escalation policy
- **Documentation**: This file + runbooks in `/security-detections/runbooks/`

---

**Classification**: Internal Use Only
**Last Updated**: 2026-01-12
**Review Frequency**: Quarterly

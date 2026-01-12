# Root Account Usage Detection & Response Runbook

## 🚨 Alert: Root Account Activity Detected

**Severity**: CRITICAL
**Response Time**: Immediate (< 5 minutes)
**Escalation**: Security Team → CISO

---

## Initial Response (First 5 Minutes)

### 1. Verify Alert Legitimacy

**Check CloudTrail Event**:
```bash
# Get root activity in last hour
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=root \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --max-results 10 \
  --region us-east-1
```

**Key Information to Capture**:
- ✅ Event time
- ✅ Source IP address
- ✅ User agent
- ✅ Action performed
- ✅ Account ID
- ✅ Success/failure status

### 2. Determine If Authorized

**Ask These Questions**:
1. ❓ Was this a planned break-glass procedure?
   - Check change calendar
   - Check emergency response log

2. ❓ Is the source IP recognized?
   - Corporate VPN: `X.X.X.X/24`
   - Office network: `Y.Y.Y.Y/24`
   - Home IPs of authorized personnel

3. ❓ Was the action allowed by SCP?
   - Billing operations → Expected
   - Infrastructure changes → ALERT

### 3. Immediate Actions Based on Assessment

#### ✅ AUTHORIZED ACCESS
```bash
# Document in incident log
echo "$(date): Authorized root access by [NAME] - [REASON]" >> /var/log/root-access.log

# Verify action completed
# Monitor for completion
# Close alert
```

#### ⚠️ SUSPICIOUS BUT UNCLEAR
```bash
# Continue investigation
# Don't take action yet
# Escalate to senior responder
# Keep monitoring
```

#### 🔴 CONFIRMED UNAUTHORIZED
**IMMEDIATELY EXECUTE INCIDENT RESPONSE** (see below)

---

## Incident Response Procedures

### Phase 1: Containment (Minutes 5-15)

#### Action 1: Revoke Active Sessions

```bash
# Get account ID from alert
ACCOUNT_ID="123456789012"

# Create session revocation policy (management account)
cat > /tmp/revoke-sessions.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*",
      "Condition": {
        "DateLessThan": {
          "aws:TokenIssueTime": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        }
      }
    }
  ]
}
EOF

# Apply to security group (requires IAM admin role)
aws iam put-group-policy \
  --group-name EmergencyRootRevocation \
  --policy-name RevokeAllSessions-$(date +%s) \
  --policy-document file:///tmp/revoke-sessions.json
```

#### Action 2: Reset Root Password

```bash
# This requires console access and MFA
# Steps:
# 1. Login to compromised account as IAM admin
# 2. Navigate to: My Account → Security Credentials
# 3. Click "Send password reset email"
# 4. Security team retrieves reset email
# 5. Reset password IMMEDIATELY
```

**⚠️ NOTE**: Root password reset requires access to root email account

#### Action 3: Lock Root Email Account

```bash
# Contact email administrator
# Reset email password
# Enable MFA on email if not already enabled
# Review email forwarding rules for compromise
```

#### Action 4: Enable MFA (If Not Enabled)

```bash
# Via AWS Console:
# 1. Login as IAM administrator
# 2. AWS Console → Account → Security Credentials
# 3. Assign hardware MFA to root
# 4. Secure hardware token in vault
```

### Phase 2: Investigation (Minutes 15-30)

#### Forensics Checklist

**1. Full Activity Timeline**
```bash
# Get ALL root activity for past 30 days
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=root \
  --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%S) \
  --max-results 50 \
  --query 'Events[*].[EventTime,EventName,Username,SourceIPAddress]' \
  --output table > root-activity-$(date +%s).txt
```

**2. Check for Persistence Mechanisms**
```bash
# Look for backdoor users
aws iam list-users --output table

# Look for new access keys
aws iam list-access-keys --user-name root

# Look for new IAM roles with trust policies
aws iam list-roles --query 'Roles[?CreateDate>=`2026-01-10`]'

# Look for modified IAM policies
aws iam list-policies --scope Local --only-attached \
  --query 'Policies[?CreateDate>=`2026-01-10` || UpdateDate>=`2026-01-10`]'
```

**3. Resource Enumeration**
```bash
# Check for unauthorized resources
# EC2 instances
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,State.Name,LaunchTime]' --output table

# S3 buckets (check for data exfiltration)
aws s3api list-buckets --query 'Buckets[?CreationDate>=`2026-01-10`]'

# Lambda functions (check for crypto miners)
aws lambda list-functions --query 'Functions[?LastModified>=`2026-01-10T00:00:00`]'

# Check billing for unexpected charges
aws ce get-cost-and-usage \
  --time-period Start=2026-01-10,End=2026-01-12 \
  --granularity DAILY \
  --metrics BlendedCost
```

**4. Network Analysis**
```bash
# Check VPC Flow Logs for attacker IP
aws ec2 describe-flow-logs

# Check for security group changes
aws ec2 describe-security-groups \
  --filters Name=ip-permission.cidr,Values=0.0.0.0/0

# Check for public snapshots (data leak)
aws ec2 describe-snapshots --owner-ids self \
  --query 'Snapshots[?Public==`true`]'
```

### Phase 3: Eradication (Minutes 30-60)

#### Remove Attacker Access

**1. Delete Unauthorized Resources**
```bash
# Example: Delete unauthorized IAM user
aws iam delete-user --user-name suspicious-user

# Example: Terminate unauthorized instances
aws ec2 terminate-instances --instance-ids i-1234567890abcdef0

# Example: Delete exposed snapshots
aws ec2 delete-snapshot --snapshot-id snap-1234567890abcdef0
```

**2. Rotate All Credentials**
```bash
# List all IAM users
aws iam list-users --output table

# For each user, disable access keys
for user in $(aws iam list-users --query 'Users[*].UserName' --output text); do
  echo "Processing user: $user"
  for key in $(aws iam list-access-keys --user-name $user --query 'AccessKeyMetadata[*].AccessKeyId' --output text); do
    echo "  Deactivating key: $key"
    aws iam update-access-key --user-name $user --access-key-id $key --status Inactive
  done
done
```

**3. Review and Tighten SCPs**
```bash
# Verify SCP is attached
aws organizations list-policies-for-target \
  --target-id ou-xxxx-xxxxxxxx \
  --filter SERVICE_CONTROL_POLICY

# Consider adding IP restriction (if not already present)
# Edit: management-account/org-account.tf
# Add NotIpAddress condition to root deny policy
```

### Phase 4: Recovery (Hour 1-2)

#### Restore Normal Operations

**1. Communicate Status**
```bash
# Notify stakeholders
# - Security team: incident contained
# - Engineering: credential rotation required
# - Leadership: impact assessment
```

**2. Issue New Credentials**
```bash
# Generate new access keys for legitimate users
# Distribute via secure channel (1Password, Vault)
# Verify users can authenticate
```

**3. Monitor for Recurring Activity**
```bash
# Set up enhanced CloudWatch alarms
aws cloudwatch put-metric-alarm \
  --alarm-name "Root-Account-Login-Enhanced" \
  --alarm-description "Enhanced monitoring post-incident" \
  --metric-name RootAccountUsage \
  --namespace Custom/Security \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:SecurityAlerts
```

### Phase 5: Post-Incident (Day 1-7)

#### 1. Root Cause Analysis

**Questions to Answer**:
- How did attacker gain root credentials?
- What vulnerabilities were exploited?
- What was the blast radius?
- What controls failed?
- What controls worked?

#### 2. Lessons Learned

**Document**:
- Timeline of events
- Actions taken
- What worked well
- What needs improvement
- Recommendations

#### 3. Implement Improvements

**Action Items**:
- [ ] Update SCP with stricter conditions
- [ ] Implement IP-based restrictions
- [ ] Enhance monitoring/alerting
- [ ] Conduct security training
- [ ] Review privileged access procedures
- [ ] Implement hardware MFA for root
- [ ] Enable GuardDuty if not active
- [ ] Review break-glass procedures

---

## Prevention Measures

### Before an Incident

**1. Secure Root Credentials**
```
- Store in enterprise password vault (1Password, LastPass)
- Require MFA (hardware token preferred)
- Limit knowledge of credentials to 2-3 senior personnel
- Document location in secure wiki
```

**2. Implement Detective Controls**
```bash
# CloudWatch alarm for root login
aws cloudwatch put-metric-alarm \
  --alarm-name "RootAccountLogin" \
  --metric-name RootAccountLogin \
  --namespace AWS/CloudTrail \
  --statistic Sum \
  --period 60 \
  --evaluation-periods 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions arn:aws:sns:us-east-1:123456789012:SecurityAlerts

# EventBridge rule for root API calls
aws events put-rule \
  --name "RootAccountActivity" \
  --event-pattern '{
    "detail": {
      "userIdentity": {
        "type": ["Root"]
      }
    }
  }' \
  --state ENABLED

# SNS notification
aws events put-targets \
  --rule "RootAccountActivity" \
  --targets "Id"="1","Arn"="arn:aws:sns:us-east-1:123456789012:SecurityAlerts"
```

**3. Regular Testing**
```bash
# Quarterly: Test break-glass procedure
# Monthly: Review root access logs
# Weekly: Verify SCP attachments
# Daily: Monitor alerts
```

---

## Escalation Matrix

| Time Elapsed | Action | Contact |
|--------------|--------|---------|
| 0-5 min | Initial assessment | On-call engineer |
| 5-15 min | Containment actions | Security team lead |
| 15-30 min | Full investigation | CISO + Security team |
| 30-60 min | Eradication | Security + Engineering leads |
| 1+ hour | Recovery | All stakeholders |

---

## Communication Templates

### Initial Alert (Slack/Email)

```
🚨 SECURITY ALERT: Root Account Activity Detected

Account: 123456789012 (workload-production)
Time: 2026-01-12 14:32:15 UTC
Action: ec2:RunInstances
Source IP: 203.0.113.45
Status: INVESTIGATING

Incident Commander: [NAME]
Bridge: https://zoom.us/j/emergency
Slack: #security-incident-response

Updates every 15 minutes or as status changes.
```

### All-Clear Notification

```
✅ INCIDENT RESOLVED: Root Account Activity

Incident ID: INC-2026-001
Status: RESOLVED
Root Cause: [Brief description]
Impact: [None/Limited/Moderate]
Actions Taken:
- Root password reset
- Sessions revoked
- Unauthorized resources deleted
- Credentials rotated

Post-incident review scheduled for [DATE]
Full report: [LINK]
```

---

## Tools & Resources

### AWS CLI Commands
```bash
# Quick reference for common tasks
alias root-activity="aws cloudtrail lookup-events --lookup-attributes AttributeKey=Username,AttributeValue=root --max-results 10"
alias check-scps="aws organizations list-policies-for-target --filter SERVICE_CONTROL_POLICY"
alias list-iam-users="aws iam list-users --output table"
```

### Useful Links
- CloudTrail Console: https://console.aws.amazon.com/cloudtrail/
- IAM Console: https://console.aws.amazon.com/iam/
- Root Account SCP Guide: `/management-account/ROOT-ACCOUNT-SCP-GUIDE.md`
- Security Services: `/management-account/SECURITY-SERVICES-GUIDE.md`

### On-Call Contacts
- Security Team: security@example.com
- PagerDuty: https://example.pagerduty.com
- CISO Mobile: +1-XXX-XXX-XXXX
- AWS Support (Enterprise): 1-800-XXX-XXXX

---

**Document Owner**: Security Team
**Last Updated**: 2026-01-12
**Review Frequency**: Quarterly
**Next Review**: 2026-04-12

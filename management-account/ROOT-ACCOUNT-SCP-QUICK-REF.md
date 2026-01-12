# Root Account SCP - Quick Reference Card

**Last Updated**: 2026-01-12
**Policy Name**: DenyRootAccountUsage
**Applied To**: Workloads OU (all member accounts)

---

## 🎯 Quick Facts

| Item | Value |
|------|-------|
| **Accounts Protected** | All member accounts in Workloads OU |
| **Management Account** | NOT protected (by design) |
| **Policy Type** | Deny-by-default with exceptions |
| **Compliance** | CIS 1.7, 1.8, 1.9 ✅ |
| **Status** | Production-Ready ✅ |

---

## ⚡ Emergency Procedures

### 🚨 Detected Root Login?
1. Check alert: Is it authorized?
2. If NO → Execute [root-account-incident.md](../security-detections/runbooks/root-account-incident.md)
3. If YES → Document in change log

### 🔥 Need Root Access? (Break-Glass)
1. Retrieve credentials from vault (1Password)
2. Login to AWS Console as root
3. ✅ You CAN: Billing, account recovery, MFA management
4. ❌ You CANNOT: EC2, S3, IAM, Lambda, infrastructure changes
5. Log activity in break-glass log

### 🔐 Lost All Access?
1. Root account CAN still login
2. Root CAN reset IAM user passwords
3. Root CAN manage MFA devices
4. Root CANNOT create new IAM users (use AWS Support)

---

## ✅ What Root CAN Do (60+ Actions)

### Billing & Payments
- View billing dashboard
- Update payment methods
- View invoices and cost reports
- Manage billing preferences
- View tax information

### Account Management
- View/update account contacts
- View account information
- Change root password
- Manage root MFA device

### Support & Recovery
- Create AWS Support cases
- View Trusted Advisor checks
- View service health

### Monitoring (Read-Only)
- View CloudTrail events
- View IAM account summary
- View service quotas

---

## ❌ What Root CANNOT Do

- Launch EC2 instances
- Create/modify S3 buckets
- Create IAM users/roles
- Modify security groups
- Create Lambda functions
- Anything infrastructure-related

**→ Use IAM roles with proper permissions instead**

---

## 📞 Contacts

| Role | Contact |
|------|---------|
| **Security Team** | security@example.com |
| **On-Call** | PagerDuty escalation |
| **CISO** | +1-XXX-XXX-XXXX |
| **AWS Support** | Enterprise support line |

---

## 📚 Documentation Links

| Document | Purpose |
|----------|---------|
| [ROOT-ACCOUNT-SCP-GUIDE.md](./ROOT-ACCOUNT-SCP-GUIDE.md) | Complete implementation guide |
| [root-account-incident.md](../security-detections/runbooks/root-account-incident.md) | Incident response playbook |
| [README.md](./README.md) | Management account overview |

---

## 🔧 Quick Commands

```bash
# Check root activity (last 24 hours)
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=root \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --max-results 10

# Verify SCP attachment
aws organizations list-policies-for-target \
  --target-id ou-xxxx-xxxxxxxx \
  --filter SERVICE_CONTROL_POLICY

# Get effective policy for account
aws organizations describe-effective-policy \
  --policy-type SERVICE_CONTROL_POLICY \
  --target-id 123456789012
```

---

## 🎓 Training Resources

**For Developers**:
- Use IAM Identity Center (SSO) for access
- Never use root for deployments
- Use service roles for applications

**For Security Team**:
- Monitor CloudTrail for root logins
- Review break-glass logs monthly
- Test emergency procedures quarterly

**For Leadership**:
- Root account is locked down by policy
- Emergency access still available
- Compliance requirements met

---

## ⚠️ Important Notes

1. **Management Account**: This SCP is NOT applied to the management account (by design). Management account root must remain unrestricted to manage the organization.

2. **Break-Glass**: Root can still login and perform billing/recovery operations. This is INTENTIONAL for emergencies.

3. **IAM Roles**: IAM users and roles are UNAFFECTED by this policy. Normal operations continue unchanged.

4. **Monitoring**: All root activity is logged in CloudTrail. Set up alarms!

5. **Testing**: Test this policy in non-production first. Verify IAM access works before applying to production.

---

**Print this card and keep it with on-call documentation!**

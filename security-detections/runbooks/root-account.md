# 🚨 Root Account Usage Detection

## Severity
Critical

## Estimated Investigation Time
**30-60 minutes**

## Compliance Scope
- **SOC 2:** CC6.1 (Logical Access Controls)
- **PCI-DSS:** 7.1 (Access Control - Least Privilege)
- **HIPAA:** 164.312(a)(1) (Access Control)
- **GDPR:** Article 32 (Security of Processing)

## Trigger

• OpenSearch alert indicating root account activity
• CloudTrail event where user.identity.type = Root

⸻

## Why This Matters

The AWS root account has unrestricted privileges and bypasses IAM controls.
Any use of the root account significantly increases blast radius and may indicate:

• Credential compromise
• Policy bypass
• Accidental or unauthorized administrative access
• Elevated financial and operational risk

Root account usage is treated as a zero-tolerance event.

⸻

## OpenSearch Query Example

```json
{
  "query": {
    "bool": {
      "must": [
        {
          "term": {
            "class_name": "API Activity"
          }
        },
        {
          "term": {
            "actor.user.type": "Root"
          }
        }
      ]
    }
  },
  "sort": [
    {
      "time": {
        "order": "desc"
      }
    }
  ]
}
```

**Index Pattern:** `securitylake-cloudtrail-*`
**OCSF Field:** `actor.user.type = "Root"`

**AWS CLI Alternative:**
```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=root \
  --max-results 50 \
  --region us-east-1
```

⸻

## Investigation Steps

1. Identify the source IP address from CloudTrail
2. Review all API actions performed during the session
3. Verify whether MFA was used
4. Confirm the time, region, and duration of activity
5. Determine whether the activity was authorized or expected
6. Correlate with other security signals (GuardDuty, VPC Flow Logs)

⸻

## Containment Actions

1. Immediately rotate root account credentials
2. Enable or re-enforce MFA on the root account
3. Restrict root permissions using Service Control Policies where feasible
4. Temporarily suspend sensitive operations if compromise is suspected

⸻

## Remediation Steps

• Perform a full IAM audit (users, roles, policies)
• Review recent infrastructure changes and deployments
• Rotate any potentially exposed credentials
• Update internal security policies and access procedures
• Educate stakeholders on root account usage policies

⸻

## Validation

• Confirm no further root account activity occurs
• Verify MFA enforcement is active
• Ensure all remediation actions are completed
• Close alert once environment integrity is restored

⸻

## Common False Positives

- **Account setup:** Initial AWS account creation (expected once)
- **Billing inquiries:** Root-only billing console access (rare, but legitimate)
- **Support cases:** AWS Support requiring root authentication

**Expected Frequency:** 0-2 occurrences per year for mature organizations

⸻

## Escalation Criteria

**Escalate IMMEDIATELY to CISO if:**
- Root access was NOT authorized
- Suspicious API calls detected (IAM changes, resource deletion)
- MFA was NOT used
- Source IP is not from corporate network

**Notification Timeline:** Within 15 minutes of detection
**Notification Channel:** Slack #security-critical, Email: ciso@company.com, PagerDuty

⸻

## DLQ Handling (Alert Delivery Failure)

If the alert was not delivered successfully:

1. Check SQS queue: soc-security-alerts-dlq
2. Identify failed alert messages
3. Investigate SNS, IAM, or notification destination issues
4. Manually notify SOC stakeholders if required
5. Clear DLQ messages after delivery is restored

⸻

## Related MITRE ATT&CK

• **T1078** – Valid Accounts (Cloud Accounts - T1078.004)

**Tactic:** Initial Access, Persistence, Privilege Escalation, Defense Evasion

⸻

## Related Runbooks

- [GuardDuty Detection](./guardduty.md) - If credential compromise suspected
- [Terraform State Access](./terraform-state.md) - If infrastructure credentials at risk

⸻

## SOC Note

Root account access should be extremely rare.
Every occurrence must be investigated, documented, and justified.

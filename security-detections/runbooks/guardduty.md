# 🚨 GuardDuty High / Critical Threat Detection

## Severity
Critical

## Estimated Investigation Time
**30-90 minutes** (varies by finding complexity)

## Compliance Scope
- **SOC 2:** CC7.2 (System Monitoring)
- **PCI-DSS:** 10.6 (Log Review)
- **HIPAA:** 164.312(b) (Audit Controls)
- **GDPR:** Article 32 (Security of Processing)

## Trigger
• AWS GuardDuty finding with severity HIGH or CRITICAL

## Why This Matters

High and Critical GuardDuty findings indicate active or imminent security threats,
including but not limited to:

• Malware execution
• Cryptocurrency mining
• Credential compromise
• Backdoor or command-and-control activity
• Data exfiltration attempts

These findings require immediate investigation and response.

⸻

## OpenSearch Query Example

```json
{
  "query": {
    "bool": {
      "must": [
        {
          "term": {
            "class_name": "Security Finding"
          }
        },
        {
          "term": {
            "metadata.product.name": "GuardDuty"
          }
        },
        {
          "range": {
            "severity_id": {
              "gte": 4
            }
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

**Index Pattern:** `securitylake-guardduty-*`
**OCSF Severity Mapping:** 4 = High, 5 = Critical

⸻

## Investigation Steps

1. Review GuardDuty finding details:
   • Finding type (e.g., `CryptoCurrency:EC2/BitcoinTool.B!DNS`, `Trojan:EC2/DNSDataExfiltration`)
   • Resource type (EC2, IAM, S3, EKS, etc.)
   • Affected account and region
2. Identify the impacted resource and its role in the environment
3. Correlate activity with:
   • VPC Flow Logs
   • CloudTrail events
   • OpenSearch security dashboards
4. Review recent IAM activity related to the resource
5. Validate whether the activity is expected or potentially malicious

⸻

## Containment Actions

1. Isolate affected EC2 instances:
   • Remove internet access
   • Apply restrictive security groups
2. Take snapshots or forensic images for analysis
3. Disable or rotate potentially compromised IAM credentials
4. Block known malicious IPs or domains if applicable

⸻

## Remediation Steps

• Patch exploited vulnerabilities
• Remove malicious binaries or processes
• Rotate credentials and enforce MFA
• Review and tighten IAM permissions
• Apply additional monitoring where gaps were identified

⸻

## Validation

• Confirm GuardDuty finding is resolved or archived
• Ensure no additional related findings appear
• Verify normal system behaviour is restored
• Document investigation outcome

⸻

## Common False Positives

- **Bitcoin DNS queries:** Security scanners or threat intelligence tools
- **Port scanning:** Approved vulnerability scanners (Qualys, Nessus)
- **Anonymous access:** Public S3 buckets with legitimate public content

**Action:** Validate source is approved, then suppress finding in GuardDuty

⸻

## Escalation Criteria

**Escalate to Incident Commander if:**
- Finding indicates active data exfiltration
- Multiple resources affected (lateral movement)
- Production environment impacted
- Cannot contain within 30 minutes

**Notification:** Slack #security-critical, Email: incident-response@company.com

⸻

## DLQ Handling (Alert Delivery Failure)

If the GuardDuty alert was not delivered successfully:

1. Check SQS queue: soc-security-alerts-dlq
2. Identify failed alert messages
3. Investigate SNS, IAM, or notification destination issues
4. Manually notify SOC stakeholders if required
5. Clear DLQ messages after delivery is restored

⸻

## Related MITRE ATT&CK

• **T1204** – User Execution (Malicious Image)
• **T1059** – Command and Scripting Interpreter
• **T1078** – Valid Accounts (if credential abuse is detected)

**Tactic:** Execution

⸻

## Related Runbooks

- [Root Account Usage](./root-account.md) - If Root credentials compromised
- [VPC Scanning](./vpc-scanning.md) - If reconnaissance activity detected

⸻

## SOC Note

GuardDuty provides detection.
Response effectiveness depends on rapid containment and accurate correlation.

Speed and precision matter.

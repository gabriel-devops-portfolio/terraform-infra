# 🚨 VPC Network Scanning / Traffic Anomalies

## Severity
Medium

## Estimated Investigation Time
**20-40 minutes**

## Compliance Scope
- **SOC 2:** CC7.2 (System Monitoring)
- **PCI-DSS:** 11.4 (Network Security Testing)
- **HIPAA:** 164.312(e)(1) (Transmission Security)
- **GDPR:** Article 32 (Security of Processing)

## Trigger

• High volume of rejected VPC Flow Log traffic
• Unusual or non-standard destination ports detected
• Repeated connection attempts across multiple ports or targets

**Alert Threshold:** >100 rejected connections in 5 minutes

⸻

## Why This Matters

This activity may indicate:

• Network reconnaissance or port scanning
• Misconfigured services or exposed resources
• Early-stage lateral movement attempts

While not always malicious, this behaviour warrants investigation to prevent escalation.

⸻

## OpenSearch Query Example

```json
{
  "query": {
    "bool": {
      "must": [
        {
          "term": {
            "class_name": "Network Activity"
          }
        },
        {
          "term": {
            "connection_info.direction": "Unknown"
          }
        },
        {
          "term": {
            "disposition": "Blocked"
          }
        }
      ],
      "filter": {
        "range": {
          "time": {
            "gte": "now-5m"
          }
        }
      }
    }
  },
  "aggs": {
    "by_src_ip": {
      "terms": {
        "field": "src_endpoint.ip",
        "size": 10
      }
    }
  }
}
```

**Index Pattern:** `securitylake-vpcflow-*`
**OCSF Action:** `REJECT` or `disposition = "Blocked"`
**Detection Logic:** Count REJECT actions >100 in 5-minute window

**AWS CLI Alternative:**
```bash
aws ec2 describe-flow-logs --region us-east-1
aws logs filter-log-events \
  --log-group-name "/aws/vpc/flowlogs" \
  --filter-pattern "[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, windowstart, windowend, action=REJECT, flowlogstatus]"
```

⸻

## Investigation Steps

1. Identify source IP address and affected destination resources
2. Review destination ports and protocols involved
3. Determine whether traffic originates internally or externally
4. Correlate activity with GuardDuty findings or other alerts
5. Validate whether the traffic aligns with expected application behaviour

⸻

## Containment Actions

1. Block malicious or unauthorized source IPs using Security Groups or NACLs
2. Restrict or close unnecessary exposed ports
3. Apply temporary rate limiting or filtering if required

⸻

## Remediation Steps

• Review and harden Security Group rules
• Improve network segmentation between tiers
• Ensure least-privilege network access policies are enforced
• Validate firewall and routing configurations

⸻

## Validation

• Confirm rejected traffic volume returns to baseline
• Verify no further anomalous connection attempts occur
• Ensure application functionality is not impacted
• Close alert once behaviour is confirmed benign or remediated

⸻

## Common False Positives

- **Vulnerability scanners:** Qualys, Nessus, Tenable (approved sources)
- **Load balancer health checks:** ELB probing multiple ports
- **Container orchestration:** Kubernetes service discovery across nodes
- **Security research:** Authorized penetration testing

**Action:** Whitelist approved scanner IPs, document in exceptions list

⸻

## Escalation Criteria

**Escalate to Security Lead if:**
- Scanning originates from production workloads (lateral movement)
- High-value targets scanned (databases, admin servers)
- Scanning persists >30 minutes after initial containment
- Correlated with GuardDuty findings

**Notification:** Slack #security-alerts

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

• **T1046** – Network Service Scanning

**Tactic:** Discovery

⸻

## Related Runbooks

- [GuardDuty Detection](./guardduty.md) - If reconnaissance escalates to exploitation
- [Root Account Usage](./root-account.md) - If scanning from compromised admin access

⸻

## SOC Note

Not all scans are attacks, but all scans deserve visibility.
Early detection prevents escalation.

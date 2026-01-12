🚨 Runbook: SOC Alerting DLQ Incident

📌 Purpose

This runbook defines response procedures when the SOC alerting Dead Letter Queue (DLQ)
contains messages, indicating a failure in the alert delivery pipeline.

DLQ alerts represent an operational monitoring failure rather than a direct security
incident. However, they are treated as high priority because failed delivery may prevent
security alerts from reaching responders.

⸻

## Severity
High (Operational)

## Estimated Investigation Time
**30-60 minutes**

## Compliance Scope
- **SOC 2:** CC7.2 (System Monitoring)
- **PCI-DSS:** 10.6 (Log Review)
- **HIPAA:** 164.312(b) (Audit Controls)
- **GDPR:** Article 32 (Security Monitoring)

⸻

🔍 Trigger Condition

• CloudWatch alarm: soc-dlq-messages-present
• Condition: One or more messages present in the DLQ

⸻

🎯 Impact

• Security alerts may not be delivered to responders
• SOC visibility may be degraded
• Potential missed or delayed incident response

⸻

## OpenSearch Query Example

**DLQ Message Inspection (AWS CLI):**
```bash
# List DLQ messages
aws sqs get-queue-attributes \
  --queue-url https://sqs.us-east-1.amazonaws.com/111111222222/soc-security-alerts-dlq \
  --attribute-names ApproximateNumberOfMessages

# Receive and inspect messages (without deleting)
aws sqs receive-message \
  --queue-url https://sqs.us-east-1.amazonaws.com/111111222222/soc-security-alerts-dlq \
  --max-number-of-messages 10 \
  --visibility-timeout 0

# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/SQS \
  --metric-name ApproximateNumberOfMessagesVisible \
  --dimensions Name=QueueName,Value=soc-security-alerts-dlq \
  --start-time 2026-01-12T00:00:00Z \
  --end-time 2026-01-12T23:59:59Z \
  --period 300 \
  --statistics Sum
```

**CloudWatch Log Insights (SNS Delivery Failures):**
```
fields @timestamp, @message
| filter @message like /delivery failure/ or @message like /AccessDenied/
| sort @timestamp desc
| limit 50
```

⸻

🧠 Investigation Steps

1. Confirm the DLQ alarm state in CloudWatch
2. Identify the affected SQS DLQ queue
3. Check message count and oldest message age
4. Inspect sample messages to identify the failure source
5. Determine which component failed to deliver alerts:
   • OpenSearch notification destination
   • SNS topic or subscription
   • IAM permissions associated with alert delivery
6. Review recent configuration or IAM changes
7. Check service quotas, throttling, or regional service issues

⸻

🛠️ Containment Actions

• Manually notify SOC stakeholders if critical alerts may be blocked
• Temporarily pause affected OpenSearch monitors if misfiring
• Ensure no high-severity security alerts are silently dropped

⸻

🔄 Remediation Steps

• Fix IAM permission or configuration issues
• Validate OpenSearch notification destinations
• Confirm SNS topic and subscription health
• Reprocess or manually review DLQ messages if required
• Clear DLQ messages only after resolution is confirmed

⸻

✅ Validation

• Confirm DLQ message count returns to zero
• Trigger a test alert from OpenSearch
• Verify successful delivery to SNS and email recipients
• Confirm CloudWatch alarm returns to OK state

⸻

## Common Root Causes

- **IAM Permissions:** OpenSearchSNSRole missing `sns:Publish` permission
- **SNS Subscription:** Email not confirmed, subscription deleted
- **Service Quotas:** SNS message rate limit exceeded
- **Network Issues:** VPC endpoint or security group blocking SNS
- **Malformed Payloads:** OpenSearch monitor JSON syntax errors

**Resolution Time:** 15-30 minutes for IAM/config issues

⸻

## Escalation Criteria

**Escalate to Platform Team if:**
- DLQ messages exceed 50
- Oldest message age >2 hours
- Multiple monitors affected simultaneously
- Cannot identify root cause within 30 minutes

**Notification:** Slack #platform-engineering, PagerDuty

⸻

📘 Lessons Learned

• Document root cause and remediation steps
• Identify whether retries, thresholds, or permissions require tuning
• Evaluate whether alert delivery resilience needs improvement

⸻

🔗 Related Components

• **CloudWatch Alarm:** DLQ monitoring (`soc-dlq-messages-present`)
• **SQS DLQ:** `soc-security-alerts-dlq`
• **SNS Topics:** `soc-alerts-critical`, `soc-alerts-high`, `soc-alerts-medium`
• **IAM Role:** `OpenSearchSNSRole`
• **OpenSearch:** Notification destinations and monitors
• **AWS Security Lake:** Telemetry source

⸻

## Related Runbooks

- [GuardDuty Detection](./guardduty.md) - Critical alerts that may be affected
- [Root Account Usage](./root-account.md) - Critical alerts that must be delivered
- [VPC Scanning](./vpc-scanning.md) - Medium alerts affected by delivery failures

⸻

🧠 SOC Note

Detection without delivery is failure.

A healthy SOC pipeline ensures that every critical alert
reaches a human responder without delay.

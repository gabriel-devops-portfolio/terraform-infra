🚨 SOC Alerting & Detection Strategy

📌 Overview

This document describes the Security Operations Centre (SOC) alerting and detection strategy implemented in the Secure Multi-Account AWS Platform.

The alerting system is built on centralised security telemetry collected through AWS Security Lake, enriched with signals from CloudTrail, GuardDuty, and VPC Flow Logs. Detection and alerting are implemented using Amazon OpenSearch Security Analytics, following real-world SOC practices used in enterprise and regulated environments.

Dashboards provide visibility. Alerts drive response.

⸻

🧠 Alerting Philosophy

The alerting strategy follows these principles:

• Alerts represent meaningful security risk
• Noise and false positives are minimised
• Each alert has a clear security intent
• Alerts are severity classified
• Notifications are automated via Amazon SNS
• Every alert has a documented SOC runbook

The goal is high-signal, actionable alerting, not metric noise.

⸻

🧩 Detection & Alerting Architecture

Security alerts are generated using OpenSearch monitors, not direct EventBridge rules.
This enables richer query logic, thresholding, and SOC-style detection workflows.

High-level flow:

• Security events occur across AWS accounts
• Events are ingested and normalised by AWS Security Lake
• OpenSearch monitors evaluate detection logic
• Alerts are routed based on severity to SNS topics
• Alert delivery is protected by a Dead Letter Queue (DLQ)
• DLQ health is monitored independently to prevent alert loss

EventBridge / CloudWatch are used only for DLQ monitoring, not for primary security detections.

⸻

🚨 Implemented Alerts

1️⃣ GuardDuty High / Critical Findings

Triggers when AWS GuardDuty reports high-risk or critical findings, such as malware execution, credential compromise, or active exploitation.

Severity: Critical

Detection Logic (text representation):
severity.label IN (“HIGH”, “CRITICAL”)

Action:
Send notification to SNS topic: soc-alerts-critical

Mapped Runbook:
security-detections/runbooks/guardduty.md

SOC Meaning:
Active high-risk threat detected that requires immediate investigation.

⸻

2️⃣ Root Account Activity (Zero Tolerance)

Triggers on any usage of the AWS root account. Root credentials bypass IAM controls and are treated as a critical security event.

Severity: Critical

Detection Logic (text representation):
user.identity.type equals Root

Action:
Send notification to SNS topic: soc-alerts-critical

Mapped Runbook:
security-detections/runbooks/root-account.md

SOC Meaning:
Potential account compromise or policy violation requiring immediate containment.

⸻

3️⃣ Excessive Rejected VPC Traffic

Detects unusually high volumes of rejected VPC traffic, which may indicate scanning, misconfiguration, or lateral movement attempts.

Severity: Medium

Detection Logic (text representation):
VPC Flow Log action equals REJECT
Count greater than 100 events within 10 minutes

Action:
Send notification to SNS topic: soc-alerts-medium

Mapped Runbook:
security-detections/runbooks/vpc-scanning.md

SOC Meaning:
Suspicious network behaviour that warrants investigation.

⸻

4️⃣ Terraform State Access Outside Approved Roles

Terraform state files often contain sensitive infrastructure metadata and credentials. This alert triggers when state files are accessed outside approved backend or CI/CD roles.

Severity: High

Detection Logic (text representation):
api.request.object.key contains terraform.tfstate
AND user.identity.arn NOT matching TerraformBackendRole

Action:
Send notification to SNS topic: soc-alerts-high

Mapped Runbook:
security-detections/runbooks/terraform-state.md

SOC Meaning:
Potential infrastructure compromise or unauthorised access to sensitive data.

⸻

📊 Alert Severity, MITRE Mapping & Routing
| Alert Type                     | Severity  | SNS Topic            | MITRE Technique | Security Impact                     |
|--------------------------------|-----------|----------------------|-----------------|-------------------------------------|
| GuardDuty High / Critical      | Critical  | soc-alerts-critical  | T1204           | Active threat execution             |
| Root Account Activity          | Critical  | soc-alerts-critical  | T1078           | Privileged account abuse            |
| Terraform State Access         | High      | soc-alerts-high      | T1552           | Exposure of sensitive credentials  |
| VPC Scanning / Traffic Anomaly | Medium    | soc-alerts-medium    | T1046           | Network reconnaissance             |

⸻
🔔 Notification & Escalation

Alerts are routed through severity-based SNS topics to ensure appropriate escalation:

• Critical alerts require immediate response
• High alerts indicate infrastructure integrity risk
• Medium alerts represent suspicious behaviour

SNS subscriptions currently deliver alerts via email and can be extended to:
• Slack
• PagerDuty
• SIEM platforms

⸻

🧯 Alert Delivery Protection (DLQ)

Alert delivery reliability is protected using an SQS Dead Letter Queue (DLQ).

• If alert delivery fails, the message is sent to the DLQ
• A CloudWatch alarm monitors the DLQ for undelivered messages
• DLQ alerts indicate a monitoring pipeline failure, not a security incident

Mapped Runbook:
security-detections/runbooks/dlq-alerting.md

⸻

🔗 OpenSearch Notification Destinations

OpenSearch monitors send alerts via Notification Destinations.

Each destination maps to an SNS topic created via Terraform:

• soc-alerts-critical
• soc-alerts-high
• soc-alerts-medium

Each SNS topic is registered once in OpenSearch.
Monitor triggers reference the destination_id returned by OpenSearch.

⸻

📘 SOC Runbooks

Each alert is mapped to a SOC runbook located at:

security-detections/runbooks/

Runbooks provide step-by-step guidance for:

• Investigation
• Validation
• Containment
• Remediation
• Post-incident review

This ensures consistent, repeatable incident response.

⸻

🎯 Why This Matters

This alerting and detection framework demonstrates:

• SOC-style cloud security operations
• Threat-driven detection design
• Practical use of AWS Security Lake
• OpenSearch-based security analytics
• Severity-based escalation
• Alignment with MITRE ATT&CK
• Operational security maturity

It shows not only how infrastructure is secured, but how security is actively monitored, detected, and operated in practice.

🚨 ALERT 1: GuardDuty HIGH / CRITICAL Findings

  Alert Severity
    • CRITICAL

  Trigger
    • Count ≥ 1
    • Event Severity = HIGH or CRITICAL
    • Window = 5 minutes

  Query
    severity.label IN ("HIGH","CRITICAL")

  Action
    • Send to SNS topic soc-security-alerts

  SOC Meaning
    Active high-risk threat detected requiring immediate investigation

  Mapped Runbook
    • security-detections/runbooks/guardduty.md


🚨 ALERT 2: Root Account Activity (ZERO tolerance)

  Alert Severity
    • CRITICAL

  Trigger
    • Count ≥ 1
    • Immediate

  Query
    user.identity.type : "Root"

  Action
    • Send to SNS topic soc-security-alerts

  SOC Meaning
    Root account usage detected — potential account compromise

  Mapped Runbook
  • security-detections/runbooks/root-account.md


🚨 ALERT 3: Excessive REJECTED VPC Traffic

  Alert Severity
    • MEDIUM

  Trigger
    • REJECT count > 100 in 10 minutes

  Query
    action : "REJECT"

  Action
    • Send to SNS topic soc-security-alerts

  SOC Meaning
    Possible scanning, misconfiguration, or network-based attack
  Mapped Runbook
    • security-detections/runbooks/vpc-scanning.md


🚨 ALERT 4: Terraform State Access

  Alert Severity
    • HIGH

  Trigger
    • Any access outside CI/CD role

  Query
    api.request.object.key : "*terraform.tfstate*"
    AND NOT user.identity.arn : "*TerraformBackendRole*"

  Action
    • Send to SNS topic soc-security-alerts

  SOC Meaning
    Terraform state accessed by unauthorized identity — infrastructure compromise risk

  Mapped Runbook
    • security-detections/runbooks/terraform-state.md

# Security Detection & Response Strategy

**Version:** 2.0
**Last Updated:** January 12, 2026
**Status:** Production Ready

This directory contains the documentation and artifacts that define the security detection and response strategy for the platform. It serves as a central knowledge base for security analysts, engineers, and architects.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Runbooks](#runbooks)
- [MITRE ATT&CK Mapping](#mitre-attck-mapping)
- [Incident Response Templates](#incident-response-templates)
- [Detection Coverage](#detection-coverage)
- [Compliance Coverage](#compliance-coverage)
- [How to Use](#how-to-use)
- [Contributing](#contributing)
- [Response SLAs](#response-slas)
- [References](#references)

---

## Overview

The goal of this documentation is to ensure that security operations are consistent, effective, and aligned with industry best practices. It provides the necessary guidance for identifying, investigating, and responding to security threats.

**Key Features:**
- ✅ Standardized runbooks for 5 detection types
- ✅ MITRE ATT&CK framework integration
- ✅ OpenSearch query examples for every detection
- ✅ Investigation time estimates
- ✅ Compliance mappings (SOC 2, PCI-DSS, HIPAA, GDPR)
- ✅ Escalation procedures with SLA targets
- ✅ Incident response templates

---

## Directory Structure

```
security-detections/
├── README.md                          # This file
├── DOCUMENTATION-REVIEW.md            # Quality assessment
├── mitre-mapping.md                   # MITRE ATT&CK coverage table
├── mitre-mapping.yaml                 # Machine-readable MITRE mapping
├── runbooks/                          # SOC analyst procedures
│   ├── guardduty.md                   # GuardDuty threat detection
│   ├── root-account.md                # Root account usage
│   ├── vpc-scanning.md                # Network reconnaissance
│   ├── terraform-state.md             # Infrastructure credential access
│   └── dlq-alerting.md                # Alert delivery failures
└── templates/                         # Incident response templates
    ├── incident-report.md             # Incident documentation
    ├── post-incident-review.md        # PIR template
    └── escalation-checklist.md        # Escalation procedures
```

---

## Runbooks

The `runbooks/` subdirectory contains detailed, step-by-step procedures for Security Operations Center (SOC) analysts to follow when a specific security alert is triggered.

### Available Runbooks

| Runbook | Severity | Est. Time | Data Source | MITRE Technique |
|---------|----------|-----------|-------------|-----------------|
| [GuardDuty Detection](./runbooks/guardduty.md) | Critical | 30-90 min | GuardDuty | T1204 (User Execution) |
| [Root Account Usage](./runbooks/root-account.md) | Critical | 30-60 min | CloudTrail | T1078 (Valid Accounts) |
| [Terraform State Access](./runbooks/terraform-state.md) | High | 45-75 min | CloudTrail | T1552 (Unsecured Credentials) |
| [VPC Network Scanning](./runbooks/vpc-scanning.md) | Medium | 20-40 min | VPC Flow Logs | T1046 (Network Scanning) |
| [DLQ Alerting](./runbooks/dlq-alerting.md) | High (Ops) | 30-60 min | CloudWatch | Operational |

### Runbook Structure

Each runbook includes:

1. **Severity** - Critical/High/Medium/Low classification
2. **Estimated Investigation Time** - How long investigation typically takes
3. **Compliance Scope** - SOC 2, PCI-DSS, HIPAA, GDPR mappings
4. **Trigger** - What causes the alert to fire
5. **Why This Matters** - Business/security impact
6. **OpenSearch Query Example** - Ready-to-use queries for investigation
7. **Investigation Steps** - Systematic investigation procedure
8. **Containment Actions** - Immediate steps to limit damage
9. **Remediation Steps** - Long-term fixes
10. **Validation** - How to confirm resolution
11. **Common False Positives** - Expected benign scenarios
12. **Escalation Criteria** - When and who to escalate to
13. **DLQ Handling** - Alert delivery failure procedures
14. **Related MITRE ATT&CK** - Framework mapping with tactics
15. **Related Runbooks** - Cross-references to related procedures
16. **SOC Note** - Operational philosophy

---

## MITRE ATT&CK Mapping

The `mitre-mapping.md` and `mitre-mapping.yaml` files map the platform's detection capabilities to the [MITRE ATT&CK® framework](https://attack.mitre.org/).

### Coverage Summary

**Techniques Covered:** 5
**Tactics Covered:** 5
**MITRE Version:** v13 Enterprise Matrix

### By Tactic
- **Initial Access:** 1 detection
- **Execution:** 1 detection
- **Persistence:** 2 detections
- **Privilege Escalation:** 2 detections
- **Credential Access:** 1 detection
- **Discovery:** 1 detection
- **Defense Evasion:** 1 detection

### By Severity
- **Critical:** 2 detections (Root Account, GuardDuty)
- **High:** 2 detections (Terraform State, DLQ)
- **Medium:** 1 detection (VPC Scanning)

### By Data Source
- **CloudTrail:** 3 detections
- **GuardDuty:** 1 detection
- **VPC Flow Logs:** 1 detection

**Files:**
- `mitre-mapping.md` - Human-readable table format
- `mitre-mapping.yaml` - Machine-readable format for automation

**Visualize Coverage:**
Upload `mitre-mapping.yaml` to [MITRE ATT&CK Navigator](https://mitre-attack.github.io/attack-navigator/)

---

## Incident Response Templates

The `templates/` directory contains standardized forms for incident documentation and management.

### Available Templates

1. **[Incident Report](./templates/incident-report.md)**
   - Comprehensive incident documentation
   - Timeline tracking
   - IOC collection
   - Impact assessment
   - Compliance reporting

2. **[Post-Incident Review (PIR)](./templates/post-incident-review.md)**
   - Blameless retrospective template
   - Root cause analysis (5 Whys)
   - Action item tracking
   - Metrics and KPIs
   - Lessons learned

3. **[Escalation Checklist](./templates/escalation-checklist.md)**
   - Severity-based escalation matrix
   - Contact directory
   - Communication templates
   - Decision tree
   - War room activation criteria

---

## Detection Coverage

### Identity & Access Management
- ✅ Root account usage (T1078)
- ✅ Terraform state access (T1552)
- ⚠️ AssumedRole abuse (T1098) - Planned

### Network Security
- ✅ VPC scanning/reconnaissance (T1046)
- ⚠️ Data exfiltration (T1048) - Planned

### Threat Detection
- ✅ GuardDuty malware/C2 (T1204)
- ⚠️ Cryptocurrency mining - Planned

### Operational Monitoring
- ✅ Alert delivery failures (DLQ)

**Coverage:** 5 active detections across 5 MITRE techniques

---

## Compliance Coverage

All detections and runbooks support compliance requirements:

| Framework | Controls Covered | Status |
|-----------|------------------|--------|
| **SOC 2 Type II** | CC6.1 (Access), CC7.2 (Monitoring) | ✅ Active |
| **PCI-DSS v4.0** | 7.1, 7.2, 8.2, 10.6, 11.4 | ✅ Active |
| **HIPAA** | 164.312(a), 164.312(b), 164.312(e) | ✅ Active |
| **GDPR** | Article 32 (Security of Processing) | ✅ Active |

**Audit Evidence:**
- Detection configurations: `/security-account/soc-alerting/monitors/`
- Alert delivery: SNS topic subscriptions with email confirmation
- Incident documentation: Templates in `templates/` directory
- Coverage mapping: `mitre-mapping.md` and `mitre-mapping.yaml`

---

## How to Use

### For SOC Analysts

1. **When an alert fires:**
   - Identify the alert type (GuardDuty, Root Account, etc.)
   - Open the corresponding runbook
   - Follow investigation steps systematically
   - Document findings in incident ticket
   - Escalate per severity guidelines

2. **Using OpenSearch queries:**
   - Copy query from runbook
   - Navigate to OpenSearch Dashboards
   - Select appropriate index pattern
   - Paste and run query
   - Analyze results

3. **Documenting incidents:**
   - Use `templates/incident-report.md` for all incidents
   - Complete post-incident review for High/Critical incidents
   - Track action items to completion

### For Security Engineers

1. **Reviewing detection coverage:**
   - Check `mitre-mapping.md` for current coverage
   - Identify gaps using MITRE Navigator
   - Propose new detections to fill gaps

2. **Updating runbooks:**
   - When detection logic changes, update corresponding runbook
   - Update OpenSearch query examples
   - Update estimated investigation times if workflow changes
   - Maintain consistency with runbook structure

3. **Maintaining YAML:**
   - Keep `mitre-mapping.yaml` synchronized with `mitre-mapping.md`
   - Update version and last_updated fields
   - Add new detections to both files

### For Security Leadership

1. **Compliance reporting:**
   - Use coverage tables for audit evidence
   - Reference specific controls in runbooks
   - Provide MITRE mapping for security posture assessment

2. **Metrics tracking:**
   - Investigation time estimates for capacity planning
   - Escalation criteria for SLA compliance
   - PIR templates for continuous improvement

---

## Contributing

### Creating New Runbooks

When adding a new detection:

1. **Copy existing runbook template** (use `guardduty.md` as reference)
2. **Include all required sections:**
   - Severity
   - Estimated Investigation Time
   - Compliance Scope
   - Trigger
   - Why This Matters
   - OpenSearch Query Example
   - Investigation Steps
   - Containment Actions
   - Remediation Steps
   - Validation
   - Common False Positives
   - Escalation Criteria
   - DLQ Handling
   - Related MITRE ATT&CK
   - Related Runbooks
   - SOC Note

3. **Update MITRE mappings:**
   - Add entry to `mitre-mapping.md` table
   - Add entry to `mitre-mapping.yaml` with full metadata

4. **Update this README:**
   - Add to runbooks table
   - Update coverage summary
   - Update compliance mappings if applicable

5. **Peer review:**
   - Have another analyst review for clarity
   - Test OpenSearch queries
   - Validate escalation procedures

### Runbook Maintenance

- **Quarterly:** Review all runbooks for accuracy
- **After incidents:** Update runbooks based on PIR findings
- **Tool changes:** Update queries when data sources change
- **Annually:** Full documentation audit

---

## Response SLAs

### Acknowledgment
| Severity | Target | Notification |
|----------|--------|-------------|
| Critical | 5 minutes | PagerDuty |
| High | 15 minutes | Slack |
| Medium | 30 minutes | Slack |
| Low | 1 hour | Email |

### Investigation Start
| Severity | Target |
|----------|--------|
| Critical | 10 minutes |
| High | 30 minutes |
| Medium | 1 hour |
| Low | 4 hours |

### Escalation Timeline
| Severity | Escalate After | Notify |
|----------|---------------|--------|
| Critical | 15 minutes | CISO, Incident Commander |
| High | 30 minutes | Security Lead |
| Medium | 1 hour | SOC Manager |
| Low | 4 hours | SOC Lead |

### Resolution Targets
| Severity | Target |
|----------|--------|
| Critical | 1 hour (containment), 4 hours (resolution) |
| High | 4 hours (containment), 24 hours (resolution) |
| Medium | 24 hours |
| Low | 1 week |

---

## References

### External Resources
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [NIST SP 800-61 Rev 2 - Incident Handling Guide](https://csrc.nist.gov/publications/detail/sp/800-61/rev-2/final)
- [AWS Security Best Practices](https://aws.amazon.com/security/best-practices/)
- [OCSF Schema Documentation](https://schema.ocsf.io/)
- [OpenSearch Security Analytics](https://opensearch.org/docs/latest/security-analytics/)

### Internal Documentation
- [Security Lake Architecture](../SECURITY-LAKE-ARCHITECTURE.md)
- [OpenSearch SNS Setup](../OPENSEARCH-SNS-SETUP.md)
- [SOC Setup Validation](../SOC-SETUP-VALIDATION.md)
- [OpenSearch Monitors](../security-account/soc-alerting/monitors/)

### Tools
- **SIEM:** AWS Security Lake + OpenSearch
- **Alerting:** SNS + Email
- **Ticketing:** [Configure your ticketing system]
- **ChatOps:** Slack #security-alerts
- **SOAR:** AWS Systems Manager Automation (planned)

---

## Quick Start

### For Your First Alert

1. **Receive alert** via Email/Slack
2. **Identify detection type** (check subject line or alert name)
3. **Open runbook** from table above
4. **Acknowledge alert** (Slack emoji or ticket comment)
5. **Start investigation** using runbook steps
6. **Run OpenSearch query** from runbook
7. **Document findings** in ticket
8. **Contain** if malicious
9. **Escalate** if criteria met
10. **Validate** and close

**Need Help?**
- Business Hours: Slack #soc-team
- After Hours: PagerDuty on-call
- Documentation Issues: File issue in repository

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-10 | SOC Team | Initial documentation |
| 2.0 | 2026-01-12 | SOC Team | Added investigation times, queries, compliance mappings, templates, escalation procedures |

---

**Next Review:** April 12, 2026
**Owner:** SOC Manager
**Status:** ✅ Production Ready

---

## Questions or Feedback?

Contact:
- **SOC Manager:** soc-manager@company.com
- **Security Lead:** security-lead@company.com
- **Slack:** #soc-team

# MITRE ATT&CK Detection Coverage

**Version:** 1.0
**MITRE ATT&CK Version:** v13 Enterprise Matrix
**Last Updated:** January 12, 2026
**Coverage:** 5 techniques across 5 tactics

## Detection to Technique Mapping

| Detection | Severity | Tactic | Technique ID | Technique Name | Sub-Technique | Data Source | Est. Time | Compliance |
|-----------|----------|--------|--------------|----------------|---------------|-------------|-----------|------------|
| Root account usage | Critical | Initial Access, Persistence | T1078 | Valid Accounts | T1078.004 | CloudTrail | 30-60 min | SOC2 CC6.1 |
| GuardDuty malware | Critical | Execution | T1204 | User Execution | T1204.003 | GuardDuty | 30-90 min | SOC2 CC7.2 |
| Terraform state access | High | Credential Access | T1552 | Unsecured Credentials | T1552.001 | CloudTrail | 45-75 min | SOC2 CC6.1 |
| AssumedRole abuse | High | Persistence, Privilege Escalation | T1098 | Account Manipulation | T1098.003 | CloudTrail | 45-90 min | PCI-DSS 7.2 |
| VPC scanning | Medium | Discovery | T1046 | Network Service Scanning | - | VPC Flow Logs | 20-40 min | PCI-DSS 11.4 |

## Coverage Summary

### By Tactic
- **Initial Access:** 1 detection
- **Execution:** 1 detection
- **Persistence:** 2 detections
- **Privilege Escalation:** 2 detections
- **Credential Access:** 1 detection
- **Discovery:** 1 detection
- **Defense Evasion:** 1 detection

### By Severity
- **Critical:** 2 detections
- **High:** 2 detections
- **Medium:** 1 detection

### By Data Source
- **CloudTrail:** 3 detections
- **GuardDuty:** 1 detection
- **VPC Flow Logs:** 1 detection

## Compliance Coverage

| Framework | Controls Covered |
|-----------|------------------|
| **SOC 2 Type II** | CC6.1 (Logical Access), CC7.2 (System Monitoring) |
| **PCI-DSS v4.0** | 7.1, 7.2 (Access Control), 10.6 (Monitoring), 11.4 (Network Security) |
| **HIPAA** | 164.312(a)(1), 164.312(a)(2), 164.312(b), 164.312(e)(1) |
| **GDPR** | Article 32 (Security of Processing) |

## MITRE Navigator

To visualize this coverage in MITRE ATT&CK Navigator:
1. Visit https://mitre-attack.github.io/attack-navigator/
2. Import the `mitre-mapping.yaml` file
3. Review coverage heatmap

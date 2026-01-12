# 🚨 Security Incident Report

**Incident ID:** INC-[YYYY-MM-DD]-[###]
**Date Opened:** [YYYY-MM-DD HH:MM UTC]
**Date Closed:** [YYYY-MM-DD HH:MM UTC]
**Reported By:** [Name/Team]
**Severity:** [ ] Critical [ ] High [ ] Medium [ ] Low

---

## Executive Summary

*Brief 2-3 sentence summary of what happened, impact, and resolution status.*

---

## Incident Details

### Detection Source
- [ ] OpenSearch Monitor
- [ ] GuardDuty
- [ ] CloudTrail
- [ ] VPC Flow Logs
- [ ] Manual Discovery
- [ ] Third-Party Report

**Alert/Finding ID:** ___________
**First Detected:** [YYYY-MM-DD HH:MM UTC]

### Affected Resources
- **AWS Account(s):** ___________
- **Region(s):** ___________
- **Resource Type(s):** ___________
- **Resource ID(s):** ___________

### Classification
**MITRE ATT&CK Tactic:** ___________
**MITRE ATT&CK Technique:** ___________
**Detection Category:**
- [ ] Credential Compromise
- [ ] Malware/C2
- [ ] Data Exfiltration
- [ ] Unauthorized Access
- [ ] Reconnaissance
- [ ] Policy Violation
- [ ] Operational Issue

---

## Timeline

| Time (UTC) | Event | Actor | Action Taken |
|------------|-------|-------|--------------|
| HH:MM | Initial detection | System | Alert triggered |
| HH:MM | Investigation started | Analyst | Reviewed finding |
| HH:MM | Containment action | Analyst | [Describe action] |
| HH:MM | Remediation completed | Engineer | [Describe action] |
| HH:MM | Validation confirmed | Analyst | [Describe validation] |
| HH:MM | Incident closed | Manager | Documentation complete |

---

## Investigation Summary

### Indicators of Compromise (IOCs)
- **IP Addresses:** ___________
- **User Agents:** ___________
- **File Hashes:** ___________
- **Domain Names:** ___________
- **IAM Principals:** ___________

### Root Cause Analysis
*Describe the underlying cause that allowed this incident to occur.*

### Scope Assessment
**Data Accessed:** [ ] Yes [ ] No [ ] Unknown
**Data Exfiltrated:** [ ] Yes [ ] No [ ] Unknown
**Credentials Compromised:** [ ] Yes [ ] No [ ] Unknown
**Lateral Movement:** [ ] Yes [ ] No [ ] Unknown

---

## Response Actions

### Containment
*List all actions taken to contain the incident and prevent further damage.*

1. ___________
2. ___________
3. ___________

### Eradication
*List all actions taken to remove the threat from the environment.*

1. ___________
2. ___________
3. ___________

### Recovery
*List all actions taken to restore normal operations.*

1. ___________
2. ___________
3. ___________

---

## Impact Assessment

### Business Impact
- [ ] No business impact
- [ ] Degraded service performance
- [ ] Service disruption
- [ ] Data breach
- [ ] Financial loss
- [ ] Reputational damage

**Estimated Downtime:** ___________
**Estimated Financial Impact:** ___________

### Compliance Impact
- [ ] SOC 2 reportable event
- [ ] PCI-DSS breach notification required
- [ ] HIPAA breach notification required
- [ ] GDPR breach notification required (72 hours)
- [ ] No compliance impact

---

## Validation

### Remediation Verification
- [ ] Threat removed from environment
- [ ] All credentials rotated
- [ ] Security controls enhanced
- [ ] No further suspicious activity detected
- [ ] Monitoring in place to detect recurrence

### Evidence Preservation
- [ ] CloudTrail logs archived
- [ ] VPC Flow Logs archived
- [ ] GuardDuty findings exported
- [ ] Forensic images captured
- [ ] Evidence chain of custody documented

**Evidence Location:** ___________

---

## Lessons Learned

### What Went Well
1. ___________
2. ___________
3. ___________

### What Could Be Improved
1. ___________
2. ___________
3. ___________

### Action Items

| Action Item | Owner | Due Date | Status |
|-------------|-------|----------|--------|
| _________ | _____ | ________ | Open/Closed |
| _________ | _____ | ________ | Open/Closed |
| _________ | _____ | ________ | Open/Closed |

---

## References

**Related Runbooks:** ___________
**Related Incidents:** ___________
**Ticket/Case Number:** ___________

**OpenSearch Dashboard:** ___________
**CloudTrail Query:** ___________

---

## Approvals

**Prepared By:** ___________ (Analyst)
**Reviewed By:** ___________ (SOC Manager)
**Approved By:** ___________ (CISO)

**Date:** ___________

---

## Distribution

- [ ] SOC Team
- [ ] Security Leadership
- [ ] Legal/Compliance
- [ ] Executive Management
- [ ] Affected Business Units
- [ ] Board of Directors (Critical incidents only)

**Confidentiality:** [ ] Internal Use Only [ ] Confidential [ ] Highly Confidential

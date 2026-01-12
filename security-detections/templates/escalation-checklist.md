# 📞 Incident Escalation Checklist

Use this checklist to determine when and how to escalate security incidents.

---

## Severity-Based Escalation Matrix

| Severity | Acknowledgment | Investigation Start | Escalation Trigger | Notify |
|----------|---------------|-------------------|-------------------|--------|
| **Critical** | 5 minutes | 10 minutes | 15 minutes | CISO, Incident Commander, On-call Manager |
| **High** | 15 minutes | 30 minutes | 30 minutes | Security Lead, SOC Manager |
| **Medium** | 30 minutes | 1 hour | 1 hour | SOC Manager |
| **Low** | 1 hour | 4 hours | 4 hours | SOC Lead |

---

## Automatic Escalation Triggers

### ✅ Escalate IMMEDIATELY to CISO if:

- [ ] Root account access detected (unauthorized)
- [ ] Data exfiltration confirmed (>1GB or PII/PHI)
- [ ] Active ransomware or cryptominer detected
- [ ] AWS account takeover suspected
- [ ] Production environment compromised
- [ ] Credentials publicly exposed (GitHub, Pastebin, etc.)
- [ ] Regulatory breach notification threshold met (GDPR, HIPAA, PCI-DSS)
- [ ] Multiple AWS accounts affected (lateral movement)
- [ ] C2 (Command & Control) communication confirmed
- [ ] Critical vulnerability being actively exploited (0-day)

**Notification Channels:**
- 📧 Email: ciso@company.com
- 📱 PagerDuty: CISO On-call
- 💬 Slack: #security-critical
- ☎️ Phone: [CISO Mobile Number]

---

### ✅ Escalate to Incident Commander if:

- [ ] Multiple teams required for response (SOC + DevOps + Legal)
- [ ] Customer data potentially accessed
- [ ] Incident duration >2 hours without containment
- [ ] War room needed for coordination
- [ ] External communication required (customers, regulators)
- [ ] Business operations significantly impacted
- [ ] Cannot determine scope within 1 hour

**Notification Channels:**
- 📧 Email: incident-commander@company.com
- 📱 PagerDuty: Incident Commander Rotation
- 💬 Slack: #incident-response
- 📞 Conference Bridge: [Meeting Link]

---

### ✅ Escalate to Security Lead if:

- [ ] High-severity GuardDuty finding (malware, C2, exfiltration)
- [ ] Infrastructure credentials (Terraform state) accessed
- [ ] VPC scanning from production workloads (lateral movement)
- [ ] IAM privilege escalation detected
- [ ] Cannot contain incident within 30 minutes
- [ ] Runbook incomplete or unclear
- [ ] Forensic analysis required

**Notification Channels:**
- 📧 Email: security-lead@company.com
- 💬 Slack: #security-alerts

---

### ✅ Escalate to Platform Team if:

- [ ] SOC alerting DLQ messages exceed 50
- [ ] OpenSearch cluster degraded or unavailable
- [ ] Security Lake ingestion failing
- [ ] IAM role permissions blocking investigation
- [ ] Cannot access logs/telemetry needed for investigation
- [ ] Infrastructure changes required for containment

**Notification Channels:**
- 📧 Email: platform-engineering@company.com
- 💬 Slack: #platform-engineering
- 📱 PagerDuty: Platform On-call

---

## Escalation Decision Tree

```
┌─────────────────────────────────┐
│ Security Alert Received         │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│ Is it Critical or High severity?│
└─────────┬───────────────────────┘
          │
    ┌─────┴─────┐
    │           │
   YES         NO
    │           │
    ▼           ▼
┌─────────┐  ┌──────────────────────┐
│ Critical│  │ Medium/Low           │
│ Path    │  │ Follow standard SLA  │
└────┬────┘  └──────────────────────┘
     │
     ▼
┌──────────────────────────────────┐
│ Can you contain within 15 min?   │
└────┬────────────────────┬────────┘
     │                    │
    YES                  NO
     │                    │
     ▼                    ▼
┌─────────────┐    ┌─────────────────┐
│ Continue    │    │ Escalate to     │
│ investigation│    │ Security Lead   │
└─────────────┘    └────────┬────────┘
                            │
                            ▼
                   ┌─────────────────────┐
                   │ Still unresolved?   │
                   │ (30+ minutes)       │
                   └────┬────────────────┘
                        │
                       YES
                        │
                        ▼
                   ┌────────────────────┐
                   │ Escalate to        │
                   │ Incident Commander │
                   └────────┬───────────┘
                            │
                            ▼
                   ┌────────────────────┐
                   │ Data breach or     │
                   │ regulatory impact? │
                   └────┬───────────────┘
                        │
                       YES
                        │
                        ▼
                   ┌────────────────────┐
                   │ Escalate to CISO   │
                   │ (IMMEDIATE)        │
                   └────────────────────┘
```

---

## Escalation Communication Template

### Subject Line Format:
```
[SECURITY] [SEVERITY] Brief Incident Description - INC-YYYY-MM-DD-###
```

**Examples:**
- `[SECURITY] [CRITICAL] Root Account Access Detected - INC-2026-01-12-001`
- `[SECURITY] [HIGH] GuardDuty Malware Finding - INC-2026-01-12-002`

### Email/Slack Message Template:

```
🚨 SECURITY INCIDENT ESCALATION

Incident ID: INC-[YYYY-MM-DD]-[###]
Severity: [Critical/High/Medium/Low]
Detected: [YYYY-MM-DD HH:MM UTC]
Assigned Analyst: [Your Name]

SUMMARY:
[2-3 sentence description of what happened]

IMPACT:
- Affected Resources: [AWS Account, Region, Resources]
- Business Impact: [Service disruption, data access, etc.]
- Scope: [Contained/Spreading/Unknown]

ACTIONS TAKEN:
1. [Action 1]
2. [Action 2]

REQUESTING:
[Specific help needed: permissions, decisions, resources]

NEXT STEPS:
[What will happen next]

INCIDENT CHANNEL:
Slack: #incident-response-[inc-number]
Conference Bridge: [Link]

OpenSearch Dashboard: [Link]
CloudTrail Query: [Link]
```

---

## Escalation Checklist (Before Escalating)

Before escalating, ensure you have:

- [ ] **Incident ID created:** INC-[YYYY-MM-DD]-[###]
- [ ] **Severity assessed:** Critical/High/Medium/Low
- [ ] **Initial investigation completed:** Reviewed alert, checked runbook
- [ ] **Scope identified:** Affected accounts, regions, resources
- [ ] **Containment attempted:** Tried immediate actions from runbook
- [ ] **Evidence preserved:** CloudTrail, VPC Flows, GuardDuty findings
- [ ] **Timeline documented:** When detected, actions taken
- [ ] **Business impact assessed:** Service disruption, data access
- [ ] **Clear ask prepared:** What specific help do you need?
- [ ] **Dashboard/queries ready:** Links to OpenSearch, CloudTrail

**DO NOT escalate if:**
- You haven't followed the runbook
- You haven't attempted containment
- You don't have basic incident details
- It's a false positive you can resolve

**Exception:** Critical incidents bypass this checklist - escalate immediately!

---

## After-Hours Escalation

### Business Hours (9am-5pm EST)
- Use Slack as primary channel
- Email for documentation
- Phone for urgent matters

### After-Hours (5pm-9am EST, Weekends, Holidays)
- **PagerDuty** is primary escalation method
- Always include phone call for Critical incidents
- Document in Slack after initial notification

---

## Escalation Paths by Detection Type

| Detection Type | First Contact | Escalate After | Final Escalation |
|---------------|--------------|---------------|-----------------|
| Root Account Usage | SOC Analyst | 15 min → Security Lead | 30 min → CISO |
| GuardDuty Critical | SOC Analyst | 15 min → Security Lead | 30 min → Incident Commander |
| Terraform State Access | SOC Analyst | 30 min → Security Lead | 1 hour → Infrastructure Lead |
| VPC Scanning | SOC Analyst | 1 hour → Security Lead | 2 hours → SOC Manager |
| DLQ Alerting | SOC Analyst | 30 min → Platform Team | 1 hour → SOC Manager |

---

## War Room Activation Criteria

Activate incident war room (conference bridge + Slack channel) if:

- [ ] Multiple teams required (SOC + DevOps + Legal + PR)
- [ ] Incident duration >1 hour
- [ ] Customer-facing impact
- [ ] Regulatory reporting likely
- [ ] Executive visibility required
- [ ] Complex coordination needed

**War Room Setup:**
1. Create Slack channel: `#incident-response-inc-[number]`
2. Start conference bridge: [Meeting Link]
3. Invite: SOC Lead, Security Lead, Incident Commander, relevant engineers
4. Post status updates every 15 minutes
5. Assign scribe for documentation

---

## External Escalation (Legal/PR/Customers)

### Legal/Compliance Team
**Notify if:**
- Customer PII/PHI accessed or exfiltrated
- Regulatory breach notification thresholds met
- Potential litigation risk

**Contact:** legal@company.com

### Public Relations Team
**Notify if:**
- Public disclosure required
- Media inquiry received
- Customer-facing statement needed

**Contact:** pr@company.com

### Customer Communication Team
**Notify if:**
- Customer data accessed
- Service outage >2 hours
- Security incident affects customer operations

**Contact:** customer-success@company.com

---

## Escalation Do's and Don'ts

### ✅ DO:
- Escalate early if unsure (better safe than sorry)
- Provide clear, concise incident summary
- Include specific asks (what help do you need?)
- Document escalation in incident timeline
- Follow up with written summary after phone calls

### ❌ DON'T:
- Delay escalation hoping problem resolves itself
- Escalate without basic investigation
- Escalate via wrong channel (use PagerDuty after-hours)
- Leave escalation open-ended ("just letting you know")
- Forget to document escalation in incident ticket

---

## Contact Directory

| Role | Business Hours | After-Hours | Email |
|------|---------------|-------------|-------|
| **CISO** | Slack DM | PagerDuty | ciso@company.com |
| **Incident Commander** | Slack #incident-response | PagerDuty | incident-commander@company.com |
| **Security Lead** | Slack #security-alerts | PagerDuty | security-lead@company.com |
| **SOC Manager** | Slack #soc-team | Phone | soc-manager@company.com |
| **Platform Lead** | Slack #platform-engineering | PagerDuty | platform-lead@company.com |
| **Legal** | Email | On-call Counsel | legal@company.com |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-12 | Initial escalation checklist |

---

**Questions?** Contact SOC Manager or review [Incident Response Procedures](../README.md)

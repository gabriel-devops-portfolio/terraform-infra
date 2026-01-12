# 🚨 SOC Quick Reference Card

**Version:** 1.0 | **Last Updated:** 2026-01-12

---

## 📞 Emergency Contacts

| Role | Business Hours | After-Hours | Channel |
|------|---------------|-------------|---------|
| **CISO** | Slack DM | PagerDuty | ciso@company.com |
| **Security Lead** | #security-alerts | PagerDuty | security-lead@company.com |
| **SOC Manager** | #soc-team | Phone | soc-manager@company.com |
| **Platform Team** | #platform-engineering | PagerDuty | platform-lead@company.com |

---

## ⏱️ Response SLAs

| Severity | Acknowledge | Investigate | Escalate | Resolve |
|----------|------------|------------|----------|---------|
| **Critical** | 5 min | 10 min | 15 min | 1-4 hours |
| **High** | 15 min | 30 min | 30 min | 4-24 hours |
| **Medium** | 30 min | 1 hour | 1 hour | 24 hours |
| **Low** | 1 hour | 4 hours | 4 hours | 1 week |

---

## 🎯 Detection Quick Reference

| Alert Type | Severity | Runbook | Index Pattern | Time |
|------------|----------|---------|---------------|------|
| GuardDuty High/Critical | Critical | [guardduty.md](./runbooks/guardduty.md) | `securitylake-guardduty-*` | 30-90 min |
| Root Account Usage | Critical | [root-account.md](./runbooks/root-account.md) | `securitylake-cloudtrail-*` | 30-60 min |
| Terraform State Access | High | [terraform-state.md](./runbooks/terraform-state.md) | `securitylake-cloudtrail-*` | 45-75 min |
| VPC Scanning | Medium | [vpc-scanning.md](./runbooks/vpc-scanning.md) | `securitylake-vpcflow-*` | 20-40 min |
| DLQ Alerting | High (Ops) | [dlq-alerting.md](./runbooks/dlq-alerting.md) | CloudWatch/SQS | 30-60 min |

---

## 🔍 Quick Investigation Steps

### 1. Acknowledge (Within SLA)
```
- [ ] Acknowledge in Slack (emoji react)
- [ ] Create incident ticket: INC-YYYY-MM-DD-###
- [ ] Note time of acknowledgment
```

### 2. Identify
```
- [ ] What type of alert? (GuardDuty, Root, etc.)
- [ ] Affected resource(s)?
- [ ] AWS Account & Region?
- [ ] Time of occurrence?
```

### 3. Investigate (Follow Runbook)
```
- [ ] Open corresponding runbook
- [ ] Run OpenSearch query from runbook
- [ ] Check CloudTrail for related events
- [ ] Review VPC Flow Logs if network-related
- [ ] Document findings in ticket
```

### 4. Assess
```
- [ ] Malicious or benign?
- [ ] False positive?
- [ ] Impact scope?
- [ ] Need to escalate?
```

### 5. Contain (If Malicious)
```
- [ ] Follow containment steps from runbook
- [ ] Isolate affected resources
- [ ] Rotate credentials if needed
- [ ] Block IPs/domains if applicable
```

### 6. Escalate (If Criteria Met)
```
- [ ] Check escalation criteria in runbook
- [ ] Use escalation template
- [ ] Notify per severity matrix
- [ ] Document escalation in ticket
```

### 7. Remediate
```
- [ ] Follow remediation steps from runbook
- [ ] Apply long-term fixes
- [ ] Update security controls
```

### 8. Validate & Close
```
- [ ] Confirm threat removed
- [ ] Verify normal operations restored
- [ ] No further suspicious activity
- [ ] Document outcome
- [ ] Close ticket with summary
```

---

## 💻 Quick OpenSearch Queries

### Root Account Activity
```json
{
  "query": {
    "bool": {
      "must": [
        {"term": {"class_name": "API Activity"}},
        {"term": {"actor.user.type": "Root"}}
      ]
    }
  },
  "sort": [{"time": {"order": "desc"}}]
}
```
**Index:** `securitylake-cloudtrail-*`

### GuardDuty High/Critical
```json
{
  "query": {
    "bool": {
      "must": [
        {"term": {"metadata.product.name": "GuardDuty"}},
        {"range": {"severity_id": {"gte": 4}}}
      ]
    }
  }
}
```
**Index:** `securitylake-guardduty-*`

### VPC Rejected Traffic (Last 5 Min)
```json
{
  "query": {
    "bool": {
      "must": [
        {"term": {"class_name": "Network Activity"}},
        {"term": {"disposition": "Blocked"}}
      ],
      "filter": {
        "range": {"time": {"gte": "now-5m"}}
      }
    }
  }
}
```
**Index:** `securitylake-vpcflow-*`

### Terraform State Access
```json
{
  "query": {
    "bool": {
      "must": [
        {"match": {"api.operation": "GetObject"}},
        {"wildcard": {"resources.uid": "*terraform.tfstate*"}}
      ],
      "must_not": [
        {"terms": {"actor.user.name": ["TerraformBackendRole", "GitHubActionsRole"]}}
      ]
    }
  }
}
```
**Index:** `securitylake-cloudtrail-*`

---

## 📋 Escalation Checklist

Before escalating, ensure you have:

```
- [ ] Incident ID: INC-YYYY-MM-DD-###
- [ ] Severity assessed
- [ ] Basic investigation done
- [ ] Scope identified
- [ ] Containment attempted
- [ ] Evidence preserved
- [ ] Clear ask prepared
- [ ] Dashboard links ready
```

---

## 🚨 Auto-Escalate to CISO If:

```
⚠️ Root account access (unauthorized)
⚠️ Data exfiltration confirmed (>1GB or PII)
⚠️ Active ransomware detected
⚠️ AWS account takeover suspected
⚠️ Production compromised
⚠️ Multiple accounts affected
⚠️ Regulatory breach threshold met
```

**Notify:** PagerDuty + Phone + Email (within 15 minutes)

---

## 📧 Escalation Message Template

```
🚨 SECURITY INCIDENT ESCALATION

Incident ID: INC-[YYYY-MM-DD]-[###]
Severity: [Critical/High/Medium/Low]
Detected: [YYYY-MM-DD HH:MM UTC]
Analyst: [Your Name]

SUMMARY:
[2-3 sentence description]

IMPACT:
- Resources: [Account, Region, Resources]
- Business: [Service disruption, data access]
- Scope: [Contained/Spreading/Unknown]

ACTIONS TAKEN:
1. [Action 1]
2. [Action 2]

REQUESTING:
[Specific help needed]

LINKS:
- Ticket: [Link]
- OpenSearch: [Link]
- CloudTrail: [Link]
```

---

## 🔗 Key Links

| Resource | Link |
|----------|------|
| **OpenSearch Dashboards** | https://opensearch.security-account.company.com |
| **CloudTrail Console** | AWS Console → CloudTrail → Event History |
| **GuardDuty Console** | AWS Console → GuardDuty → Findings |
| **VPC Flow Logs** | CloudWatch Logs → /aws/vpc/flowlogs |
| **Security Lake** | AWS Console → Security Lake |
| **Runbooks** | `/security-detections/runbooks/` |
| **Templates** | `/security-detections/templates/` |
| **Incident Slack** | #incident-response |
| **SOC Slack** | #soc-team |

---

## 🧠 Quick Tips

### For Analysts
- ✅ **Always follow the runbook** - Don't skip steps
- ✅ **Document everything** - Future you will thank you
- ✅ **Escalate early** - Better safe than sorry
- ✅ **Preserve evidence** - Save logs before cleanup
- ✅ **Test queries first** - Verify before running

### For False Positives
- ✅ Check "Common False Positives" in runbook
- ✅ Document FP in ticket
- ✅ Consider suppression rule
- ✅ Update runbook if new FP type

### For After-Hours
- ✅ Use PagerDuty for Critical/High
- ✅ Phone call for CISO escalation
- ✅ Document in Slack after notification
- ✅ Don't wait until morning for Critical

---

## 📚 Templates Location

```
/security-detections/templates/
├── incident-report.md          # Full incident documentation
├── post-incident-review.md     # PIR after High/Critical
└── escalation-checklist.md     # When and how to escalate
```

---

## 🎓 Common Mistakes to Avoid

```
❌ Skipping runbook steps
❌ Not documenting findings
❌ Delaying escalation
❌ Not preserving evidence
❌ Assuming it's a false positive
❌ Escalating without basic investigation
❌ Forgetting to close ticket
❌ Not following up after escalation
```

---

## 🆘 When in Doubt

**Ask yourself:**
1. Did I follow the runbook?
2. Did I document my findings?
3. Do I have enough info to make a decision?
4. Does this meet escalation criteria?
5. Would I want to explain this decision to my manager?

**If "NO" to any:** Ask for help! #soc-team or @soc-manager

---

## 📞 After-Hours On-Call

**PagerDuty Rotations:**
- Security Lead: security-oncall
- Platform Team: platform-oncall
- Incident Commander: ic-oncall

**When to Page:**
- Critical severity alerts
- Cannot contain within 30 minutes
- Production impact
- Data breach suspected

**Conference Bridge:** [Insert meeting link]

---

## ✅ Daily Checklist

### Start of Shift
```
- [ ] Review overnight alerts
- [ ] Check DLQ messages (should be 0)
- [ ] Review open tickets
- [ ] Check Slack #security-alerts
- [ ] Verify OpenSearch accessible
```

### During Shift
```
- [ ] Monitor Slack #security-alerts
- [ ] Respond to new alerts per SLA
- [ ] Update ticket status
- [ ] Escalate if criteria met
- [ ] Document all findings
```

### End of Shift
```
- [ ] Update ticket notes
- [ ] Handoff open incidents
- [ ] Note pending escalations
- [ ] Post shift summary in #soc-team
```

---

## 🎯 Performance Metrics

Track your performance:

| Metric | Target | Your Goal |
|--------|--------|-----------|
| Acknowledgment (Critical) | <5 min | Beat target |
| Investigation (Critical) | <10 min | Beat target |
| False Positive Rate | <10% | Minimize |
| Escalation Accuracy | >90% | Maximize |
| Documentation Quality | 100% | Always |

---

## 📱 Slack Quick Commands

```
/incident create         # Create incident channel
/page security-oncall    # Page security lead
/statuspage update       # Update status page
```

---

## 🔄 Shift Handoff Template

```
Shift Handoff [YYYY-MM-DD HH:MM]

OPEN INCIDENTS:
- INC-XXX: [Summary] - Status: [Investigating/Contained]
- INC-YYY: [Summary] - Status: [Awaiting response]

ESCALATIONS:
- Escalated INC-XXX to Security Lead at HH:MM
- Awaiting response from Platform Team on INC-YYY

NOTES:
- DLQ message count: 0
- OpenSearch performance: Normal
- No planned maintenance

NEXT SHIFT:
- Follow up on INC-XXX by [time]
- Check CloudTrail logs for [resource]
```

---

## 📖 Study Materials

**Master these runbooks:**
1. Root Account (most critical, zero-tolerance)
2. GuardDuty (most complex, variable investigation)
3. Terraform State (infrastructure security)
4. VPC Scanning (common, usually benign)
5. DLQ Alerting (operational, system health)

**Pro tip:** Read runbooks during slow periods!

---

**Print this card and keep it handy! 📌**

**Questions?** Slack: #soc-team | Email: soc-manager@company.com

---

*This quick reference card is a companion to the full security detection documentation.*
*For complete details, see `/security-detections/README.md`*

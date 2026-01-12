# 📋 Post-Incident Review (PIR)

**Incident ID:** INC-[YYYY-MM-DD]-[###]
**Review Date:** [YYYY-MM-DD]
**Facilitator:** ___________
**Attendees:** ___________

---

## Meeting Objective

To conduct a blameless review of incident INC-[###], identify systemic improvements, and prevent recurrence through actionable recommendations.

---

## Incident Recap

**Incident Type:** ___________
**Severity:** ___________
**Duration:** ___________ hours
**Mean Time to Detect (MTTD):** ___________ minutes
**Mean Time to Respond (MTTR):** ___________ minutes
**Mean Time to Recover (MTTR):** ___________ hours

**Summary:**
*Brief 2-3 sentence summary of what happened.*

---

## Timeline Analysis

### Detection Phase
**Time to Detect:** ___________ minutes
**Detection Method:** ___________

**Questions:**
- Could we have detected this incident sooner?
- Were our monitoring systems effective?
- Were any signals missed before the incident was detected?

**Findings:**
1. ___________
2. ___________

---

### Response Phase
**Time to Initial Response:** ___________ minutes
**First Responder:** ___________

**Questions:**
- Was the right person notified first?
- Did we have the necessary tools and access?
- Were runbooks helpful and accurate?
- Did we escalate at the appropriate time?

**Findings:**
1. ___________
2. ___________

---

### Containment Phase
**Time to Contain:** ___________ minutes
**Containment Actions:** ___________

**Questions:**
- Did we contain the incident effectively?
- Were there delays in containment? Why?
- Did we have the necessary permissions?
- Could automation have helped?

**Findings:**
1. ___________
2. ___________

---

### Recovery Phase
**Time to Full Recovery:** ___________ hours
**Recovery Actions:** ___________

**Questions:**
- How long did it take to restore normal operations?
- Were there any setbacks during recovery?
- Did we validate full remediation?

**Findings:**
1. ___________
2. ___________

---

## Root Cause Analysis (5 Whys)

**Problem Statement:** ___________

1. **Why did this incident occur?**
   - ___________

2. **Why did that happen?**
   - ___________

3. **Why did that happen?**
   - ___________

4. **Why did that happen?**
   - ___________

5. **Why did that happen? (Root Cause)**
   - ___________

---

## What Went Well 🎉

List things that worked well during the incident response:

1. ✅ ___________
2. ✅ ___________
3. ✅ ___________

**Examples:**
- Alert fired within 2 minutes of suspicious activity
- Runbook was clear and easy to follow
- Team collaborated effectively across time zones
- Evidence was properly preserved

---

## What Didn't Go Well ⚠️

List things that could have been better (blameless):

1. ⚠️ ___________
2. ⚠️ ___________
3. ⚠️ ___________

**Examples:**
- Initial alert lacked sufficient context
- Had to wait 20 minutes for on-call engineer to respond
- Runbook was outdated
- Required manual steps that could be automated

---

## Where We Got Lucky 🍀

List things that could have made the incident worse:

1. 🍀 ___________
2. 🍀 ___________
3. 🍀 ___________

**Examples:**
- Incident occurred during business hours (not 3am)
- Only affected dev environment, not production
- Credentials had just been rotated the week before
- Security monitoring was recently upgraded

---

## Action Items

### High Priority (Complete within 1 week)

| Action | Owner | Due Date | Status | Validation |
|--------|-------|----------|--------|-----------|
| _____ | _____ | ________ | Open | _________ |
| _____ | _____ | ________ | Open | _________ |
| _____ | _____ | ________ | Open | _________ |

### Medium Priority (Complete within 1 month)

| Action | Owner | Due Date | Status | Validation |
|--------|-------|----------|--------|-----------|
| _____ | _____ | ________ | Open | _________ |
| _____ | _____ | ________ | Open | _________ |

### Low Priority (Complete within 3 months)

| Action | Owner | Due Date | Status | Validation |
|--------|-------|----------|--------|-----------|
| _____ | _____ | ________ | Open | _________ |
| _____ | _____ | ________ | Open | _________ |

---

## Recommendations

### People & Process
1. ___________
2. ___________
3. ___________

### Technology & Tools
1. ___________
2. ___________
3. ___________

### Documentation
1. ___________
2. ___________
3. ___________

### Training
1. ___________
2. ___________
3. ___________

---

## Metrics & KPIs

| Metric | Target | Actual | Pass/Fail |
|--------|--------|--------|-----------|
| Mean Time to Detect (MTTD) | <15 min | _____ | _____ |
| Mean Time to Respond (MTTR) | <30 min | _____ | _____ |
| Mean Time to Contain | <60 min | _____ | _____ |
| Mean Time to Recover | <4 hours | _____ | _____ |
| Escalation Time | <15 min | _____ | _____ |

---

## Knowledge Sharing

### Runbook Updates Required
- [ ] Update runbook: ___________
- [ ] Create new runbook: ___________
- [ ] Add query examples to: ___________

### Internal Communications
- [ ] Share findings with SOC team
- [ ] Update security training materials
- [ ] Brief executive leadership
- [ ] Document in knowledge base

### External Communications
- [ ] Customer notification (if applicable)
- [ ] Regulatory notification (if applicable)
- [ ] Public disclosure (if applicable)

---

## Follow-Up

**Next Review Meeting:** [YYYY-MM-DD]
**Responsible for Action Item Tracking:** ___________

---

## Attendee Feedback

**What did you learn from this incident?**
- ___________
- ___________

**What would you do differently next time?**
- ___________
- ___________

**Additional Comments:**
___________

---

## References

**Incident Report:** INC-[YYYY-MM-DD]-[###]
**Related Tickets:** ___________
**Related PIRs:** ___________

---

**Prepared By:** ___________
**Date:** ___________

---

## Distribution

- [ ] SOC Team
- [ ] Security Engineering
- [ ] Infrastructure Team
- [ ] Security Leadership
- [ ] Compliance Team

# 🚀 OpenSearch SNS Alerting - Implementation Complete

## ⚠️ **IMPORTANT: Deployment Method Updated**

**This document describes the legacy per-module deployment method.**

**✅ For current deployment, use the unified method:**
```bash
cd security-account/backend-bootstrap
terraform apply
```

**This single command deploys OpenSearch, SNS topics, and all other security infrastructure.**

**See:** [UNIFIED-DEPLOYMENT-GUIDE.md](./UNIFIED-DEPLOYMENT-GUIDE.md) for complete instructions.

---

## ✅ **IAM Role Created Successfully**

The IAM role for OpenSearch to publish alerts to SNS has been implemented!

---

### **1. IAM Role for OpenSearch → SNS** ✅

**File:** `opensearch/main.tf`

```terraform
resource "aws_iam_role" "opensearch_sns" {
  name        = "OpenSearchSNSRole"
  description = "IAM role for OpenSearch to publish alerts to SNS topics"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "es.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}
```

### **2. IAM Policy for SNS Publish** ✅

```terraform
resource "aws_iam_role_policy" "opensearch_sns" {
  name = "OpenSearchSNSPolicy"
  role = aws_iam_role.opensearch_sns.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowSNSPublish"
      Effect = "Allow"
      Action = ["sns:Publish"]
      Resource = [
        "arn:aws:sns:us-east-1:404068503087:soc-alerts-critical",
        "arn:aws:sns:us-east-1:404068503087:soc-alerts-high",
        "arn:aws:sns:us-east-1:404068503087:soc-alerts-medium"
      ]
    }]
  })
}
```

**Permissions:** OpenSearch can now publish to all 3 severity SNS topics

---

## 📤 **Outputs Added**

### **OpenSearch Outputs** (`opensearch/outputs.tf`)

```terraform
output "opensearch_sns_role_arn" {
  description = "ARN of the IAM role for OpenSearch to publish to SNS"
  value       = aws_iam_role.opensearch_sns.arn
}

output "opensearch_sns_role_name" {
  description = "Name of the IAM role for OpenSearch to publish to SNS"
  value       = aws_iam_role.opensearch_sns.name
}
```

### **SNS Outputs** (`soc-alerting/sns.tf`)

```terraform
output "critical_topic_arn" {
  value = aws_sns_topic.critical.arn
}

output "high_topic_arn" {
  value = aws_sns_topic.high.arn
}

output "medium_topic_arn" {
  value = aws_sns_topic.medium.arn
}

output "sns_topics" {
  value = {
    critical = aws_sns_topic.critical.arn
    high     = aws_sns_topic.high.arn
    medium   = aws_sns_topic.medium.arn
  }
}
```

---

## 🚀 **Deployment Steps**

### ✅ **New Unified Deployment Method (Use This!)**

**Step 1: Deploy All Security Infrastructure**

```bash
cd security-account/backend-bootstrap

terraform init
terraform apply
```

**This single command deploys:**
- ✅ Cross-Account Roles (S3, IAM, KMS)
- ✅ Security Lake (OCSF data lake, Glue, Athena)
- ✅ Athena Queries (7 queries + 4 views)
- ✅ OpenSearch (domain + SNS IAM role)
- ✅ SNS Topics (critical, high, medium)
- ✅ DLQ Monitoring
- ✅ Config Drift Detection

**Expected Output:**
```
Apply complete! Resources: 85+ added, 0 changed, 0 destroyed.

Outputs:

opensearch_endpoint = "https://search-security-logs-xxxxx.us-east-1.es.amazonaws.com"
opensearch_dashboard_endpoint = "https://search-security-logs-xxxxx.us-east-1.es.amazonaws.com/_dashboards"
opensearch_sns_role_arn = "arn:aws:iam::404068503087:role/OpenSearchSNSRole"
critical_topic_arn = "arn:aws:sns:us-east-1:404068503087:soc-alerts-critical"
high_topic_arn = "arn:aws:sns:us-east-1:404068503087:soc-alerts-high"
medium_topic_arn = "arn:aws:sns:us-east-1:404068503087:soc-alerts-medium"
```

**⚠️ IMPORTANT:** Check your email (captain.gab@protonmail.com) and **confirm all 3 SNS subscriptions**!

---

### 📝 **Legacy Per-Module Deployment (Deprecated)**

<details>
<summary>Click to expand old deployment method (not recommended)</summary>

**Old Step 1: Deploy SNS Topics First**

```bash
cd security-account/soc-alerting
terraform init
terraform apply
```

**Old Step 2: Deploy OpenSearch**

```bash
cd security-account/opensearch
terraform init
terraform apply
```

**⚠️ This method is deprecated. Use unified deployment instead.**

</details>

---

### **Step 2: Get Deployment Outputs**

```bash
cd security-account/backend-bootstrap
terraform output
```

**📝 Copy these values - you'll need them next!**

---

## 🔗 **Create SNS Destinations in OpenSearch**

### **Step 3: Access OpenSearch Dashboards**

1. **Get the dashboard URL:**
   ```bash
   cd security-account/backend-bootstrap
   terraform output opensearch_dashboard_endpoint
   ```

2. **Get admin password:**
   ```bash
   aws secretsmanager get-secret-value \
     --secret-id opensearch-admin-password \
     --query SecretString \
     --output text
   ```

3. **Open in browser:**
   - URL: (from step 1)
   - Username: `admin`
   - Password: (from step 2)

---

### **Step 4: Create SNS Destinations (Manual UI Steps)**

#### **A. Navigate to Alerting**
1. Click hamburger menu (☰) in top left
2. Go to: **Alerting → Destinations**
3. Click **Create destination**

---

#### **B. Create Critical Alerts Destination**

**Configuration:**
```
Name: SNS Critical Alerts
Type: Amazon SNS

SNS Topic ARN:
arn:aws:sns:us-east-1:404068503087:soc-alerts-critical

IAM Role ARN:
arn:aws:iam::404068503087:role/OpenSearchSNSRole
```

**Click "Create"**

**⚠️ IMPORTANT:** Copy the generated **Destination ID** (looks like: `dest-sns-critical-abc123def456`)

---

#### **C. Create High Alerts Destination**

```
Name: SNS High Alerts
Type: Amazon SNS

SNS Topic ARN:
arn:aws:sns:us-east-1:404068503087:soc-alerts-high

IAM Role ARN:
arn:aws:iam::404068503087:role/OpenSearchSNSRole
```

**Copy Destination ID**

---

#### **D. Create Medium Alerts Destination**

```
Name: SNS Medium Alerts
Type: Amazon SNS

SNS Topic ARN:
arn:aws:sns:us-east-1:404068503087:soc-alerts-medium

IAM Role ARN:
arn:aws:iam::404068503087:role/OpenSearchSNSRole
```

**Copy Destination ID**

---

### **Step 5: Update Monitor JSON Files**

Update your monitor files with the **actual Destination IDs** you copied:

#### **guardduty-monitor.json**
```json
{
  "actions": [{
    "name": "notify-sns",
    "destination_id": "YOUR_ACTUAL_CRITICAL_DESTINATION_ID"
  }]
}
```

#### **root-account-monitor.json**
```json
{
  "actions": [{
    "name": "notify-sns-critical",
    "destination_id": "YOUR_ACTUAL_CRITICAL_DESTINATION_ID"
  }]
}
```

#### **vpc-anomalies-monitor.json**
```json
{
  "actions": [{
    "name": "notify-sns",
    "destination_id": "YOUR_ACTUAL_MEDIUM_DESTINATION_ID"
  }]
}
```

#### **terraform-state-monitor.json**
```json
{
  "actions": [{
    "name": "notify-sns",
    "destination_id": "YOUR_ACTUAL_HIGH_DESTINATION_ID"
  }]
}
```

---

### **Step 6: Upload Monitors to OpenSearch**

**Option A: Automated Script (Recommended)**

```bash
cd security-account/soc-alerting/monitors
./deploy-monitors.sh
```

**Option B: Manual Upload**

```bash
cd security-account/soc-alerting/monitors

# Get OpenSearch endpoint
OPENSEARCH_ENDPOINT=$(cd ../../backend-bootstrap && terraform output -raw opensearch_endpoint | sed 's|https://||')

# Get admin password
OPENSEARCH_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id opensearch-admin-password \
  --query SecretString \
  --output text)

# Upload GuardDuty monitor
curl -X POST "https://${OPENSEARCH_ENDPOINT}/_plugins/_alerting/monitors" \
  -H "Content-Type: application/json" \
  -u "admin:${OPENSEARCH_PASSWORD}" \
  -d @guardduty-monitor.json

# Upload Root Account monitor
curl -X POST "https://${OPENSEARCH_ENDPOINT}/_plugins/_alerting/monitors" \
  -H "Content-Type: application/json" \
  -u "admin:${OPENSEARCH_PASSWORD}" \
  -d @root-account-monitor.json

# Upload VPC Anomalies monitor
curl -X POST "https://${OPENSEARCH_ENDPOINT}/_plugins/_alerting/monitors" \
  -H "Content-Type: application/json" \
  -u "admin:${OPENSEARCH_PASSWORD}" \
  -d @vpc-anomalies-monitor.json

# Upload Terraform State monitor
curl -X POST "https://${OPENSEARCH_ENDPOINT}/_plugins/_alerting/monitors" \
  -H "Content-Type: application/json" \
  -u "admin:${OPENSEARCH_PASSWORD}" \
  -d @terraform-state-monitor.json
```

**Expected Response:** `{"_id":"monitor-id","_version":1,"monitor":{"name":"..."}}`

---

## ✅ **Verification Steps**

### **1. Verify IAM Role Exists**
```bash
aws iam get-role --role-name OpenSearchSNSRole
```

**Expected:** Role details with trust policy for `es.amazonaws.com`

---

### **2. Verify SNS Topics Exist**
```bash
aws sns list-topics | grep soc-alerts
```

**Expected:**
```
"TopicArn": "arn:aws:sns:us-east-1:404068503087:soc-alerts-critical"
"TopicArn": "arn:aws:sns:us-east-1:404068503087:soc-alerts-high"
"TopicArn": "arn:aws:sns:us-east-1:404068503087:soc-alerts-medium"
```

---

### **3. Verify Email Subscriptions**
```bash
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:404068503087:soc-alerts-critical
```

**Expected:** Status = "Confirmed" (after clicking email link)

---

### **4. Test SNS Publishing**
```bash
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:404068503087:soc-alerts-critical \
  --message "Test alert from OpenSearch setup" \
  --subject "OpenSearch Test Alert"
```

**Expected:** You receive an email within 1 minute

---

### **5. Verify Monitors in OpenSearch**

**Option A: Via UI**
- Open OpenSearch Dashboards
- Go to: **Alerting → Monitors**
- Should see 4 monitors listed with "Enabled" status

**Option B: Via API**
```bash
curl -X GET "https://${OPENSEARCH_ENDPOINT}/_plugins/_alerting/monitors/_search" \
  -u "admin:${OPENSEARCH_PASSWORD}" \
  -H "Content-Type: application/json"
```

---

## 🧪 **Test End-to-End Alert Flow**

### **Test 1: Manual SNS Test (Bypass OpenSearch)**
```bash
# This tests SNS → Email directly
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:404068503087:soc-alerts-high \
  --message '{"severity":"HIGH","service":"GuardDuty","finding":"Test Finding"}' \
  --subject "SOC Alert Test - High Severity"
```

✅ **Success:** Email received at captain.gab@protonmail.com

---

### **Test 2: OpenSearch Monitor Test**

**Via OpenSearch UI:**
1. Go to **Alerting → Monitors**
2. Click on "guardduty-high-critical" monitor
3. Click **Run** button (play icon)
4. Check if alert was triggered

**Via API:**
```bash
# Execute monitor manually
curl -X POST "https://${OPENSEARCH_ENDPOINT}/_plugins/_alerting/monitors/MONITOR_ID/_execute" \
  -u "admin:${OPENSEARCH_PASSWORD}" \
  -H "Content-Type: application/json"
```

---

### **Test 3: Trigger Real GuardDuty Finding**
```bash
# Create sample GuardDuty finding (safe test)
aws guardduty create-sample-findings \
  --detector-id $(aws guardduty list-detectors --query 'DetectorIds[0]' --output text) \
  --finding-types "Recon:EC2/PortProbeUnprotectedPort"
```

**Expected Flow:**
1. GuardDuty creates finding (severity: Medium/High)
2. Finding flows to Security Lake
3. Lambda ingests into OpenSearch
4. Monitor detects finding within 1 minute
5. Alert sent to SNS
6. Email received at captain.gab@protonmail.com

⏱️ **Total time:** 2-5 minutes

---

## 📊 **Architecture Diagram**

```
┌─────────────────────────────────────────────────────────────┐
│                   ALERTING FLOW                              │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Security Lake → Lambda → OpenSearch → Monitor → SNS → Email│
│                                                               │
│  ┌──────────────┐                                           │
│  │ Security Lake│                                           │
│  │   (OCSF)     │                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐                                           │
│  │  OpenSearch  │                                           │
│  │ Index Pattern│                                           │
│  │securitylake-*│                                           │
│  └──────┬───────┘                                           │
│         │                                                    │
│         ▼                                                    │
│  ┌──────────────┐         ┌─────────────────┐             │
│  │   Monitor    │────────►│  SNS Critical   │             │
│  │ (1 min scan) │         │  SNS High       │             │
│  │              │         │  SNS Medium     │             │
│  └──────────────┘         └────────┬────────┘             │
│         ▲                          │                        │
│         │                          │                        │
│         │                          ▼                        │
│  ┌──────────────┐         ┌─────────────────┐             │
│  │ IAM Role:    │         │ Email:          │             │
│  │OpenSearchSNS │         │captain.gab@     │             │
│  │ Role         │         │protonmail.com   │             │
│  └──────────────┘         └─────────────────┘             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 📝 **Quick Reference**

### **Key ARNs (From Terraform Output)**

```bash
# Get all needed values from unified deployment
cd security-account/backend-bootstrap

terraform output opensearch_sns_role_arn
terraform output opensearch_endpoint
terraform output critical_topic_arn
terraform output high_topic_arn
terraform output medium_topic_arn
```

### **OpenSearch Destinations Summary**

| Destination Name | Type | SNS Topic | IAM Role | Severity |
|-----------------|------|-----------|----------|----------|
| SNS Critical Alerts | SNS | soc-alerts-critical | OpenSearchSNSRole | Critical (1) |
| SNS High Alerts | SNS | soc-alerts-high | OpenSearchSNSRole | High (2) |
| SNS Medium Alerts | SNS | soc-alerts-medium | OpenSearchSNSRole | Medium (3) |

---

## ✅ **Success Checklist**

- [x] **IAM role created** - `OpenSearchSNSRole`
- [x] **IAM policy attached** - SNS publish permissions
- [x] **Outputs added** - Easy reference for ARNs
- [ ] **All infrastructure deployed** - Run `terraform apply` in backend-bootstrap/
- [ ] **Email subscriptions confirmed** - Check email and click links
- [ ] **SNS destinations created** - Manual step in OpenSearch UI
- [ ] **Destination IDs updated** - Update monitor JSON files
- [ ] **Monitors uploaded** - Run `./deploy-monitors.sh` script
- [ ] **Monitors enabled** - Verify in OpenSearch UI
- [ ] **Test alert sent** - Receive email successfully

---

## 🎯 **Next Steps**

1. ✅ **Deploy everything:** `cd security-account/backend-bootstrap && terraform apply`
2. ✅ **Confirm email subscriptions** (check inbox for 3 confirmation emails)
3. ⏳ **Create SNS destinations** in OpenSearch Dashboards UI
4. ⏳ **Update monitor JSON files** with destination IDs
5. ⏳ **Upload monitors:** `cd soc-alerting/monitors && ./deploy-monitors.sh`
6. ⏳ **Test alert flow** end-to-end
7. ⏳ **Create dashboards** for visualization (optional)

---

## 📚 **Related Documentation**

- **[UNIFIED-DEPLOYMENT-GUIDE.md](./UNIFIED-DEPLOYMENT-GUIDE.md)** - Complete deployment guide ⭐
- **[QUICK-REFERENCE.md](./QUICK-REFERENCE.md)** - One-page quick reference
- **[soc-alerting/MONITOR-STATUS-SUMMARY.md](./soc-alerting/MONITOR-STATUS-SUMMARY.md)** - Monitor deployment checklist
- **[README.md](./README.md)** - Master documentation index

---

**Status:** ✅ **IAM ROLE IMPLEMENTATION COMPLETE**
**Ready for deployment!** 🚀

**Last Updated:** January 12, 2026

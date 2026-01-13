# ✅ SOC Alerting Monitors - Status Summary

## ⚠️ What Still Needs to Be Done

### 1. **Create SNS Destinations in OpenSearch** (REQUIRED)

You need to create 3 destinations in OpenSearch Dashboards:

**Path:** OpenSearch Dashboards → Alerting → Destinations → Create destination

#### Destination 1: Critical Alerts
```
Name: SNS Critical Alerts
Type: Amazon SNS
SNS Topic ARN: arn:aws:sns:us-east-1:404068503087:soc-alerts-critical
IAM Role ARN: arn:aws:iam::404068503087:role/OpenSearchSNSRole
```

#### Destination 2: High Alerts
```
Name: SNS High Alerts
Type: Amazon SNS
SNS Topic ARN: arn:aws:sns:us-east-1:404068503087:soc-alerts-high
IAM Role ARN: arn:aws:iam::404068503087:role/OpenSearchSNSRole
```

#### Destination 3: Medium Alerts
```
Name: SNS Medium Alerts
Type: Amazon SNS
SNS Topic ARN: arn:aws:sns:us-east-1:404068503087:soc-alerts-medium
IAM Role ARN: arn:aws:iam::404068503087:role/OpenSearchSNSRole
```

**⚠️ IMPORTANT:** Copy the generated **Destination ID** from each (looks like: `dest-abc123xyz`)

---

### 2. **Update Destination IDs in Monitor Files** (REQUIRED)

Replace placeholder IDs in each monitor JSON file:

**guardduty-monitor.json:**
```json
"destination_id": "YOUR_ACTUAL_CRITICAL_DESTINATION_ID"
```

**root-account-monitor.json:**
```json
"destination_id": "YOUR_ACTUAL_CRITICAL_DESTINATION_ID"
```

**terraform-state-monitor.json:**
```json
"destination_id": "YOUR_ACTUAL_HIGH_DESTINATION_ID"
```

**vpc-anomalies-monitor.json:**
```json
"destination_id": "YOUR_ACTUAL_MEDIUM_DESTINATION_ID"
```

---

### 3. **Upload Monitors to OpenSearch** (REQUIRED)

**Option A: Automated Script (Recommended)**

```bash
cd security-account/soc-alerting/monitors
./deploy-monitors.sh
```

**Option B: Manual Upload**

```bash
cd security-account/soc-alerting/monitors

# Get OpenSearch endpoint
OPENSEARCH_ENDPOINT=$(cd ../../opensearch && terraform output -raw opensearch_endpoint | sed 's|https://||')

# Get admin password
OPENSEARCH_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id opensearch-admin-password \
  --query SecretString \
  --output text \
  --region us-east-1)

# Upload each monitor
curl -X POST "https://${OPENSEARCH_ENDPOINT}/_plugins/_alerting/monitors" \
  -H "Content-Type: application/json" \
  -u "admin:${OPENSEARCH_PASSWORD}" \
  -d @guardduty-monitor.json

curl -X POST "https://${OPENSEARCH_ENDPOINT}/_plugins/_alerting/monitors" \
  -H "Content-Type: application/json" \
  -u "admin:${OPENSEARCH_PASSWORD}" \
  -d @root-account-monitor.json

curl -X POST "https://${OPENSEARCH_ENDPOINT}/_plugins/_alerting/monitors" \
  -H "Content-Type: application/json" \
  -u "admin:${OPENSEARCH_PASSWORD}" \
  -d @terraform-state-monitor.json

curl -X POST "https://${OPENSEARCH_ENDPOINT}/_plugins/_alerting/monitors" \
  -H "Content-Type: application/json" \
  -u "admin:${OPENSEARCH_PASSWORD}" \
  -d @vpc-anomalies-monitor.json
```

**Expected Response:** HTTP 201 with monitor ID

---

## 📋 Deployment Checklist

- [ ] **1. Prerequisites**
  - [ ] OpenSearch domain deployed and active
  - [ ] SNS topics created (critical, high, medium)
  - [ ] SNS email subscriptions confirmed
  - [ ] IAM role `OpenSearchSNSRole` exists

- [ ] **2. Create Destinations**
  - [ ] Create "SNS Critical Alerts" destination
  - [ ] Create "SNS High Alerts" destination
  - [ ] Create "SNS Medium Alerts" destination
  - [ ] Copy all 3 destination IDs

- [ ] **3. Update Monitor Files**
  - [ ] Update `guardduty-monitor.json` destination ID
  - [ ] Update `root-account-monitor.json` destination ID
  - [ ] Update `terraform-state-monitor.json` destination ID
  - [ ] Update `vpc-anomalies-monitor.json` destination ID

- [ ] **4. Deploy Monitors**
  - [ ] Run `./deploy-monitors.sh` OR
  - [ ] Upload manually via curl commands

- [ ] **5. Verification**
  - [ ] Verify 4 monitors exist in OpenSearch Dashboards
  - [ ] Verify all monitors are enabled
  - [ ] Test each monitor (optional but recommended)
  - [ ] Confirm SNS alerts are received

---

## 🧪 Testing

### Test GuardDuty Monitor
```bash
# Manually trigger monitor
curl -X POST "https://${OPENSEARCH_ENDPOINT}/_plugins/_alerting/monitors/MONITOR_ID/_execute" \
  -u "admin:${OPENSEARCH_PASSWORD}"
```

### Test Root Account Monitor
```bash
# Use root account to log in to AWS Console (⚠️ DO NOT do in production!)
# Or simulate by injecting test data into Security Lake
```

### Test Terraform State Monitor
```bash
# Access Terraform state outside approved role
aws s3 cp s3://org-terraform-state-security/workload/terraform.tfstate /tmp/test.tfstate
```

### Test VPC Anomalies Monitor
```bash
# Generate rejected VPC traffic (e.g., port scan simulation)
# Or wait for natural rejected traffic to accumulate >100 events
```

---

## 🎯 Expected Behavior

Once deployed and configured correctly:

1. **GuardDuty Monitor:**
   - Runs every 1 minute
   - Triggers on ANY HIGH or CRITICAL GuardDuty finding
   - Sends email to critical SNS topic subscribers

2. **Root Account Monitor:**
   - Runs every 1 minute
   - Triggers on ANY root account activity
   - Sends email to critical SNS topic subscribers

3. **Terraform State Monitor:**
   - Runs every 5 minutes
   - Triggers on unauthorized Terraform state access
   - Sends email to high SNS topic subscribers

4. **VPC Anomalies Monitor:**
   - Runs every 5 minutes
   - Triggers if >100 rejected VPC flows detected
   - Sends email to medium SNS topic subscribers

---

## 📖 Documentation Reference

| Document | Purpose |
|----------|---------|
| [MONITOR-CONFIGURATION-REVIEW.md](./MONITOR-CONFIGURATION-REVIEW.md) | Detailed monitor analysis and deployment guide |
| [README.md](./README.md) | SOC alerting strategy and philosophy |
| [../OPENSEARCH-SNS-SETUP.md](../OPENSEARCH-SNS-SETUP.md) | OpenSearch and SNS integration guide |
| [deploy-monitors.sh](./monitors/deploy-monitors.sh) | Automated deployment script |

---

## 💡 Key Takeaways

1. ✅ **Monitor structure is correct** - All JSON files are valid OpenSearch monitor definitions
2. ✅ **Field names are correct** - Fixed root account monitor to use OCSF format
3. ❌ **Monitors are not deployed** - JSON files are templates only, not active monitors
4. ⚠️ **Destination IDs are placeholders** - Must be replaced with real IDs from OpenSearch
5. 📝 **Manual steps required** - Cannot deploy monitors via Terraform, must use OpenSearch API

**Bottom line:** Your monitors are well-designed and production-ready, but require manual deployment through OpenSearch Dashboards or REST API to become active.

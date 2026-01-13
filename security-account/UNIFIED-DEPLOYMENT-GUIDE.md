# 🚀 Security Account - Unified Deployment Guide

## 📋 Overview

**ALL security infrastructure is now deployed from a single location:** `security-account/backend-bootstrap/`

This centralized approach deploys all components in the correct dependency order through a single `terraform apply` command.

---

## 🏗️ Architecture - Deployment Flow

```
backend-bootstrap/main.tf (SINGLE ENTRY POINT)
         ↓
┌────────────────────────────────────────────────┐
│  Module 1: Cross-Account Roles                │
│  - IAM roles for cross-account access         │
│  - S3 buckets (CloudTrail, VPC Flow, State)   │
│  - KMS keys for encryption                    │
│  - CloudTrail data events trail               │
│  - EventBridge + SNS for state monitoring     │
└────────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────────┐
│  Module 2: Security Lake                      │
│  - OCSF 1.1.0 data lake                      │
│  - Glue database and crawler                  │
│  - Athena workgroup                           │
│  - 730-day retention                          │
└────────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────────┐
│  Module 3: Athena Queries (NEW!)              │
│  - 7 named queries for security analysis      │
│  - 4 view creation queries                    │
│  - VPC, Terraform state, GuardDuty, auth      │
└────────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────────┐
│  Module 4: OpenSearch                         │
│  - Security log visualization                 │
│  - IAM role for SNS integration               │
│  - Admin password in Secrets Manager          │
└────────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────────┐
│  Module 5: SOC Alerting                       │
│  - 3 SNS topics (critical, high, medium)      │
│  - Email subscriptions                        │
│  - Dead Letter Queue (DLQ)                    │
│  - DLQ monitoring with CloudWatch             │
└────────────────────────────────────────────────┘
         ↓
┌────────────────────────────────────────────────┐
│  Module 6: Config Drift Detection             │
│  - AWS Config rules                           │
│  - Compliance monitoring                      │
└────────────────────────────────────────────────┘
```

---

## 🚀 Single Command Deployment

### Prerequisites

1. AWS CLI configured with security account credentials
2. Terraform >= 1.5.0 installed
3. Access to security account (404068503087)
4. Remote state backend already configured

### Deployment Steps

```bash
# Navigate to deployment directory
cd security-account/backend-bootstrap

# Review configuration
cat terraform.tfvars
```

Expected `terraform.tfvars`:
```terraform
config_bucket_name  = "org-aws-config-logs-prod"
security_account_id = "404068503087"
workload_account_id = "290793900072"
region              = "us-east-1"
```

```bash
# Initialize Terraform
terraform init

# Review what will be deployed
terraform plan

# Deploy everything
terraform apply
```

**Expected Output:**
```
Plan: 85+ resources to add, 0 to change, 0 to destroy.

module.cross-account-role.aws_s3_bucket.cloudtrail_logs: Creating...
module.cross-account-role.aws_kms_key.security_lake: Creating...
module.security-lake.aws_glue_catalog_database.security_lake: Creating...
module.athena.aws_athena_named_query.vpc_traffic_anomalies: Creating...
module.opensearch.aws_opensearch_domain.security_logs: Creating...
module.soc-alerting.aws_sns_topic.critical: Creating...
...

Apply complete! Resources: 85 added, 0 changed, 0 destroyed.

Outputs:

cloudtrail_logs_bucket = "org-cloudtrail-logs-security-404068503087"
opensearch_endpoint = "https://search-security-logs-xxxxx.us-east-1.es.amazonaws.com"
critical_topic_arn = "arn:aws:sns:us-east-1:404068503087:soc-alerts-critical"
athena_workgroup_name = "security-lake-queries"
...
```

---

## 📦 What Gets Deployed

### Automatically Deployed via Terraform

| Component | Module | Resources | Status |
|-----------|--------|-----------|--------|
| **S3 Buckets** | cross-account-role | CloudTrail logs, VPC Flow logs, Terraform state, State access logs | ✅ Auto |
| **IAM Roles** | cross-account-role | SecurityAuditor, TerraformBackend, etc. | ✅ Auto |
| **KMS Keys** | cross-account-role | Security Lake encryption, S3 encryption | ✅ Auto |
| **CloudTrail** | cross-account-role | Data events trail for Terraform state | ✅ Auto |
| **EventBridge** | cross-account-role | Real-time state access detection | ✅ Auto |
| **Security Lake** | security-lake | OCSF data lake, Glue database, Athena workgroup | ✅ Auto |
| **Athena Queries** | athena | 7 named queries + 4 view creation queries | ✅ Auto |
| **OpenSearch** | opensearch | Domain, admin password, SNS role | ✅ Auto |
| **SNS Topics** | soc-alerting | 3 severity-based topics, email subscriptions | ✅ Auto |
| **DLQ Monitoring** | soc-alerting | SQS DLQ, CloudWatch alarm | ✅ Auto |
| **AWS Config** | config-drift-detection | Config rules, compliance monitoring | ✅ Auto |

### Manual Post-Deployment Steps

| Component | Action Required | When | Documentation |
|-----------|-----------------|------|---------------|
| **SNS Email Confirmation** | Confirm 3 email subscriptions | After deployment | Check captain.gab@protonmail.com |
| **OpenSearch Destinations** | Create 3 SNS destinations in UI | After OpenSearch ready | [MONITOR-STATUS-SUMMARY.md](./soc-alerting/MONITOR-STATUS-SUMMARY.md) |
| **OpenSearch Monitors** | Upload 4 monitor JSON files | After destinations created | [deploy-monitors.sh](./soc-alerting/monitors/deploy-monitors.sh) |
| **Athena Views** | Run 4 view creation queries | After Athena deployed | [athena/README.md](./athena/README.md#create-views-one-time-setup) |
| **OpenSearch Dashboards** | Create visualizations | Optional | [SOC-SETUP-VALIDATION.md](./SOC-SETUP-VALIDATION.md#dashboard-creation-steps) |

---

## ✅ Post-Deployment Verification

### 1. Verify All Modules Deployed

```bash
cd security-account/backend-bootstrap

# List all deployed resources
terraform state list

# Expected output should include:
# module.cross-account-role.aws_s3_bucket.cloudtrail_logs
# module.security-lake.aws_glue_catalog_database.security_lake
# module.athena.aws_athena_named_query.vpc_traffic_anomalies
# module.opensearch.aws_opensearch_domain.security_logs
# module.soc-alerting.aws_sns_topic.critical
# module.config-drift-detection.aws_config_configuration_recorder.main
```

### 2. Verify S3 Buckets

```bash
# List security buckets
aws s3 ls | grep -E "cloudtrail|vpc-flow|terraform-state|athena"

# Expected:
# org-cloudtrail-logs-security-404068503087
# org-vpc-flow-logs-security-404068503087
# org-terraform-state-security
# org-terraform-state-logs-404068503087
# org-athena-query-results-404068503087
```

### 3. Verify Security Lake

```bash
# Check Glue database
aws glue get-database --name amazon_security_lake_glue_db_us_east_1

# Check Glue crawler
aws glue get-crawler --name security-lake-crawler

# Check Athena workgroup
aws athena get-work-group --work-group security-lake-queries
```

### 4. Verify Athena Queries

```bash
# List Athena named queries
aws athena list-named-queries --region us-east-1

# Get query details
aws athena get-named-query --named-query-id <query-id>

# Expected 11 queries:
# - vpc-traffic-anomalies
# - terraform-state-access
# - privileged-activity-monitoring
# - guardduty-high-severity-findings
# - failed-authentication-attempts
# - s3-public-access-changes
# - security-group-changes
# - create-view-vpc-traffic-anomalies
# - create-view-terraform-state-access
# - create-view-privileged-activity
# - create-view-guardduty-findings
```

### 5. Verify OpenSearch

```bash
# Get OpenSearch endpoint
cd security-account/backend-bootstrap
terraform output opensearch_endpoint

# Get admin password
aws secretsmanager get-secret-value \
  --secret-id opensearch-admin-password \
  --query SecretString \
  --output text

# Test OpenSearch access
curl -u "admin:<password>" \
  "https://<opensearch-endpoint>/_cluster/health"
```

### 6. Verify SNS Topics

```bash
# List SNS topics
aws sns list-topics | grep soc-alerts

# Expected:
# arn:aws:sns:us-east-1:404068503087:soc-alerts-critical
# arn:aws:sns:us-east-1:404068503087:soc-alerts-high
# arn:aws:sns:us-east-1:404068503087:soc-alerts-medium

# Check subscriptions
aws sns list-subscriptions-by-topic \
  --topic-arn arn:aws:sns:us-east-1:404068503087:soc-alerts-critical
```

---

## 🔧 Manual Configuration Steps

### Step 1: Confirm SNS Email Subscriptions

⚠️ **REQUIRED** - Alerts won't work without this!

1. Check email: **captain.gab@protonmail.com**
2. Find 3 emails from AWS SNS
3. Click "Confirm subscription" in each email
4. Verify confirmation:

```bash
aws sns list-subscriptions | grep captain.gab@protonmail.com
# All should show "SubscriptionArn" (not "PendingConfirmation")
```

---

### Step 2: Create OpenSearch SNS Destinations

📍 **Location:** OpenSearch Dashboards → Alerting → Destinations

#### Destination 1: Critical Alerts
```
Name: SNS Critical Alerts
Type: Amazon SNS
SNS Topic ARN: arn:aws:sns:us-east-1:404068503087:soc-alerts-critical
IAM Role ARN: arn:aws:iam::404068503087:role/OpenSearchSNSRole
```

**⚠️ Copy the generated Destination ID** (e.g., `dest-abc123xyz`)

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

---

### Step 3: Update Monitor JSON Files

Update destination IDs in monitor files:

```bash
cd security-account/soc-alerting/monitors

# Edit each file and replace "destination_id" values with actual IDs from Step 2
# - guardduty-monitor.json → Critical destination ID
# - root-account-monitor.json → Critical destination ID
# - terraform-state-monitor.json → High destination ID
# - vpc-anomalies-monitor.json → Medium destination ID
```

---

### Step 4: Upload OpenSearch Monitors

**Option A: Automated Script (Recommended)**

```bash
cd security-account/soc-alerting/monitors
./deploy-monitors.sh
```

**Option B: Manual Upload**

```bash
# Get OpenSearch endpoint
OPENSEARCH_ENDPOINT=$(cd ../../backend-bootstrap && terraform output -raw opensearch_endpoint | sed 's|https://||')

# Get admin password
OPENSEARCH_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id opensearch-admin-password \
  --query SecretString \
  --output text)

# Upload monitors
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

---

### Step 5: Create Athena Views (Optional)

Run these in Athena Console to create reusable views:

1. Navigate to: https://console.aws.amazon.com/athena
2. Select workgroup: `security-lake-queries`
3. Go to "Saved queries"
4. Run these 4 queries:
   - `create-view-vpc-traffic-anomalies`
   - `create-view-terraform-state-access`
   - `create-view-privileged-activity`
   - `create-view-guardduty-findings`

---

## 🎯 Complete Deployment Checklist

### Automated (via terraform apply)
- [x] S3 buckets created
- [x] IAM roles created
- [x] KMS keys created
- [x] CloudTrail data events configured
- [x] EventBridge rules created
- [x] Security Lake deployed
- [x] Glue database created
- [x] Glue crawler configured
- [x] Athena workgroup created
- [x] Athena named queries created
- [x] OpenSearch domain deployed
- [x] OpenSearch SNS IAM role created
- [x] SNS topics created
- [x] SNS email subscriptions created
- [x] DLQ created
- [x] DLQ CloudWatch alarm created
- [x] AWS Config rules deployed

### Manual (post-deployment)
- [ ] SNS email subscriptions confirmed
- [ ] OpenSearch destinations created (3 destinations)
- [ ] Monitor JSON files updated with destination IDs
- [ ] OpenSearch monitors uploaded (4 monitors)
- [ ] Athena views created (4 views)
- [ ] OpenSearch dashboards created (optional)
- [ ] End-to-end alert testing completed

---

## 🧪 Testing

### Test GuardDuty Alert
```bash
aws guardduty create-sample-findings \
  --detector-id <detector-id> \
  --finding-types Recon:EC2/PortProbeUnprotectedPort

# Wait 1-2 minutes
# Check email for critical alert
```

### Test Terraform State Access Alert
```bash
# Access state file (triggers EventBridge + SNS immediately)
aws s3 cp s3://org-terraform-state-security/backend-bootstrap/terraform.tfstate /tmp/test.tfstate

# Check email for high severity alert
```

### Test Athena Query
```bash
# Run VPC traffic anomalies query
aws athena start-query-execution \
  --query-string "SELECT * FROM security_vpc_traffic_anomalies LIMIT 10" \
  --work-group security-lake-queries \
  --result-configuration "OutputLocation=s3://org-athena-query-results-404068503087/"
```

---

## 📊 Monitoring & Operations

### View Terraform State
```bash
cd security-account/backend-bootstrap
terraform show
```

### Update Individual Module
```bash
# Target specific module for updates
terraform apply -target=module.athena
terraform apply -target=module.opensearch
```

### Destroy Everything (⚠️ DANGEROUS)
```bash
cd security-account/backend-bootstrap
terraform destroy
```

---

## 🔗 Documentation Links

| Document | Purpose |
|----------|---------|
| [athena/DEPLOYMENT-GUIDE.md](./athena/DEPLOYMENT-GUIDE.md) | Athena queries and views |
| [athena/README.md](./athena/README.md) | Athena configuration details |
| [soc-alerting/MONITOR-STATUS-SUMMARY.md](./soc-alerting/MONITOR-STATUS-SUMMARY.md) | OpenSearch monitor deployment |
| [soc-alerting/MONITOR-CONFIGURATION-REVIEW.md](./soc-alerting/MONITOR-CONFIGURATION-REVIEW.md) | Monitor technical review |
| [soc-alerting/README.md](./soc-alerting/README.md) | SOC alerting strategy |
| [SOC-SETUP-VALIDATION.md](./SOC-SETUP-VALIDATION.md) | Complete validation guide |
| [START-HERE.md](./START-HERE.md) | Legacy deployment guide (deprecated) |

---

## ⚡ Quick Commands Reference

```bash
# Deploy everything
cd security-account/backend-bootstrap && terraform apply

# Upload OpenSearch monitors
cd security-account/soc-alerting/monitors && ./deploy-monitors.sh

# View outputs
cd security-account/backend-bootstrap && terraform output

# Check OpenSearch status
aws opensearch describe-domain --domain-name security-logs

# Check Security Lake crawler
aws glue get-crawler --name security-lake-crawler

# List Athena queries
aws athena list-named-queries

# Test SNS topic
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:404068503087:soc-alerts-critical \
  --message "Test alert" \
  --subject "Test Alert"
```

---

## 🎉 Success Criteria

Your security infrastructure is fully operational when:

1. ✅ `terraform apply` completes without errors
2. ✅ All 6 modules show "Apply complete"
3. ✅ SNS email subscriptions confirmed (3/3)
4. ✅ OpenSearch destinations created (3/3)
5. ✅ OpenSearch monitors uploaded and enabled (4/4)
6. ✅ Test alerts successfully delivered to email
7. ✅ Athena queries return data from Security Lake
8. ✅ OpenSearch Dashboards accessible
9. ✅ CloudTrail logs flowing to S3
10. ✅ Security Lake ingesting data (check Glue tables)

---

**Last Updated:** January 13, 2026
**Deployment Method:** Centralized via `backend-bootstrap/main.tf`
**Status:** ✅ Production Ready

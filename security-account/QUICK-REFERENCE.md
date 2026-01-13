# 🚀 Security Account - Quick Reference Card

## 📋 One-Command Deployment

```bash
cd security-account/backend-bootstrap && terraform apply
```

**Deploys:** All security infrastructure (S3, IAM, Security Lake, Athena, OpenSearch, SNS, DLQ, Config)

---

## ✅ Post-Deployment Checklist

### 1. Confirm SNS Email Subscriptions
- [ ] Check email: captain.gab@protonmail.com
- [ ] Click "Confirm subscription" in 3 AWS SNS emails
- [ ] Verify: `aws sns list-subscriptions | grep Confirmed`

### 2. Create OpenSearch Destinations
- [ ] Open: `https://<opensearch-endpoint>/_dashboards`
- [ ] Navigate: Alerting → Destinations → Create destination
- [ ] Create 3 destinations (Critical, High, Medium)
- [ ] Copy destination IDs

### 3. Update Monitor Files
- [ ] Edit: `security-account/soc-alerting/monitors/*.json`
- [ ] Replace `destination_id` with actual IDs from step 2

### 4. Upload OpenSearch Monitors
- [ ] Run: `cd security-account/soc-alerting/monitors && ./deploy-monitors.sh`
- [ ] Verify: OpenSearch Dashboards → Alerting → Monitors

### 5. Create Athena Views (Optional)
- [ ] Open: https://console.aws.amazon.com/athena
- [ ] Run 4 "create-view-*" queries from Saved queries

---

## 🔍 Verification Commands

```bash
# Check all modules deployed
cd security-account/backend-bootstrap
terraform state list | wc -l  # Should show 80+ resources

# Verify S3 buckets
aws s3 ls | grep -E "cloudtrail|vpc-flow|terraform-state|athena"

# Verify Security Lake
aws glue get-database --name amazon_security_lake_glue_db_us_east_1

# Verify Athena queries
aws athena list-named-queries | wc -l  # Should show 11+ queries

# Verify OpenSearch
aws opensearch describe-domain --domain-name security-logs

# Verify SNS topics
aws sns list-topics | grep soc-alerts  # Should show 3 topics

# Test SNS alert
aws sns publish \
  --topic-arn arn:aws:sns:us-east-1:404068503087:soc-alerts-critical \
  --message "Test" --subject "Test"
```

---

## 🧪 Testing

### Test CloudTrail → Security Lake
```bash
# Generate API call
aws s3 ls s3://org-terraform-state-security/

# Wait 5-10 minutes for Security Lake ingestion
# Query in Athena:
# SELECT * FROM amazon_security_lake_glue_db_us_east_1.amazon_cloudtrail_mgmt LIMIT 10
```

### Test GuardDuty → OpenSearch Alert
```bash
# Create sample finding
aws guardduty create-sample-findings \
  --detector-id <detector-id> \
  --finding-types Recon:EC2/PortProbeUnprotectedPort

# Check email in 1-2 minutes
```

### Test Terraform State Access Alert
```bash
# Access state file (triggers immediate alert)
aws s3 cp s3://org-terraform-state-security/backend-bootstrap/terraform.tfstate /tmp/test.tfstate

# Check email for HIGH severity alert
```

---

## 📊 Key Outputs

```bash
cd security-account/backend-bootstrap
terraform output
```

**Important Outputs:**
- `opensearch_endpoint` - OpenSearch Dashboards URL
- `opensearch_admin_password_secret_arn` - Admin password location
- `critical_topic_arn` - Critical alerts SNS topic
- `athena_workgroup_name` - Athena workgroup for queries
- `cloudtrail_logs_bucket` - CloudTrail logs S3 bucket

---

## 🔐 Credentials

### OpenSearch Admin Password
```bash
aws secretsmanager get-secret-value \
  --secret-id opensearch-admin-password \
  --query SecretString \
  --output text
```

### OpenSearch URL
```bash
cd security-account/backend-bootstrap
terraform output opensearch_endpoint
```

**Login:** admin / [password from Secrets Manager]

---

## 📖 Documentation

| Doc | Purpose |
|-----|---------|
| [UNIFIED-DEPLOYMENT-GUIDE.md](./UNIFIED-DEPLOYMENT-GUIDE.md) | **Complete deployment guide** |
| [athena/DEPLOYMENT-GUIDE.md](./athena/DEPLOYMENT-GUIDE.md) | Athena queries deployment |
| [soc-alerting/MONITOR-STATUS-SUMMARY.md](./soc-alerting/MONITOR-STATUS-SUMMARY.md) | Monitor deployment checklist |
| [SOC-SETUP-VALIDATION.md](./SOC-SETUP-VALIDATION.md) | Validation and testing |

---

## 🆘 Troubleshooting

### Monitor Not Sending Alerts
```bash
# 1. Check SNS subscription is confirmed
aws sns list-subscriptions | grep captain.gab@protonmail.com

# 2. Check OpenSearch monitor is enabled
# Login to Dashboards → Alerting → Monitors

# 3. Check DLQ for failed deliveries
aws sqs get-queue-attributes \
  --queue-url $(aws sqs get-queue-url --queue-name soc-alerts-dlq --query QueueUrl --output text) \
  --attribute-names ApproximateNumberOfMessages
```

### Athena Query Fails
```bash
# 1. Check Glue crawler has run
aws glue get-crawler --name security-lake-crawler

# 2. Run crawler manually
aws glue start-crawler --name security-lake-crawler

# 3. Check tables exist
aws glue get-tables --database-name amazon_security_lake_glue_db_us_east_1
```

### No Data in Security Lake
```bash
# 1. Check Security Lake is ingesting logs
# AWS Console → Security Lake → Sources

# 2. Check CloudTrail is logging
aws cloudtrail describe-trails

# 3. Check S3 bucket has data
aws s3 ls s3://org-cloudtrail-logs-security-404068503087/ --recursive | head
```

---

## 🔄 Update/Redeploy

### Update Single Module
```bash
cd security-account/backend-bootstrap
terraform apply -target=module.athena
```

### Update All
```bash
cd security-account/backend-bootstrap
terraform apply
```

### Destroy (⚠️ DANGEROUS)
```bash
cd security-account/backend-bootstrap
terraform destroy
```

---

## 🎯 Success Criteria

- [x] `terraform apply` completes successfully
- [ ] SNS email subscriptions confirmed (3/3)
- [ ] OpenSearch destinations created (3/3)
- [ ] OpenSearch monitors uploaded (4/4)
- [ ] Test alert received via email
- [ ] Athena query returns data
- [ ] Security Lake ingesting logs (check Glue tables)
- [ ] CloudTrail logs in S3
- [ ] OpenSearch accessible

---

## 📞 Quick Commands

```bash
# Deploy everything
cd security-account/backend-bootstrap && terraform apply

# Upload monitors
cd security-account/soc-alerting/monitors && ./deploy-monitors.sh

# View outputs
cd security-account/backend-bootstrap && terraform output

# Get OpenSearch password
aws secretsmanager get-secret-value --secret-id opensearch-admin-password --query SecretString --output text

# Test SNS
aws sns publish --topic-arn arn:aws:sns:us-east-1:404068503087:soc-alerts-critical --message "Test"

# Check Security Lake data
aws athena start-query-execution \
  --query-string "SELECT COUNT(*) FROM amazon_security_lake_glue_db_us_east_1.amazon_cloudtrail_mgmt" \
  --work-group security-lake-queries \
  --result-configuration "OutputLocation=s3://org-athena-query-results-404068503087/"
```

---

**Last Updated:** January 13, 2026
**Deployment Time:** ~15-20 minutes
**Manual Steps:** ~10-15 minutes

# 🚀 Security Lake Deployment Guide

## Overview
This guide walks you through deploying the complete Security Lake architecture with OpenSearch, Athena, and SOC alerting using the **unified deployment method**.

**All security infrastructure deploys with a single command from `backend-bootstrap/`.**

## Related Documentation
- **[UNIFIED-DEPLOYMENT-GUIDE.md](./UNIFIED-DEPLOYMENT-GUIDE.md)** ⭐ Complete step-by-step deployment guide
- **[QUICK-REFERENCE.md](./QUICK-REFERENCE.md)** ⭐ One-page command reference
- **[README.md](./README.md)** - Master documentation index

## 📋 Prerequisites

1. **AWS Accounts:**
   - Security Account: 404068503087
   - Workload Account: 290793900072

2. **Existing Infrastructure:**
   - VPC with private subnets (for OpenSearch)
   - Cross-account roles deployed (from `/workload-account/cross-account-roles`)

3. **Required Permissions:**
   - Administrative access to security account
   - Ability to enable Security Lake

## 🎯 Deployment Steps

### Step 1: Verify Prerequisites

Ensure you have:
- AWS CLI configured with appropriate credentials
- Terraform >= 1.5.0 installed
- Access to security account (404068503087)

### Step 2: Configure Variables

```bash
cd security-account/backend-bootstrap

# Verify terraform.tfvars has correct configuration
cat terraform.tfvars
```

**Required variables:**
```hcl
security_account_id = "404068503087"
workload_account_id = "290793900072"
region             = "us-east-1"
```

### Step 3: Deploy All Infrastructure

```bash
cd security-account/backend-bootstrap
terraform init
terraform apply
```

**What this deploys:**
- ✅ **Cross-Account Roles** (S3, IAM, KMS)
- ✅ **Security Lake** (OCSF data lake, automatic AWS log ingestion)
- ✅ **Glue Catalog** (database, crawler, metadata management)
- ✅ **Athena** (workgroup + 7 named queries + 4 views)
- ✅ **OpenSearch** (3-node cluster, KMS encryption, SNS role)
- ✅ **SNS Topics** (critical, high, medium severity)
- ✅ **SOC Alerting** (DLQ monitoring)
- ✅ **Config Drift Detection**

**Deployment Time:** 15-20 minutes | **Resources:** 85+

**Expected Output:**
```
Apply complete! Resources: 85+ added, 0 changed, 0 destroyed.

Outputs:

security_lake_bucket = "aws-security-data-lake-us-east-1-404068503087"
glue_database_name = "amazon_security_lake_glue_db_us_east_1"
glue_crawler_name = "security-lake-crawler"
athena_workgroup = "security-lake-queries"
opensearch_endpoint = "https://search-security-logs-xxxxx.us-east-1.es.amazonaws.com"
opensearch_dashboard_endpoint = "https://.../_dashboards"
opensearch_sns_role_arn = "arn:aws:iam::404068503087:role/OpenSearchSNSRole"
critical_topic_arn = "arn:aws:sns:us-east-1:404068503087:soc-alerts-critical"
high_topic_arn = "arn:aws:sns:us-east-1:404068503087:soc-alerts-high"
medium_topic_arn = "arn:aws:sns:us-east-1:404068503087:soc-alerts-medium"
```

### Step 4: Confirm SNS Email Subscriptions

Check your email (captain.gab@protonmail.com) for **3 confirmation emails** and click "Confirm subscription" in each.

```bash
# Verify subscriptions are confirmed
aws sns list-subscriptions | grep Confirmed
```

### Step 5: Access OpenSearch Dashboards

```bash
cd security-account/backend-bootstrap

# Get dashboard URL
terraform output opensearch_dashboard_endpoint

# Get admin password
aws secretsmanager get-secret-value \
  --secret-id opensearch-admin-password \
  --query SecretString \
  --output text
```

**Login:**
- URL: (from output above)
- Username: `admin`
- Password: (from command above)

### Step 6: Run Glue Crawler

```bash
# Start crawler to catalog Security Lake data
aws glue start-crawler --name security-lake-crawler

# Check crawler status (wait 5-10 minutes)
aws glue get-crawler --name security-lake-crawler --query 'Crawler.State'
```

### Step 7: Test Athena Queries

**Open Athena Console:**
- Workgroup: `security-lake-queries`
- Database: `amazon_security_lake_glue_db_us_east_1`

**Run test query:**
```sql
-- Show all tables created by Security Lake
SHOW TABLES IN amazon_security_lake_glue_db_us_east_1;

-- Query CloudTrail events from last 24 hours
SELECT
    time,
    metadata.product.name as source,
    activity_name,
    actor.user.name as user,
    cloud.region
FROM amazon_security_lake_glue_db_us_east_1.amazon_security_lake_table_us_east_1_cloud_trail_mgmt_2_0
WHERE time >= current_timestamp - interval '24' hour
LIMIT 10;
```

## 📊 Verification Checklist

### After Unified Deployment:
- [ ] All 85+ resources deployed: `cd backend-bootstrap && terraform state list | wc -l`
- [ ] Security Lake deployed successfully
- [ ] AWS log sources enabled (CloudTrail, VPC Flow, GuardDuty)
- [ ] OpenSearch domain healthy
- [ ] OpenSearch Dashboards accessible
- [ ] SNS topics created and subscriptions confirmed
- [ ] Glue Crawler completed successfully
- [ ] Tables visible in Athena
- [ ] Can run Athena queries

### Quick Verification Commands:
```bash
cd security-account/backend-bootstrap

# Verify deployment
terraform output

# Check Security Lake
aws securitylake list-data-lakes

# Check OpenSearch
aws opensearch describe-domain --domain-name security-logs

# Check SNS subscriptions
aws sns list-subscriptions | grep Confirmed

# Check Glue tables
aws glue get-tables --database-name amazon_security_lake_glue_db_us_east_1
```

## 🔍 Troubleshooting

### Security Lake Not Ingesting Data

**Check 1: Verify log sources are enabled**
```bash
aws securitylake list-log-sources
```

**Check 2: Verify S3 bucket has data**
```bash
aws s3 ls s3://aws-security-data-lake-us-east-1-404068503087/ext/ --recursive | head -20
```

**Fix:** Wait 1-2 hours for initial data ingestion

### Glue Crawler Failed

**Check crawler logs:**
```bash
aws glue get-crawler --name security-lake-crawler --query 'Crawler.LastCrawl'
```

**Common issues:**
- IAM permissions missing → Check glue.tf IAM role
- S3 bucket empty → Wait for Security Lake to ingest data
- KMS permissions → Add Glue role to KMS key policy

### OpenSearch Not Accessible

**Check 1: Verify domain is active**
```bash
aws opensearch describe-domain --domain-name security-logs --query 'DomainStatus.Processing'
```

**Check 2: Verify VPN/VPC connectivity**
- OpenSearch is deployed in private subnets
- Requires VPN or bastion host to access
- Alternative: Use AWS Systems Manager Session Manager

**Check 3: Security group rules**
```bash
aws ec2 describe-security-groups --group-ids <opensearch-sg-id>
```

### Athena Query Fails

**Error: "Table not found"**
- Solution: Run Glue Crawler first

**Error: "Insufficient permissions"**
- Solution: Check Athena workgroup IAM permissions

**Error: "Corrupted data"**
- Solution: Wait for Security Lake to complete initial ingestion

## 💰 Cost Estimate

**Monthly Costs (Estimated) for Complete Unified Deployment:**

| Service | Resource | Monthly Cost |
|---------|----------|--------------|
| Security Lake | 1TB data/month | $25 |
| Glue Crawler | 6 runs/day | $2 |
| Athena | 100GB scanned | $5 |
| OpenSearch | 3x r6g.xlarge | $750 |
| OpenSearch Storage | 600GB EBS (3x200GB) | $90 |
| SNS Topics | 3 topics + emails | $1 |
| Secrets Manager | Admin password | $0.40 |
| **Total** | | **~$873/month** |

**Cost Optimization Tips:**
1. Use OpenSearch warm storage for older data (-30%)
2. Reduce OpenSearch to 1 node for dev/test (-66%)
3. Set shorter retention in Security Lake
4. Optimize Athena queries (use partitions)
5. Consider smaller OpenSearch instance types for testing

## 📈 Next Steps

### **After Unified Deployment:**

1. **Configure OpenSearch Monitoring:**
   - [ ] Create SNS destinations in OpenSearch UI
   - [ ] Update monitor JSON files with destination IDs
   - [ ] Upload monitors: `cd soc-alerting/monitors && ./deploy-monitors.sh`
   - [ ] Test alert flow end-to-end

2. **Configure Log Ingestion:**
   - [ ] Enable VPC Flow Logs in workload account
   - [ ] Configure CloudTrail to send to Security Lake
   - [ ] Enable GuardDuty findings export

3. **Create OpenSearch Dashboards:**
   - [ ] Security Overview Dashboard
   - [ ] Network Traffic Dashboard
   - [ ] CloudTrail Audit Dashboard

4. **Set Up Alerting:**
   - [ ] High severity GuardDuty findings
   - [ ] Unusual API calls
   - [ ] Failed authentication attempts
   - [ ] Root account usage

5. **Configure Backup:**
   - [ ] Enable OpenSearch snapshots
   - [ ] Configure S3 replication for Security Lake

**See [UNIFIED-DEPLOYMENT-GUIDE.md](./UNIFIED-DEPLOYMENT-GUIDE.md) for detailed post-deployment steps.**

## 📞 Support

**Need Help?**

### **Documentation:**
- **[UNIFIED-DEPLOYMENT-GUIDE.md](./UNIFIED-DEPLOYMENT-GUIDE.md)** ⭐ Complete deployment guide with detailed steps
- **[QUICK-REFERENCE.md](./QUICK-REFERENCE.md)** ⭐ One-page command reference
- **[README.md](./README.md)** - Master documentation index
- **[IMPLEMENTATION-COMPLETE.md](./IMPLEMENTATION-COMPLETE.md)** - What's deployed and how it works
- **[soc-alerting/MONITOR-STATUS-SUMMARY.md](./soc-alerting/MONITOR-STATUS-SUMMARY.md)** - Monitor setup checklist
- **[OPENSEARCH-SNS-SETUP.md](./OPENSEARCH-SNS-SETUP.md)** - OpenSearch SNS integration guide

**Common Resources (After Unified Deployment):**
- Deployment Location: `security-account/backend-bootstrap/`
- Security Lake S3: `s3://aws-security-data-lake-us-east-1-404068503087/`
- Glue Database: `amazon_security_lake_glue_db_us_east_1`
- Athena Workgroup: `security-lake-queries`
- OpenSearch Domain: `security-logs`
- SNS Topics: `soc-alerts-critical`, `soc-alerts-high`, `soc-alerts-medium`

**Quick Commands:**
```bash
# Get all outputs
cd security-account/backend-bootstrap
terraform output

# Get OpenSearch password
aws secretsmanager get-secret-value --secret-id opensearch-admin-password --query SecretString --output text

# Check deployment status
terraform state list | wc -l  # Should show 85+ resources
```

---

**Last Updated:** January 13, 2026
**Version:** 3.0 (Unified Deployment)
**Status:** ✅ Production Ready
**Deployment Method:** Unified (single command from backend-bootstrap/)

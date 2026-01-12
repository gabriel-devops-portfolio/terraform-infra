# 🚀 Security Lake Deployment Guide

## Overview
This guide will walk you through deploying the complete Security Lake architecture with OpenSearch and Athena integration.

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

### Step 1: Deploy Security Lake (5 minutes)

```bash
cd security-account/security-lake

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy
terraform apply
```

**What this creates:**
- Security Lake data lake
- Automatic ingestion from CloudTrail, VPC Flow Logs, GuardDuty, Route53
- Glue Catalog database
- Glue Crawler (runs every 6 hours)
- Athena workgroup for queries

**Expected Output:**
```
Apply complete! Resources: 15 added, 0 changed, 0 destroyed.

Outputs:

security_lake_s3_bucket = "aws-security-data-lake-us-east-1-404068503087"
glue_database_name = "amazon_security_lake_glue_db_us_east_1"
```

### Step 2: Deploy OpenSearch (15 minutes)

**Update terraform.tfvars:**
```hcl
# security-account/opensearch/terraform.tfvars

vpc_id             = "vpc-xxxxxxxxx"  # Your VPC ID
vpc_cidr           = "10.0.0.0/16"    # Your VPC CIDR
private_subnet_ids = [
  "subnet-xxxxxxxxx",
  "subnet-yyyyyyyyy",
  "subnet-zzzzzzzzz"
]

opensearch_instance_type  = "r6g.xlarge.search"
opensearch_instance_count = 3
ebs_volume_size           = 200
```

```bash
cd ../opensearch

# Initialize Terraform
terraform init

# Review the plan
terraform plan -var-file=terraform.tfvars

# Deploy
terraform apply -var-file=terraform.tfvars
```

**Expected Time:** 15-20 minutes

**Expected Output:**
```
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:

opensearch_endpoint = "https://search-security-logs-xxxxx.us-east-1.es.amazonaws.com"
opensearch_dashboard_endpoint = "https://search-security-logs-xxxxx.us-east-1.es.amazonaws.com/_dashboards"
```

### Step 3: Get OpenSearch Credentials

```bash
# Get the admin password
aws secretsmanager get-secret-value \
  --secret-id opensearch-admin-password \
  --query SecretString \
  --output text

# Save this password securely!
```

### Step 4: Access OpenSearch Dashboards

1. **Get the dashboard URL:**
   ```bash
   terraform output opensearch_dashboard_endpoint
   ```

2. **Access via browser:**
   - URL: `https://<opensearch-endpoint>/_dashboards`
   - Username: `admin`
   - Password: (from Step 3)

3. **Create first index pattern:**
   - Go to Management → Stack Management → Index Patterns
   - Create pattern: `security-lake-*`
   - Time field: `time`

### Step 5: Run Glue Crawler Manually (First Time)

```bash
# Trigger the crawler to catalog existing data
aws glue start-crawler --name security-lake-crawler

# Check crawler status
aws glue get-crawler --name security-lake-crawler --query 'Crawler.State'
```

Wait for crawler to complete (5-10 minutes)

### Step 6: Test Athena Queries

1. **Open Athena Console:**
   ```bash
   # Get the workgroup name
   terraform output -raw glue_database_name
   ```

2. **Run test query:**
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

- [ ] Security Lake deployed successfully
- [ ] AWS log sources enabled (CloudTrail, VPC Flow, GuardDuty)
- [ ] Glue Crawler completed successfully
- [ ] Tables visible in Athena
- [ ] OpenSearch domain healthy
- [ ] OpenSearch Dashboards accessible
- [ ] Can run Athena queries

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

**Monthly Costs (Estimated):**

| Service | Resource | Monthly Cost |
|---------|----------|--------------|
| Security Lake | 1TB data/month | $25 |
| Glue Crawler | 6 runs/day | $2 |
| Athena | 100GB scanned | $5 |
| OpenSearch | 3x r6g.xlarge | $750 |
| OpenSearch Storage | 600GB EBS (3x200GB) | $90 |
| **Total** | | **~$872/month** |

**Cost Optimization Tips:**
1. Use OpenSearch warm storage for older data
2. Set shorter retention in Security Lake
3. Optimize Athena queries (use partitions)
4. Consider smaller OpenSearch instance types for testing

## 📈 Next Steps

1. **Configure Log Ingestion:**
   - [ ] Enable VPC Flow Logs in workload account
   - [ ] Configure CloudTrail to send to Security Lake
   - [ ] Enable GuardDuty findings export

2. **Create OpenSearch Dashboards:**
   - [ ] Security Overview Dashboard
   - [ ] Network Traffic Dashboard
   - [ ] CloudTrail Audit Dashboard

3. **Set Up Alerting:**
   - [ ] High severity GuardDuty findings
   - [ ] Unusual API calls
   - [ ] Failed authentication attempts

4. **Configure Backup:**
   - [ ] Enable OpenSearch snapshots
   - [ ] Configure S3 replication for Security Lake

## 📞 Support

**Need Help?**
- Check `SECURITY-LAKE-ARCHITECTURE.md` for detailed architecture
- Check `SECURITY-LAKE-QUICK-START.md` for quick reference
- Review AWS Security Lake documentation

**Common Resources:**
- Security Lake S3: `s3://aws-security-data-lake-us-east-1-404068503087/`
- Glue Database: `amazon_security_lake_glue_db_us_east_1`
- Athena Workgroup: `security-lake-queries`
- OpenSearch Domain: `security-logs`

---

**Last Updated:** January 12, 2026
**Version:** 1.0
**Status:** Ready for Production Deployment

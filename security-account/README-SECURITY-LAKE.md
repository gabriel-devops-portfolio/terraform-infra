# AWS Security Lake with OpenSearch and Athena

## ⚠️ **IMPORTANT: Deployment Method Updated**

**This document describes the legacy per-module deployment method.**

**✅ For current deployment, use the unified method:**
```bash
cd security-account/backend-bootstrap
terraform apply
```

**This single command deploys Security Lake, OpenSearch, Athena, SNS, and all security infrastructure.**

**See:** [UNIFIED-DEPLOYMENT-GUIDE.md](./UNIFIED-DEPLOYMENT-GUIDE.md) for complete instructions.

---

## Overview
Centralized security data lake that ingests all security logs from workload accounts and provides:
- **Real-time monitoring** with Amazon OpenSearch
- **SQL queries** with Amazon Athena
- **Standardized format** using OCSF (Open Cybersecurity Schema Framework)

## Architecture

```
Workload Account Logs → Security Lake → Glue Catalog
                                    ↓
                          ┌─────────┴──────────┐
                          ↓                    ↓
                    OpenSearch            Athena
                 (Real-time monitoring)  (SQL queries)
```

## What Gets Ingested

✅ **Automatically ingested by Security Lake:**
- CloudTrail Management Events
- VPC Flow Logs
- GuardDuty Findings (via Security Hub)
- Route 53 Resolver Query Logs

✅ **Available for custom ingestion:**
- CloudWatch Logs
- Application Logs
- WAF Logs
- Custom security data

## Modules

### `/security-lake/`
Core Security Lake configuration with:
- Security Lake data lake
- AWS log source integrations
- Glue Catalog database
- Glue Crawler for metadata
- Athena workgroup

### `/opensearch/`
Amazon OpenSearch cluster for:
- Real-time dashboards
- Security alerting
- Log visualization
- Anomaly detection

## Quick Start

### ✅ **New Unified Deployment Method (Use This!)**

**Step 1: Deploy All Security Infrastructure**

```bash
cd security-account/backend-bootstrap
terraform init
terraform apply
```

**This single command deploys:**
- ✅ Security Lake (OCSF data lake, Glue, Athena)
- ✅ OpenSearch (3-node cluster + SNS role)
- ✅ Athena Queries (7 queries + 4 views)
- ✅ SNS Topics (critical, high, medium)
- ✅ Cross-Account Roles
- ✅ Config Drift Detection

**Deployment Time:** 15-20 minutes | **Resources:** 85+

---

### 📝 **Legacy Per-Module Deployment (Deprecated)**

<details>
<summary>Click to expand old deployment method (not recommended)</summary>

**Old Step 1: Deploy Security Lake**

```bash
cd security-lake
terraform init
terraform apply
```

**Old Step 2: Deploy OpenSearch**

**Create `terraform.tfvars`:**
```hcl
vpc_id             = "vpc-xxxxx"
vpc_cidr           = "10.0.0.0/16"
private_subnet_ids = ["subnet-a", "subnet-b", "subnet-c"]
```

```bash
cd ../opensearch
terraform init
terraform apply -var-file=terraform.tfvars
```

**⚠️ This method is deprecated. Use unified deployment instead.**

</details>

---

### **Step 2: Post-Deployment Configuration**

**A. Confirm SNS Email Subscriptions**
```bash
# Check email (captain.gab@protonmail.com) and confirm 3 subscriptions
aws sns list-subscriptions | grep Confirmed
```

**B. Access OpenSearch Dashboards**

```bash
cd security-account/backend-bootstrap

# Get OpenSearch endpoint
terraform output opensearch_dashboard_endpoint

# Get admin password
aws secretsmanager get-secret-value \
  --secret-id opensearch-admin-password \
  --query SecretString \
  --output text
```

**C. Run Glue Crawler**
```bash
aws glue start-crawler --name security-lake-crawler
```

---

### **Step 3: Query with Athena**

```sql
-- Show all security tables
SHOW TABLES IN amazon_security_lake_glue_db_us_east_1;

-- Query CloudTrail events
SELECT time, activity_name, actor.user.name
FROM amazon_security_lake_glue_db_us_east_1.amazon_security_lake_table_us_east_1_cloud_trail_mgmt_2_0
WHERE time >= current_timestamp - interval '24' hour;
```

## Outputs

### From Backend-Bootstrap Unified Deployment

```bash
cd security-account/backend-bootstrap
terraform output
```

**Security Lake Outputs:**
```
security_lake_s3_bucket = "aws-security-data-lake-us-east-1-404068503087"
glue_database_name = "amazon_security_lake_glue_db_us_east_1"
glue_crawler_name = "security-lake-crawler"
athena_workgroup = "security-lake-queries"
```

**OpenSearch Outputs:**
```
opensearch_endpoint = "https://search-security-logs-xxx.us-east-1.es.amazonaws.com"
opensearch_dashboard_endpoint = "https://.../_dashboards"
opensearch_sns_role_arn = "arn:aws:iam::404068503087:role/OpenSearchSNSRole"
```

**SNS Outputs:**
```
critical_topic_arn = "arn:aws:sns:us-east-1:404068503087:soc-alerts-critical"
high_topic_arn = "arn:aws:sns:us-east-1:404068503087:soc-alerts-high"
medium_topic_arn = "arn:aws:sns:us-east-1:404068503087:soc-alerts-medium"
```

## Cost Estimate

| Component | Configuration | Monthly Cost |
|-----------|--------------|--------------|
| Security Lake (1TB) | Data storage + lifecycle | $25 |
| OpenSearch (3 nodes) | r6g.xlarge.search x3 | $750 |
| OpenSearch EBS | 200GB gp3 x3 | $90 |
| Athena (100GB queries) | Pay per query | $5 |
| SNS Topics | 3 topics + emails | $1 |
| Glue Crawler | 6 runs/day | $2 |
| Secrets Manager | Admin password | $0.40 |
| **Total** | | **~$873/month** |

**Cost Optimization Tips:**
- Reduce OpenSearch to 1 node for dev/test (-66%)
- Use OpenSearch warm storage for older data (-30%)
- Optimize Athena queries with partition pruning
- Adjust Security Lake retention (shorter = cheaper)

## Data Flow

1. **Workload Account** → Generates security logs
2. **Security Lake** → Ingests and stores in OCSF format
3. **Glue Crawler** → Catalogs metadata (runs every 6 hours)
4. **OpenSearch** → Real-time indexing for dashboards
5. **Athena** → SQL queries on historical data

## Common Queries

### Find High-Severity GuardDuty Findings
```sql
SELECT time, finding.title, severity
FROM amazon_security_lake_glue_db_us_east_1.amazon_security_lake_table_us_east_1_sh_findings_2_0
WHERE severity_id >= 4
  AND time >= current_timestamp - interval '7' day;
```

### Analyze VPC Flow Logs - Denied Connections
```sql
SELECT src_endpoint.ip, dst_endpoint.ip, dst_endpoint.port, COUNT(*) as count
FROM amazon_security_lake_glue_db_us_east_1.amazon_security_lake_table_us_east_1_vpc_flow_2_0
WHERE disposition_id = 2
  AND time >= current_timestamp - interval '1' hour
GROUP BY 1, 2, 3
ORDER BY count DESC;
```

### Track API Calls by User
```sql
SELECT actor.user.name, activity_name, COUNT(*) as call_count
FROM amazon_security_lake_glue_db_us_east_1.amazon_security_lake_table_us_east_1_cloud_trail_mgmt_2_0
WHERE time >= current_timestamp - interval '24' hour
GROUP BY 1, 2
ORDER BY call_count DESC;
```

## Troubleshooting

### No Data in Security Lake
- Wait 1-2 hours after deployment for initial ingestion
- Check: `aws s3 ls s3://aws-security-data-lake-us-east-1-404068503087/ext/`

### Glue Crawler Fails
- Verify IAM role permissions in `glue.tf`
- Check crawler logs: `aws glue get-crawler --name security-lake-crawler`

### OpenSearch Not Accessible
- Deployed in private subnets - requires VPN/bastion
- Check security group allows port 443 from VPC CIDR
- Verify domain is active: `aws opensearch describe-domain --domain-name security-logs`

## Next Steps

1. ✅ **Deploy everything:** `cd security-account/backend-bootstrap && terraform apply`
2. ✅ **Confirm SNS subscriptions** (check email for 3 confirmation links)
3. ✅ **Run Glue Crawler** to catalog Security Lake data
4. ⏳ **Create OpenSearch destinations** for alerting (manual UI step)
5. ⏳ **Upload OpenSearch monitors:** `cd soc-alerting/monitors && ./deploy-monitors.sh`
6. ⏳ **Configure workload account** VPC Flow Logs
7. ⏳ **Create OpenSearch dashboards** for visualization
8. ⏳ **Set up automated alerting** rules
9. ⏳ **Configure automated incident responses**

## Documentation

### **Primary Guides (Start Here)** ⭐
- **[UNIFIED-DEPLOYMENT-GUIDE.md](./UNIFIED-DEPLOYMENT-GUIDE.md)** - Complete step-by-step deployment guide
- **[QUICK-REFERENCE.md](./QUICK-REFERENCE.md)** - One-page command reference
- **[README.md](./README.md)** - Master documentation index

### **Detailed References**
- **[IMPLEMENTATION-COMPLETE.md](./IMPLEMENTATION-COMPLETE.md)** - What's deployed and how it works
- **[OPENSEARCH-SNS-SETUP.md](./OPENSEARCH-SNS-SETUP.md)** - OpenSearch SNS integration
- **[soc-alerting/MONITOR-STATUS-SUMMARY.md](./soc-alerting/MONITOR-STATUS-SUMMARY.md)** - Monitor deployment checklist

### **Legacy Documentation** (Deprecated)
- **SECURITY-LAKE-DEPLOYMENT.md** - Old per-module deployment guide
- **SECURITY-LAKE-ARCHITECTURE.md** - Detailed architecture and design
- **SECURITY-LAKE-QUICK-START.md** - Quick reference and code samples

---

**Status:** ✅ Ready for Production
**Deployment Method:** ✅ Unified (single command from backend-bootstrap/)
**Last Updated:** January 13, 2026

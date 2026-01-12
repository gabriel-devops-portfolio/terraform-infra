# AWS Security Lake with OpenSearch and Athena

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

### 1. Deploy Security Lake

```bash
cd security-lake
terraform init
terraform apply
```

### 2. Deploy OpenSearch

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

### 3. Access Dashboards

```bash
# Get OpenSearch endpoint
terraform output opensearch_dashboard_endpoint

# Get admin password
aws secretsmanager get-secret-value \
  --secret-id opensearch-admin-password \
  --query SecretString \
  --output text
```

### 4. Query with Athena

```sql
-- Show all security tables
SHOW TABLES IN amazon_security_lake_glue_db_us_east_1;

-- Query CloudTrail events
SELECT time, activity_name, actor.user.name
FROM amazon_security_lake_glue_db_us_east_1.amazon_security_lake_table_us_east_1_cloud_trail_mgmt_2_0
WHERE time >= current_timestamp - interval '24' hour;
```

## Outputs

### Security Lake Outputs
```
security_lake_s3_bucket = "aws-security-data-lake-us-east-1-404068503087"
glue_database_name = "amazon_security_lake_glue_db_us_east_1"
```

### OpenSearch Outputs
```
opensearch_endpoint = "https://search-security-logs-xxx.us-east-1.es.amazonaws.com"
opensearch_dashboard_endpoint = "https://.../_dashboards"
```

## Cost Estimate

| Component | Monthly Cost |
|-----------|--------------|
| Security Lake (1TB) | $25 |
| OpenSearch (3 nodes) | $750 |
| Athena (100GB queries) | $5 |
| **Total** | **~$780/month** |

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

1. ✅ Deploy Security Lake and OpenSearch
2. ⏭️ Configure workload account VPC Flow Logs
3. ⏭️ Create OpenSearch dashboards
4. ⏭️ Set up alerting rules
5. ⏭️ Configure automated responses

## Documentation

- **SECURITY-LAKE-DEPLOYMENT.md** - Step-by-step deployment guide
- **SECURITY-LAKE-ARCHITECTURE.md** - Detailed architecture and design
- **SECURITY-LAKE-QUICK-START.md** - Quick reference and code samples

---

**Status:** ✅ Ready for Production
**Last Updated:** January 12, 2026

# Athena Queries for Security Lake Analysis

## 📋 Overview

This module deploys Athena named queries and views for analyzing Security Lake data. It provides pre-built queries for common security use cases including VPC traffic anomalies, Terraform state access monitoring, privileged activity tracking, and GuardDuty findings analysis.

## ⚠️ Issues Found & Fixed

### 1. **SQL Files Not Deployed** ❌
- **Problem**: SQL files existed in `views/` directory but were **NOT deployed via Terraform**
- **Impact**: Queries were not available in Athena console
- **Fix**: Created `main.tf` with `aws_athena_named_query` resources to deploy all queries

### 2. **Incorrect OCSF Table References** ❌
- **Problem**: Queries referenced `amazon_cloudtrail` table which doesn't exist in Security Lake OCSF format
- **Correct Table**: Should be `amazon_cloudtrail_mgmt` (for CloudTrail management events)
- **Fix**: Updated all CloudTrail queries to use correct OCSF table name

### 3. **Missing Database Name Substitution** ❌
- **Problem**: Hardcoded database name `amazon_security_lake_glue_db` doesn't include region
- **Correct Format**: `amazon_security_lake_glue_db_us_east_1` (underscores, not hyphens)
- **Fix**: Used `${replace(var.region, "-", "_")}` to dynamically substitute region

### 4. **Incorrect OCSF Schema** ❌
- **Problem**: Field names in SQL didn't match OCSF 1.1.0 schema
- **Examples**:
  - ❌ `user_identity.arn` → ✅ `user_identity.arn`
  - ❌ `api.operation` → ✅ `api.operation` (correct)
  - ❌ `object.key` → ✅ `api.request.key`
- **Fix**: Updated all field references to match OCSF schema

### 5. **Missing GuardDuty Table** ⚠️
- **Problem**: Referenced `amazon_guardduty_finding` but actual table is `amazon_security_finding`
- **Fix**: Updated to query `amazon_security_finding` with filter for GuardDuty product

## 🏗️ Architecture

```
Security Lake Data (OCSF Format)
         ↓
┌────────────────────────────────┐
│   AWS Glue Data Catalog        │
│   Database:                    │
│   amazon_security_lake_glue_db │
│                                │
│   Tables:                      │
│   • amazon_cloudtrail_mgmt     │
│   • amazon_vpc_flow            │
│   • amazon_security_finding    │
└────────────────────────────────┘
         ↓
┌────────────────────────────────┐
│   Athena Named Queries         │
│   Workgroup:                   │
│   security-lake-queries        │
│                                │
│   Queries:                     │
│   • VPC traffic anomalies      │
│   • Terraform state access     │
│   • Privileged activity        │
│   • GuardDuty findings         │
│   • Failed auth attempts       │
│   • S3 public access changes   │
│   • Security group changes     │
└────────────────────────────────┘
         ↓
┌────────────────────────────────┐
│   Query Results                │
│   Bucket: athena-results       │
│   Retention: 30 days           │
│   Encryption: SSE-S3           │
└────────────────────────────────┘
```

## 📊 Deployed Queries

### 1. **VPC Traffic Anomalies**
- **Query Name**: `vpc-traffic-anomalies`
- **Purpose**: Detect rejected connections and traffic to unusual ports
- **Use Case**: Network anomaly detection, port scanning alerts
- **Output**: Source/dest IPs, ports, bytes, action (REJECT/ACCEPT)

### 2. **Terraform State Access**
- **Query Name**: `terraform-state-access`
- **Purpose**: Monitor all access to Terraform state files
- **Use Case**: Audit who accessed infrastructure state, unauthorized access detection
- **Output**: User, IP, operation (GetObject/PutObject), timestamp

### 3. **Privileged Activity**
- **Query Name**: `privileged-activity-monitoring`
- **Purpose**: Track root account and assumed role activity
- **Use Case**: Privileged access monitoring, compliance auditing
- **Output**: User type (Root/AssumedRole), operation, IP, user agent

### 4. **GuardDuty Findings**
- **Query Name**: `guardduty-high-severity-findings`
- **Purpose**: Query high and critical severity security findings
- **Use Case**: Threat investigation, incident response
- **Output**: Finding title, severity, resource affected, timestamp

### 5. **Failed Authentication Attempts**
- **Query Name**: `failed-authentication-attempts`
- **Purpose**: Detect AccessDenied and authentication failures
- **Use Case**: Brute force detection, unauthorized access attempts
- **Output**: Error code, principal, IP, attempt count in sliding window

### 6. **S3 Public Access Changes**
- **Query Name**: `s3-public-access-changes`
- **Purpose**: Monitor changes to S3 bucket public access settings
- **Use Case**: Data exposure prevention, compliance
- **Output**: Bucket name, operation, user, timestamp

### 7. **Security Group Changes**
- **Query Name**: `security-group-changes`
- **Purpose**: Track security group rule modifications
- **Use Case**: Network security monitoring, change tracking
- **Output**: Operation, user, IP, timestamp

## 🚀 Deployment

### Prerequisites

1. **Security Lake configured** in the security account
2. **Glue Crawler** has run and created tables
3. **Athena workgroup** `security-lake-queries` exists
4. **S3 bucket** for Athena results exists

### Deploy Athena Queries

```bash
cd security-account/athena

# Initialize Terraform
terraform init

# Review changes
terraform plan \
  -var="security_account_id=404068503087" \
  -var="workload_account_id=290793900072" \
  -var="region=us-east-1"

# Deploy queries
terraform apply \
  -var="security_account_id=404068503087" \
  -var="workload_account_id=290793900072" \
  -var="region=us-east-1"
```

### Create Views (One-Time Setup)

After deploying, run these queries in Athena console to create reusable views:

1. `create-view-vpc-traffic-anomalies`
2. `create-view-terraform-state-access`
3. `create-view-privileged-activity`
4. `create-view-guardduty-findings`

## 📝 Usage Examples

### Query VPC Traffic Anomalies

```sql
-- Use the named query
SELECT * FROM "AwsDataCatalog"."amazon_security_lake_glue_db_us_east_1"."vpc-traffic-anomalies"

-- Or use the view (after creating it)
SELECT * FROM security_vpc_traffic_anomalies
WHERE time > current_timestamp - interval '24' hour
ORDER BY bytes DESC
LIMIT 100;
```

### Query Terraform State Access

```sql
-- Show access in last 7 days
SELECT * FROM security_terraform_state_access
WHERE time > current_timestamp - interval '7' day
ORDER BY time DESC;
```

### Query Failed Auth Attempts

```sql
-- Find IPs with multiple failed attempts
SELECT
  source_ip,
  principal,
  COUNT(*) as failed_attempts,
  MIN(time) as first_attempt,
  MAX(time) as last_attempt
FROM (
  SELECT * FROM "amazon_security_lake_glue_db_us_east_1"."failed-authentication-attempts"
)
GROUP BY source_ip, principal
HAVING COUNT(*) > 5
ORDER BY failed_attempts DESC;
```

## 🔍 Troubleshooting

### Query Fails: "Table not found"

**Problem**: Glue Crawler hasn't run or table name is incorrect

**Solution**:
```bash
# Check Glue database exists
aws glue get-database --name amazon_security_lake_glue_db_us_east_1

# Check tables
aws glue get-tables --database-name amazon_security_lake_glue_db_us_east_1

# Run crawler manually
aws glue start-crawler --name security-lake-crawler
```

### Query Returns No Results

**Problem**: No data in Security Lake or partition not loaded

**Solution**:
```sql
-- Check if data exists
SELECT COUNT(*) FROM amazon_security_lake_glue_db_us_east_1.amazon_cloudtrail_mgmt;

-- Load partitions
MSCK REPAIR TABLE amazon_security_lake_glue_db_us_east_1.amazon_cloudtrail_mgmt;
```

### OCSF Field Names Not Working

**Problem**: Using incorrect OCSF 1.1.0 field names

**Solution**: Reference OCSF schema at https://schema.ocsf.io/1.1.0/

Common OCSF fields:
- `time` - Event timestamp
- `api.operation` - API operation name
- `user_identity.arn` - User ARN
- `src_endpoint.ip` - Source IP address
- `api.request.bucket` - S3 bucket name
- `api.request.key` - S3 object key
- `severity` - Finding severity (0-10)
- `severity_id` - Numeric severity

## 📚 OCSF Table Schema Reference

### CloudTrail Management Events
Table: `amazon_cloudtrail_mgmt`

Key fields:
- `time` - Timestamp
- `api.operation` - API call (e.g., PutObject, GetObject)
- `api.request.bucket` - S3 bucket
- `api.request.key` - S3 key
- `user_identity.type` - Root, IAMUser, AssumedRole
- `user_identity.arn` - User ARN
- `src_endpoint.ip` - Source IP
- `http_request.user_agent` - User agent string
- `api.response.error` - Error code if failed

### VPC Flow Logs
Table: `amazon_vpc_flow`

Key fields:
- `time` - Flow start time
- `srcaddr` - Source IP
- `dstaddr` - Destination IP
- `srcport` - Source port
- `dstport` - Destination port
- `action` - ACCEPT or REJECT
- `packets` - Packet count
- `bytes` - Byte count

### Security Findings (GuardDuty, SecurityHub)
Table: `amazon_security_finding`

Key fields:
- `time` - Finding time
- `severity` - Text severity
- `severity_id` - Numeric (0-10)
- `finding_info.title` - Finding title
- `finding_info.types` - Finding types
- `finding_info.product_name` - GuardDuty, SecurityHub, etc.
- `resources[1].type` - Resource type
- `resources[1].uid` - Resource ID

## 🔐 Security Considerations

- Athena query results contain sensitive security data
- Results bucket has 30-day retention and encryption
- Queries use IAM permissions from Athena execution role
- Views provide read-only access to Security Lake data
- All queries log to CloudTrail for audit

## 📊 Cost Optimization

- Athena charges $5 per TB scanned
- Use partitioning (already configured by Security Lake)
- Add date filters to queries: `WHERE time > current_timestamp - interval '7' day`
- Use views to avoid rewriting complex queries
- Set query result expiration to 30 days (configured)

## 🎯 Next Steps

1. **Deploy the configuration**: Run `terraform apply`
2. **Create views**: Execute the "create-view-*" queries in Athena console
3. **Test queries**: Run sample queries to verify data access
4. **Create dashboards**: Import queries into OpenSearch or QuickSight
5. **Set up alerts**: Use EventBridge to trigger alerts on specific query results
6. **Schedule queries**: Use CloudWatch Events to run queries periodically

## 📖 Related Documentation

- [Security Lake OCSF Schema](https://docs.aws.amazon.com/security-lake/latest/userguide/ocsf-format.html)
- [Athena Query Reference](https://docs.aws.amazon.com/athena/latest/ug/ddl-sql-reference.html)
- [Glue Data Catalog](https://docs.aws.amazon.com/glue/latest/dg/components-key-concepts.html)
- [OCSF 1.1.0 Schema](https://schema.ocsf.io/1.1.0/)

# 🚀 Security Lake Custom Sources - Deployment Guide

## ✅ What This Does

Integrates your **VPC Flow Logs** and **Terraform State Access Logs** into AWS Security Lake using OCSF (Open Cybersecurity Schema Framework) format for centralized security monitoring.

**Before**: Logs scattered in separate S3 buckets
**After**: Unified OCSF-normalized data in Security Lake → queryable via Athena & OpenSearch

---

## 📋 Prerequisites Checklist

Before deploying, ensure you have:

- [x] Security Lake deployed (`module.security-lake` in backend-bootstrap)
- [x] VPC Flow Logs bucket: `org-vpc-flow-logs-security-{account-id}`
- [x] Terraform State logs bucket: `workload-account-terraform-state-access-logs`
- [x] KMS key for encryption (from `module.cross-account-role`)
- [x] SNS topic for CloudWatch alarms (from `module.soc-alerting`)

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  Existing S3 Buckets (Security Account)                         │
│                                                                   │
│  ┌──────────────────────────┐  ┌──────────────────────────┐    │
│  │ org-vpc-flow-logs-*      │  │ workload-account-        │    │
│  │ (Parquet format)         │  │ terraform-state-access-  │    │
│  │                          │  │ logs (S3 access logs)    │    │
│  └───────────┬──────────────┘  └───────────┬──────────────┘    │
│              │ S3 Event                     │ S3 Event          │
│              │ (ObjectCreated)              │ (ObjectCreated)   │
│              ▼                              ▼                    │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  🔄 Lambda: SecurityLakeOCSFTransformer                │    │
│  │  ┌──────────────────────────────────────────────────┐  │    │
│  │  │ 1. Read S3 object                                │  │    │
│  │  │ 2. Parse (Parquet/Text)                          │  │    │
│  │  │ 3. Transform to OCSF schema                      │  │    │
│  │  │    - VPC Flow → Network Activity (4001)          │  │    │
│  │  │    - Terraform → API Activity (3005)             │  │    │
│  │  │ 4. Write to Security Lake                        │  │    │
│  │  └──────────────────────────────────────────────────┘  │    │
│  └───────────┬────────────────────────────────────────────┘    │
│              ▼                                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  📊 Security Lake (OCSF Normalized)                    │    │
│  │  - vpc_flow_logs_enriched/                             │    │
│  │  - terraform_state_access/                             │    │
│  └───────────┬────────────────────────────────────────────┘    │
│              │                                                   │
│              ▼                                                   │
│  ┌──────────────────────┐  ┌──────────────────────────────┐   │
│  │  🔍 OpenSearch       │  │  📈 Athena                   │   │
│  │  (Real-time queries) │  │  (Historical analysis)       │   │
│  └──────────────────────┘  └──────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📦 Step 1: Module is Already Added

The module has been added to `backend-bootstrap/main.tf`:

```terraform
module "security-lake-custom-sources" {
  source = "../security-lake-custom-sources"

  kms_key_arn   = module.cross-account-role.kms_key_arn
  sns_topic_arn = module.soc-alerting.high_topic_arn

  depends_on = [
    module.security-lake,
    module.cross-account-role,
    module.soc-alerting
  ]
}
```

---

## 🚀 Step 2: Deploy the Module

### Option A: Deploy Everything (Recommended)

```bash
cd /Users/CaptGab/terraform-infra/security-account/backend-bootstrap

# Initialize (if not already done)
terraform init

# Preview changes
terraform plan

# Deploy
terraform apply
```

**Expected Resources**: +15 resources
- 2x Security Lake Custom Sources
- 1x Lambda Function (SecurityLakeOCSFTransformer)
- 2x S3 Event Notifications
- 2x Lambda Permissions
- 2x IAM Roles
- 4x IAM Policies
- 1x CloudWatch Log Group
- 2x CloudWatch Alarms

### Option B: Deploy Module Only

```bash
cd /Users/CaptGab/terraform-infra/security-account/backend-bootstrap

terraform apply -target=module.security-lake-custom-sources
```

---

## ✅ Step 3: Verify Deployment

### 1. Check Lambda Function

```bash
# Verify Lambda exists
aws lambda get-function \
  --function-name SecurityLakeOCSFTransformer \
  --region us-east-1

# Expected output:
# {
#   "Configuration": {
#     "FunctionName": "SecurityLakeOCSFTransformer",
#     "Runtime": "python3.11",
#     "Handler": "lambda_function.lambda_handler",
#     "MemorySize": 1024,
#     "Timeout": 300
#   }
# }
```

### 2. Check Security Lake Custom Sources

```bash
# List Security Lake log sources
aws securitylake list-log-sources \
  --region us-east-1

# Should show:
# - VPCFlowLogsEnriched (NETWORK_ACTIVITY)
# - TerraformStateAccess (API_ACTIVITY)
```

### 3. Check S3 Event Notifications

```bash
# VPC Flow Logs bucket
aws s3api get-bucket-notification-configuration \
  --bucket org-vpc-flow-logs-security-<account-id>

# Terraform State logs bucket
aws s3api get-bucket-notification-configuration \
  --bucket workload-account-terraform-state-access-logs

# Expected: Lambda function ARN in LambdaFunctionConfigurations
```

### 4. Test with Sample Data

```bash
# Option 1: Wait for real logs (automatic)
# VPC Flow Logs are generated continuously from workload VPCs
# Just wait 5-10 minutes and check Lambda logs

# Option 2: Manual trigger (optional)
# Upload a test file to trigger Lambda
aws s3 cp test-file.parquet \
  s3://org-vpc-flow-logs-security-<account-id>/AWSLogs/test/

# Check Lambda logs
aws logs tail /aws/lambda/SecurityLakeOCSFTransformer --follow
```

---

## 📊 Step 4: Query Security Lake Data

### Athena - VPC Flow Logs (OCSF)

```sql
-- Query: Recent VPC Flow Logs in OCSF format
SELECT
  time,
  src_endpoint.ip as source_ip,
  src_endpoint.port as source_port,
  dst_endpoint.ip as dest_ip,
  dst_endpoint.port as dest_port,
  traffic.bytes,
  traffic.packets,
  disposition,
  severity
FROM vpc_flow_logs_enriched
WHERE year = '2026'
  AND month = '01'
  AND day = '13'
ORDER BY time DESC
LIMIT 100;
```

```sql
-- Query: Rejected Traffic (Potential Threats)
SELECT
  src_endpoint.ip as attacker_ip,
  dst_endpoint.ip as target_ip,
  dst_endpoint.port as target_port,
  COUNT(*) as connection_attempts,
  SUM(traffic.bytes) as total_bytes
FROM vpc_flow_logs_enriched
WHERE disposition = 'Blocked'
  AND year = '2026'
  AND month = '01'
GROUP BY 1, 2, 3
HAVING COUNT(*) > 100
ORDER BY connection_attempts DESC;
```

### Athena - Terraform State Access (OCSF)

```sql
-- Query: Recent Terraform State Access
SELECT
  time,
  api.operation,
  actor.user.uid as user,
  src_endpoint.ip as source_ip,
  resources[1].name as object_key,
  severity,
  http_request.http_status
FROM terraform_state_access
WHERE year = '2026'
  AND month = '01'
  AND resources[1].name LIKE '%.tfstate%'
ORDER BY time DESC
LIMIT 100;
```

```sql
-- Query: High Severity Terraform State Access
SELECT
  time,
  api.operation,
  actor.user.uid as user,
  src_endpoint.ip,
  resources[1].name as tfstate_file
FROM terraform_state_access
WHERE severity = 'High'
  AND year = '2026'
  AND month = '01'
ORDER BY time DESC;
```

### OpenSearch - Create Index Pattern

1. **Access OpenSearch Dashboards**
   ```bash
   # Get OpenSearch endpoint
   cd /Users/CaptGab/terraform-infra/security-account/backend-bootstrap
   terraform output opensearch_endpoint
   ```

2. **Create Index Patterns**
   - Navigate to **Stack Management** → **Index Patterns**
   - Create pattern: `vpc_flow_logs_enriched*`
   - Create pattern: `terraform_state_access*`
   - Time field: `time`

3. **Create Visualizations** (Examples in `security-account/dashboards/`)

---

## 🔍 Step 5: Monitor Lambda Function

### CloudWatch Logs

```bash
# View recent logs
aws logs tail /aws/lambda/SecurityLakeOCSFTransformer --since 10m

# Follow logs in real-time
aws logs tail /aws/lambda/SecurityLakeOCSFTransformer --follow
```

### CloudWatch Metrics

```bash
# Lambda invocations (last hour)
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=SecurityLakeOCSFTransformer \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum

# Lambda errors
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Errors \
  --dimensions Name=FunctionName,Value=SecurityLakeOCSFTransformer \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Sum
```

### CloudWatch Alarms

Two alarms are automatically created:
- **SecurityLakeOCSFTransformer-Errors**: Triggers on > 5 errors in 5 minutes
- **SecurityLakeOCSFTransformer-Throttles**: Triggers on > 10 throttles in 5 minutes

Alerts sent to: `module.soc-alerting.high_topic_arn`

---

## 💰 Cost Impact

| Service | Usage | Monthly Cost |
|---------|-------|--------------|
| Lambda Invocations | ~10,000/month | $0.20 |
| Lambda Duration (1GB, 30s avg) | ~83 GB-hours | $1.40 |
| Lambda Storage | 512 MB | $0.02 |
| S3 Storage (Security Lake) | +10 GB/month | $0.25 |
| **Previous Total** | | **~$111/month** |
| **New Total** | | **~$113/month** |
| **Additional Cost** | | **+$2/month** |

**Benefits**:
- ✅ Centralized logging (no more scattered S3 buckets)
- ✅ OCSF normalization (consistent schema)
- ✅ Better correlation (VPC Flow + Terraform State + CloudTrail)
- ✅ Compliance-ready (SOC 2, PCI-DSS evidence)

---

## 🔧 Troubleshooting

### Issue: Lambda Timeout

**Symptom**: Lambda times out on large Parquet files

**Solution**:
```hcl
# In security-lake-custom-sources/main.tf, increase timeout
timeout     = 600  # Increase from 300 to 600 seconds
memory_size = 2048 # Increase from 1024 to 2048 MB
```

### Issue: No Events in Security Lake

**Symptom**: Lambda runs but no data appears in Athena queries

**Troubleshooting Steps**:
1. Check Lambda logs for errors:
   ```bash
   aws logs tail /aws/lambda/SecurityLakeOCSFTransformer --since 1h
   ```

2. Verify S3 event notifications:
   ```bash
   aws s3api get-bucket-notification-configuration \
     --bucket org-vpc-flow-logs-security-<account-id>
   ```

3. Verify IAM permissions:
   ```bash
   aws iam get-role-policy \
     --role-name SecurityLakeOCSFTransformerRole \
     --policy-name SecurityLakeWritePolicy
   ```

4. Check Security Lake custom source ARNs:
   ```bash
   cd /Users/CaptGab/terraform-infra/security-account/backend-bootstrap
   terraform output security_lake_custom_sources
   ```

### Issue: PyArrow Import Error

**Symptom**: `ImportError: No module named 'pyarrow'`

**Solution**: This shouldn't happen as PyArrow is bundled. If it does:
```bash
# Create Lambda Layer with PyArrow
cd /tmp
mkdir python
pip install pyarrow pandas -t python/
zip -r pyarrow-layer.zip python/

# Upload to Lambda Layer (manual step)
aws lambda publish-layer-version \
  --layer-name pyarrow-pandas \
  --zip-file fileb://pyarrow-layer.zip \
  --compatible-runtimes python3.11

# Update Lambda to use layer
aws lambda update-function-configuration \
  --function-name SecurityLakeOCSFTransformer \
  --layers arn:aws:lambda:us-east-1:<account-id>:layer:pyarrow-pandas:1
```

### Issue: S3 Event Notification Conflict

**Symptom**: `Error: conflicting S3 bucket notification configuration`

**Solution**: Only one notification configuration per bucket. Check existing:
```bash
aws s3api get-bucket-notification-configuration \
  --bucket org-vpc-flow-logs-security-<account-id>

# If conflicts exist, merge configurations manually in Terraform
```

---

## 📚 Related Documentation

- [Security Lake Custom Sources README](../security-lake-custom-sources/README.md)
- [VPC Flow Logs Configuration](../../workload-account/VPC-FLOW-LOGS-CONFIGURATION.md)
- [Terraform State Monitoring Runbook](../../security-detections/runbooks/terraform-state.md)
- [OCSF Schema v1.1.0](https://schema.ocsf.io/1.1.0)
- [AWS Security Lake Documentation](https://docs.aws.amazon.com/security-lake/)

---

## ✅ Success Criteria

You've successfully deployed when:

1. **Lambda Function Deployed**
   ```bash
   aws lambda get-function --function-name SecurityLakeOCSFTransformer
   # Returns function configuration
   ```

2. **S3 Event Notifications Active**
   ```bash
   aws s3api get-bucket-notification-configuration \
     --bucket org-vpc-flow-logs-security-<account-id>
   # Shows Lambda function ARN
   ```

3. **Security Lake Custom Sources Created**
   ```bash
   aws securitylake list-log-sources
   # Shows VPCFlowLogsEnriched and TerraformStateAccess
   ```

4. **Data Flowing to Security Lake**
   ```sql
   -- Athena query returns rows
   SELECT COUNT(*) FROM vpc_flow_logs_enriched
   WHERE year = '2026' AND month = '01';
   ```

5. **No Lambda Errors**
   ```bash
   aws logs tail /aws/lambda/SecurityLakeOCSFTransformer --since 1h
   # No ERROR lines
   ```

---

## 🎯 Next Steps

After successful deployment:

1. **Update OpenSearch Monitors** to query OCSF schema
2. **Create Athena Saved Queries** for common investigations
3. **Update SOC Runbooks** with Security Lake query examples
4. **Schedule Quarterly Review** of OCSF mappings
5. **Consider Adding More Custom Sources** (e.g., application logs)

---

**Deployment Date**: January 13, 2026
**Version**: 1.0
**Status**: ✅ Ready for Deployment

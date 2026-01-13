# Security Lake Custom Sources Integration

## Overview

This module integrates custom log sources with AWS Security Lake by transforming VPC Flow Logs and Terraform State Access Logs into OCSF (Open Cybersecurity Schema Framework) format.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  S3 Buckets (Security Account)                                  │
│                                                                   │
│  ┌──────────────────────────┐  ┌──────────────────────────┐    │
│  │ org-vpc-flow-logs-*      │  │ workload-account-        │    │
│  │ (Parquet/JSON)           │  │ terraform-state-access-  │    │
│  │                          │  │ logs                     │    │
│  └───────────┬──────────────┘  └───────────┬──────────────┘    │
│              │                              │                    │
│              │ S3 Event                     │ S3 Event          │
│              │ (ObjectCreated)              │ (ObjectCreated)   │
│              │                              │                    │
│              ▼                              ▼                    │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Lambda: SecurityLakeOCSFTransformer                   │    │
│  │  ┌──────────────────────────────────────────────────┐  │    │
│  │  │ 1. Download S3 object                            │  │    │
│  │  │ 2. Parse (Parquet/JSON/Text)                     │  │    │
│  │  │ 3. Transform to OCSF schema                      │  │    │
│  │  │ 4. Add metadata (severity, classification)       │  │    │
│  │  │ 5. Write to Security Lake S3                     │  │    │
│  │  └──────────────────────────────────────────────────┘  │    │
│  └───────────┬────────────────────────────────────────────┘    │
│              │                                                   │
│              │ OCSF-formatted JSON                              │
│              ▼                                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Security Lake Custom Sources                          │    │
│  │  - VPCFlowLogsEnriched (class 4001: Network Activity)  │    │
│  │  - TerraformStateAccess (class 3005: API Activity)     │    │
│  └───────────┬────────────────────────────────────────────┘    │
│              │                                                   │
│              ▼                                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  aws-security-data-lake-{region}-{account-id}          │    │
│  │  (OCSF Normalized Data)                                │    │
│  └───────────┬────────────────────────────────────────────┘    │
│              │                                                   │
│              │ Glue Catalog                                     │
│              ▼                                                   │
│  ┌──────────────────────┐  ┌──────────────────────────────┐   │
│  │  OpenSearch          │  │  Athena                      │   │
│  │  (Query OCSF)        │  │  (Query OCSF)                │   │
│  └──────────────────────┘  └──────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Features

### ✅ VPC Flow Logs Integration
- **Input Format**: Parquet (preferred) or JSON
- **OCSF Class**: 4001 (Network Activity)
- **Key Fields**:
  - Source/Destination IP and Port
  - Protocol (TCP/UDP/ICMP)
  - Bytes and Packets
  - Accept/Reject disposition
  - VPC, Subnet, ENI metadata
- **Severity**:
  - Informational: Accepted traffic
  - Medium: Rejected traffic (potential scanning/attacks)

### ✅ Terraform State Access Logs Integration
- **Input Format**: S3 Access Logs (text)
- **OCSF Class**: 3005 (API Activity)
- **Key Fields**:
  - API operation (GetObject, PutObject, etc.)
  - User identity (IAM principal)
  - Source IP address
  - HTTP status code
  - Object key (.tfstate files)
- **Severity**:
  - High: GetObject on .tfstate files
  - Medium: Other operations

## OCSF Schema Compliance

### Network Activity (Class 4001)
```json
{
  "class_uid": 4001,
  "category_uid": 4,
  "severity_id": 1-5,
  "src_endpoint": {"ip": "...", "port": 443},
  "dst_endpoint": {"ip": "...", "port": 80},
  "traffic": {"bytes": 1024, "packets": 10},
  "disposition_id": 1,  // 1=Allowed, 2=Blocked
  "cloud": {"provider": "AWS", "account": {...}}
}
```

### API Activity (Class 3005)
```json
{
  "class_uid": 3005,
  "category_uid": 3,
  "severity_id": 3,  // High for .tfstate access
  "api": {"operation": "GetObject", "service": {...}},
  "actor": {"user": {"uid": "...", "type": "IAMUser"}},
  "resources": [{"type": "s3-object", "uid": "..."}],
  "cloud": {"provider": "AWS"}
}
```

## Deployment

### Prerequisites
1. Security Lake must be deployed
2. VPC Flow Logs bucket exists: `org-vpc-flow-logs-security-{account-id}`
3. Terraform State logs bucket exists: `workload-account-terraform-state-access-logs`
4. KMS key for encryption
5. SNS topic for CloudWatch alarms

### Add to backend-bootstrap/main.tf

```terraform
############################################
# Security Lake Custom Sources Module
############################################
module "security-lake-custom-sources" {
  source = "../security-lake-custom-sources"

  kms_key_arn    = module.cross-account-role.kms_key_arn
  sns_topic_arn  = module.soc-alerting.security_alerts_high_topic_arn

  depends_on = [
    module.security-lake,
    module.cross-account-role
  ]
}
```

### Deploy

```bash
cd security-account/backend-bootstrap
terraform init
terraform plan
terraform apply
```

## Verification

### 1. Check Lambda Function

```bash
aws lambda get-function --function-name SecurityLakeOCSFTransformer
```

### 2. Check Custom Sources

```bash
aws securitylake list-log-sources
```

### 3. Trigger Test Event

```bash
# Upload a test VPC Flow Log
aws s3 cp test-vpc-flow.parquet s3://org-vpc-flow-logs-security-{account-id}/AWSLogs/test/

# Check Lambda logs
aws logs tail /aws/lambda/SecurityLakeOCSFTransformer --follow
```

### 4. Query Security Lake Data

```sql
-- Athena query for VPC Flow Logs
SELECT
  time,
  src_endpoint.ip as source_ip,
  dst_endpoint.ip as dest_ip,
  traffic.bytes,
  disposition
FROM vpc_flow_logs_enriched
WHERE time > current_timestamp - interval '1' hour
ORDER BY time DESC
LIMIT 100;

-- Athena query for Terraform State Access
SELECT
  time,
  api.operation,
  actor.user.uid as user,
  src_endpoint.ip as source_ip,
  resources[1].name as object_key,
  severity
FROM terraform_state_access
WHERE time > current_timestamp - interval '1' hour
  AND resources[1].name LIKE '%.tfstate%'
ORDER BY time DESC;
```

## Monitoring

### CloudWatch Alarms
- **Lambda Errors**: Triggers when > 5 errors in 5 minutes
- **Lambda Throttles**: Triggers when > 10 throttles in 5 minutes

### CloudWatch Logs
- Log Group: `/aws/lambda/SecurityLakeOCSFTransformer`
- Retention: 30 days

### Metrics
```bash
# Lambda invocations
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=SecurityLakeOCSFTransformer \
  --start-time 2026-01-13T00:00:00Z \
  --end-time 2026-01-13T23:59:59Z \
  --period 3600 \
  --statistics Sum
```

## Cost Estimate

| Service | Usage | Monthly Cost |
|---------|-------|--------------|
| Lambda Invocations | ~10,000/month | $0.20 |
| Lambda Duration (1GB, 30s avg) | ~83 GB-hours | $1.40 |
| Lambda Storage (512 MB package) | 512 MB | $0.02 |
| S3 Storage (Security Lake) | +10 GB/month | $0.25 |
| **Total** | | **~$2/month** |

## Troubleshooting

### Lambda Timeout
- **Issue**: Lambda times out on large Parquet files
- **Solution**: Increase timeout or memory (currently 300s, 1024MB)

### PyArrow Import Error
- **Issue**: `ImportError: No module named 'pyarrow'`
- **Solution**: Ensure Lambda layer includes PyArrow (included in deployment)

### No Events in Security Lake
- **Issue**: Lambda runs but no data appears in Security Lake
- **Solution**:
  1. Check Lambda logs for errors
  2. Verify custom source ARNs are correct
  3. Check IAM permissions for Security Lake write access
  4. Verify S3 bucket names match environment variables

### S3 Event Notification Conflicts
- **Issue**: `Error: conflicting S3 bucket notification configuration`
- **Solution**: Only one notification configuration per bucket - merge configurations

## Related Documentation

- [Security Lake Main Configuration](../security-lake/README.md)
- [VPC Flow Logs Configuration](../../workload-account/VPC-FLOW-LOGS-CONFIGURATION.md)
- [Terraform State Monitoring](../../security-detections/runbooks/terraform-state.md)
- [OCSF Schema Documentation](https://schema.ocsf.io/)

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-01-13 | Initial release with VPC Flow and Terraform State support |

## Security Considerations

✅ **Encryption**: All data encrypted at rest (KMS) and in transit (TLS)
✅ **Least Privilege**: Lambda has minimal IAM permissions
✅ **Audit Trail**: All transformations logged to CloudWatch
✅ **Data Validation**: OCSF schema validation before ingestion
✅ **No Data Duplication**: Original logs remain in source buckets

## Future Enhancements

- [ ] Support for CloudTrail events (already in Security Lake natively)
- [ ] Custom detection rules in Lambda (pre-Security Lake)
- [ ] Real-time enrichment (IP geolocation, threat intel)
- [ ] Parquet optimization for large files (chunked processing)
- [ ] Lambda Layer for PyArrow (reduce package size)

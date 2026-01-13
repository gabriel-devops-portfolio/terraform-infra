# ⚠️ IMPORTANT: VPC Flow Logs Configuration

## Lambda Function Expects JSON Format

The Lambda function `SecurityLakeOCSFTransformer` has been simplified to **only process JSON format** logs (no PyArrow/Parquet dependency).

### ✅ VPC Flow Logs Configuration Required

Your VPC Flow Logs **MUST** be configured to output in **JSON format** instead of Parquet.

#### Update VPC Flow Logs Configuration

In your **workload account** VPC module configuration, ensure VPC Flow Logs are set to JSON format:

```hcl
# workload-account/modules/networking/main.tf (or wherever VPC is configured)

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  # VPC Flow Logs Configuration
  enable_flow_log                           = true
  flow_log_destination_type                 = "s3"
  flow_log_destination_arn                  = var.security_account_vpc_flow_logs_bucket_arn
  flow_log_max_aggregation_interval         = 60
  flow_log_per_hour_partition               = true

  # 🔴 CRITICAL: Set format to JSON (not Parquet)
  flow_log_file_format                      = "json"  # NOT "parquet"

  # Optional but recommended
  flow_log_hive_compatible_partitions       = true
}
```

### Alternative: Convert Parquet to JSON

If you want to keep Parquet format for storage efficiency, you have two options:

#### Option 1: AWS Glue ETL Job
Create a Glue job to convert Parquet → JSON before sending to Lambda:

```
VPC Flow (Parquet) → S3 → Glue ETL Job → JSON → S3 → Lambda → Security Lake
```

#### Option 2: Add PyArrow Lambda Layer (Complex)
Add a Lambda Layer with PyArrow pre-compiled (~100MB):
- More complex deployment
- Larger Lambda package
- Slower cold starts

### Current Configuration

**Lambda expects**: JSON files (`.json`)
**S3 Event filter**: `filter_suffix = ".json"`

**If you send Parquet files**, Lambda will:
- ❌ Fail to parse
- ❌ Log errors in CloudWatch
- ❌ Not send data to Security Lake

### Verification

After updating VPC Flow Logs to JSON format:

1. **Wait 5-10 minutes** for new flow logs to generate
2. **Check S3 bucket** for `.json` files:
   ```bash
   aws s3 ls s3://org-vpc-flow-logs-security-<account-id>/AWSLogs/ --recursive | grep json
   ```

3. **Monitor Lambda logs**:
   ```bash
   aws logs tail /aws/lambda/SecurityLakeOCSFTransformer --follow
   ```

4. **Query Security Lake**:
   ```sql
   SELECT COUNT(*) FROM vpc_flow_logs_enriched
   WHERE year = '2026' AND month = '01';
   ```

---

## Summary

✅ **Action Required**: Update VPC Flow Logs to output JSON format
✅ **Lambda supports**: JSON (array or newline-delimited)
✅ **No external dependencies**: Pure Python stdlib + boto3
✅ **Fast deployment**: No Lambda Layers needed

**File to update**: `workload-account/modules/networking/main.tf` (or VPC module)
**Change**: `flow_log_file_format = "json"`

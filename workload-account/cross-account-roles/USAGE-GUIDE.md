# Cross-Account Logging Configuration Guide

This guide explains how to configure services in the **workload account** to send logs and data to the centralized logging buckets in the **security account**.

## 📋 Prerequisites

- ✅ Security account S3 buckets created
- ✅ Workload account IAM roles created
- ✅ Proper bucket policies in security account

---

## 1. 🛤️ CloudTrail Configuration

### Create Organization Trail (in Security Account)
```bash
aws cloudtrail create-trail \
  --name org-cloudtrail \
  --s3-bucket-name org-cloudtrail-logs-security-404068503087 \
  --is-multi-region-trail \
  --is-organization-trail \
  --enable-log-file-validation
```

### Start Logging
```bash
aws cloudtrail start-logging --name org-cloudtrail
```

**Note**: Organization trails automatically collect logs from all member accounts.

---

## 2. 🌊 VPC Flow Logs Configuration

### Enable VPC Flow Logs to S3

```hcl
resource "aws_flow_log" "vpc_to_s3" {
  log_destination_type = "s3"
  log_destination      = "arn:aws:s3:::org-vpc-flow-logs-security-404068503087"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id

  destination_options {
    file_format        = "parquet"
    per_hour_partition = true
  }

  tags = {
    Name = "vpc-flow-logs-to-security"
  }
}
```

### Enable VPC Flow Logs to CloudWatch (Optional)

```hcl
resource "aws_flow_log" "vpc_to_cloudwatch" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 7
}
```

---

## 3. 📊 CloudWatch Logs Cross-Account Streaming

### Method 1: Kinesis Data Stream (Recommended)

**In Security Account** - Create Kinesis Stream:
```hcl
resource "aws_kinesis_stream" "logs_stream" {
  name             = "cloudwatch-logs-stream"
  shard_count      = 1
  retention_period = 24

  tags = {
    Name = "CloudWatch Logs Stream"
  }
}
```

**In Workload Account** - Create Subscription Filter:
```hcl
resource "aws_cloudwatch_log_subscription_filter" "to_security" {
  name            = "security-account-subscription"
  log_group_name  = "/aws/lambda/my-function"
  filter_pattern  = ""
  destination_arn = "arn:aws:kinesis:us-east-1:404068503087:stream/cloudwatch-logs-stream"
  role_arn        = aws_iam_role.cloudwatch_logs_sender.arn
}
```

### Method 2: Kinesis Firehose

**In Security Account** - Create Firehose:
```hcl
resource "aws_kinesis_firehose_delivery_stream" "logs_stream" {
  name        = "cloudwatch-logs-firehose"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.logs.arn
    prefix     = "cloudwatch-logs/"
  }
}
```

---

## 4. 🔍 GuardDuty Integration

GuardDuty automatically sends findings to the security account when configured as delegated administrator.

**In Security Account**:
```bash
aws guardduty enable-organization-admin-account \
  --admin-account-id 404068503087
```

**Accept Member Invitation**:
```bash
aws guardduty create-members \
  --detector-id <detector-id> \
  --account-details AccountId=<workload-account-id>,Email=<email>
```

---

## 5. 🛡️ Security Hub Integration

**In Security Account** - Enable as delegated admin:
```bash
aws securityhub enable-organization-admin-account \
  --admin-account-id 404068503087
```

**In Workload Account** - Accept invitation automatically via Organizations.

---

## 6. 🔐 AWS Config Aggregator

Already configured via `aws_config_aggregate_authorization` resource.

**In Security Account** - Create aggregator:
```hcl
resource "aws_config_configuration_aggregator" "organization" {
  name = "organization-aggregator"

  organization_aggregation_source {
    all_regions = true
    role_arn    = aws_iam_role.config_aggregator.arn
  }
}
```

---

## 7. 🕵️ Detective Integration

**In Security Account** - Create graph and invite members:
```bash
aws detective create-graph
aws detective create-members \
  --graph-arn <graph-arn> \
  --accounts AccountId=<workload-account-id>,EmailAddress=<email>
```

---

## 📊 Verification Commands

### Check CloudTrail Status
```bash
aws cloudtrail get-trail-status --name org-cloudtrail
```

### List VPC Flow Logs
```bash
aws ec2 describe-flow-logs
```

### Check S3 Bucket Contents
```bash
aws s3 ls s3://org-vpc-flow-logs-security-404068503087/ --recursive
```

### Verify CloudWatch Subscription
```bash
aws logs describe-subscription-filters --log-group-name /aws/lambda/my-function
```

---

## 🎯 Quick Reference: Role ARNs

Use these role ARNs when configuring services:

| Service | Role ARN |
|---------|----------|
| VPC Flow Logs | `arn:aws:iam::<workload-account>:role/VPCFlowLogsRole` |
| CloudWatch Logs | `arn:aws:iam::<workload-account>:role/CloudWatchLogsCrossAccountRole` |
| CloudTrail | `arn:aws:iam::<workload-account>:role/CloudTrailRole` |

---

## 🔧 Troubleshooting

### Issue: VPC Flow Logs not appearing in S3

**Solution:**
1. Check bucket policy allows `delivery.logs.amazonaws.com`
2. Verify bucket name is correct
3. Check IAM role has `s3:PutObject` permission

### Issue: CloudWatch subscription filter fails

**Solution:**
1. Verify Kinesis stream exists in security account
2. Check IAM role has `kinesis:PutRecord` permission
3. Ensure stream policy allows workload account

### Issue: CloudTrail logs missing

**Solution:**
1. Verify trail is started: `aws cloudtrail start-logging`
2. Check S3 bucket policy
3. Ensure organization trail is enabled

---

## 📚 Additional Resources

- [AWS CloudTrail Documentation](https://docs.aws.amazon.com/cloudtrail/)
- [VPC Flow Logs Guide](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [CloudWatch Logs Cross-Account Streaming](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CrossAccountSubscriptions.html)

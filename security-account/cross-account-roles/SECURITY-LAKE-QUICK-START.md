# 🚀 Security Lake Implementation - Quick Start Guide

## ✅ **YES! You can centralize everything into Security Lake**

All logs → Security Lake → OpenSearch (monitoring/alerting) + Athena (querying)

---

## 🎯 **What You Get**

```
┌─────────────────────────────────────────────────────────────┐
│                    ALL LOGS IN ONE PLACE                     │
│                                                               │
│  CloudTrail + VPC Flow + CloudWatch + GuardDuty + Config    │
│                           ↓                                   │
│              AWS SECURITY LAKE (OCSF Format)                 │
│                   S3 Parquet Files                           │
│                           ↓                                   │
│              ┌────────────┴────────────┐                     │
│              ↓                         ↓                     │
│      AMAZON OPENSEARCH          AMAZON ATHENA                │
│      ┌─────────────────┐       ┌──────────────┐            │
│      │ • Dashboards    │       │ • SQL Queries│            │
│      │ • Alerting      │       │ • Reports    │            │
│      │ • Real-time     │       │ • Audits     │            │
│      │ • Visualization │       │ • Analytics  │            │
│      └─────────────────┘       └──────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 **Implementation Steps**

### **Step 1: Enable Security Lake (5 minutes)**

Security Lake **automatically** ingests these AWS sources:
- ✅ CloudTrail Management Events
- ✅ CloudTrail Data Events
- ✅ VPC Flow Logs
- ✅ Route 53 Resolver Query Logs
- ✅ AWS WAF Logs
- ✅ GuardDuty Findings (via Security Hub)

**Terraform Configuration:**

```hcl
# File: security-account/security-lake/main.tf

# Enable Security Lake
resource "aws_securitylake_data_lake" "main" {
  meta_store_manager_role_arn = aws_iam_role.security_lake_manager.arn

  configuration {
    region = "us-east-1"

    lifecycle_configuration {
      expiration {
        days = 365
      }

      transition {
        days          = 30
        storage_class = "INTELLIGENT_TIERING"
      }
    }
  }

  tags = {
    Name = "org-security-lake"
  }
}

# IAM Role for Security Lake
resource "aws_iam_role" "security_lake_manager" {
  name = "AWSSecurityLakeMetaStoreManager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "securitylake.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "security_lake_admin" {
  role       = aws_iam_role.security_lake_manager.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSecurityLakeMetastoreManagerPolicy"
}

# Subscribe CloudTrail logs
resource "aws_securitylake_aws_log_source" "cloudtrail" {
  source_name    = "CLOUD_TRAIL_MGMT"
  source_version = "2.0"

  # Include all accounts
  source {
    accounts = [
      "290793900072",  # Workload account
      "404068503087"   # Security account
    ]
    regions = ["us-east-1"]
  }
}

# Subscribe VPC Flow Logs
resource "aws_securitylake_aws_log_source" "vpc_flow" {
  source_name    = "VPC_FLOW"
  source_version = "2.0"

  source {
    accounts = ["290793900072"]
    regions  = ["us-east-1"]
  }
}

# Subscribe GuardDuty (via Security Hub)
resource "aws_securitylake_aws_log_source" "security_hub" {
  source_name    = "SH_FINDINGS"
  source_version = "2.0"

  source {
    accounts = ["290793900072"]
    regions  = ["us-east-1"]
  }
}
```

**Deploy:**
```bash
cd security-account/security-lake
terraform init
terraform apply
```

---

### **Step 2: Set Up Glue Crawler for Athena (5 minutes)**

```hcl
# File: security-account/security-lake/glue.tf

# Glue Database
resource "aws_glue_catalog_database" "security_lake" {
  name = "amazon_security_lake_glue_db_us_east_1"
}

# Glue Crawler - Automatically discovers Security Lake schema
resource "aws_glue_crawler" "security_lake" {
  name          = "security-lake-crawler"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.security_lake.name

  # Security Lake S3 bucket (created automatically by Security Lake)
  s3_target {
    path = "s3://aws-security-data-lake-us-east-1-<ACCOUNT-ID>/ext/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  # Run every 6 hours
  schedule = "cron(0 */6 * * ? *)"

  tags = {
    Name = "security-lake-crawler"
  }
}

# IAM Role for Glue Crawler
resource "aws_iam_role" "glue_crawler" {
  name = "SecurityLakeGlueCrawlerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_crawler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Additional policy for Security Lake bucket access
resource "aws_iam_role_policy" "glue_security_lake_access" {
  name = "SecurityLakeAccess"
  role = aws_iam_role.glue_crawler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::aws-security-data-lake-*",
        "arn:aws:s3:::aws-security-data-lake-*/*"
      ]
    }]
  })
}
```

---

### **Step 3: Deploy OpenSearch (15 minutes)**

```hcl
# File: security-account/opensearch/main.tf

# OpenSearch Domain
resource "aws_opensearch_domain" "security" {
  domain_name    = "security-logs"
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type            = "r6g.xlarge.search"
    instance_count           = 3
    dedicated_master_enabled = true
    dedicated_master_type    = "r6g.large.search"
    dedicated_master_count   = 3
    zone_awareness_enabled   = true

    zone_awareness_config {
      availability_zone_count = 3
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 200  # GB per node
    volume_type = "gp3"
    iops        = 3000
    throughput  = 125
  }

  encrypt_at_rest {
    enabled    = true
    kms_key_id = aws_kms_key.opensearch.arn
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = "admin"
      master_user_password = random_password.opensearch.result
    }
  }

  vpc_options {
    subnet_ids = var.private_subnet_ids
    security_group_ids = [aws_security_group.opensearch.id]
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "*"
      }
      Action   = "es:*"
      Resource = "arn:aws:es:us-east-1:${data.aws_caller_identity.current.account_id}:domain/security-logs/*"
    }]
  })

  tags = {
    Name = "security-logs-opensearch"
  }
}

# Random password for OpenSearch admin
resource "random_password" "opensearch" {
  length  = 32
  special = true
}

# Store password in Secrets Manager
resource "aws_secretsmanager_secret" "opensearch_admin" {
  name = "opensearch-admin-password"
}

resource "aws_secretsmanager_secret_version" "opensearch_admin" {
  secret_id     = aws_secretsmanager_secret.opensearch_admin.id
  secret_string = random_password.opensearch.result
}

# Output OpenSearch endpoint
output "opensearch_endpoint" {
  value = "https://${aws_opensearch_domain.security.endpoint}"
}

output "opensearch_dashboard_endpoint" {
  value = "https://${aws_opensearch_domain.security.endpoint}/_dashboards"
}
```

---

### **Step 4: Lambda to Push Security Lake → OpenSearch**

```hcl
# File: security-account/opensearch/lambda.tf

# Lambda function to ingest Security Lake data into OpenSearch
resource "aws_lambda_function" "security_lake_to_opensearch" {
  filename         = "security_lake_to_opensearch.zip"
  function_name    = "security-lake-to-opensearch"
  role            = aws_iam_role.lambda_ingestion.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 1024

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = aws_opensearch_domain.security.endpoint
      OPENSEARCH_INDEX    = "security-lake-logs"
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# EventBridge Rule - Trigger on new Security Lake data
resource "aws_cloudwatch_event_rule" "security_lake_ingestion" {
  name        = "security-lake-new-data"
  description = "Trigger when new data arrives in Security Lake"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [{
          prefix = "aws-security-data-lake"
        }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda_ingestion" {
  rule      = aws_cloudwatch_event_rule.security_lake_ingestion.name
  target_id = "SecurityLakeToOpenSearch"
  arn       = aws_lambda_function.security_lake_to_opensearch.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_lake_to_opensearch.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.security_lake_ingestion.arn
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_ingestion" {
  name = "SecurityLakeToOpenSearchRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_ingestion.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "LambdaPermissions"
  role = aws_iam_role.lambda_ingestion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::aws-security-data-lake-*",
          "arn:aws:s3:::aws-security-data-lake-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpPost",
          "es:ESHttpPut"
        ]
        Resource = "${aws_opensearch_domain.security.arn}/*"
      }
    ]
  })
}
```

**Lambda Function Code (index.py):**
```python
import json
import boto3
import os
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth
import pyarrow.parquet as pq
import io

s3 = boto3.client('s3')
region = os.environ['AWS_REGION']
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    region,
    'es',
    session_token=credentials.token
)

opensearch = OpenSearch(
    hosts=[{'host': os.environ['OPENSEARCH_ENDPOINT'], 'port': 443}],
    http_auth=awsauth,
    use_ssl=True,
    verify_certs=True,
    connection_class=RequestsHttpConnection,
    timeout=300
)

def handler(event, context):
    print(f"Received event: {json.dumps(event)}")

    # Get S3 details from EventBridge
    bucket = event['detail']['bucket']['name']
    key = event['detail']['object']['key']

    print(f"Processing: s3://{bucket}/{key}")

    try:
        # Download Parquet file
        obj = s3.get_object(Bucket=bucket, Key=key)
        parquet_data = io.BytesIO(obj['Body'].read())

        # Read Parquet file
        table = pq.read_table(parquet_data)
        records = table.to_pylist()

        print(f"Found {len(records)} records")

        # Bulk index to OpenSearch
        if records:
            actions = []
            for record in records:
                # Create index action
                actions.append(json.dumps({
                    "index": {
                        "_index": os.environ['OPENSEARCH_INDEX'],
                        "_id": record.get('metadata', {}).get('uid', record.get('time'))
                    }
                }))
                actions.append(json.dumps(record))

            # Send to OpenSearch
            body = '\n'.join(actions) + '\n'
            response = opensearch.bulk(body=body)

            if response.get('errors'):
                print(f"Errors during indexing: {response}")
            else:
                print(f"Successfully indexed {len(records)} records")

        return {
            'statusCode': 200,
            'body': f'Processed {len(records)} records from {key}'
        }

    except Exception as e:
        print(f"Error processing file: {str(e)}")
        raise
```

---

## 🎯 **Athena Queries (After Crawler Runs)**

```sql
-- Find all CloudTrail events in last 24 hours
SELECT
    time,
    unmapped['userIdentity']['principalId'] as user,
    unmapped['eventName'] as event,
    unmapped['sourceIPAddress'] as source_ip,
    cloud.region
FROM amazon_security_lake_glue_db_us_east_1.amazon_security_lake_table_us_east_1_cloud_trail_mgmt_2_0
WHERE time >= current_timestamp - interval '24' hour
ORDER BY time DESC
LIMIT 100;

-- Find VPC Flow Logs with high traffic
SELECT
    time,
    src_endpoint.ip as source,
    dst_endpoint.ip as destination,
    dst_endpoint.port,
    traffic.bytes,
    connection_info.direction
FROM amazon_security_lake_glue_db_us_east_1.amazon_security_lake_table_us_east_1_vpc_flow_2_0
WHERE time >= current_timestamp - interval '1' hour
    AND traffic.bytes > 10000000  -- > 10MB
ORDER BY traffic.bytes DESC;

-- GuardDuty high severity findings
SELECT
    time,
    finding.title,
    severity,
    resources[1].details as resource
FROM amazon_security_lake_glue_db_us_east_1.amazon_security_lake_table_us_east_1_sh_findings_2_0
WHERE time >= current_timestamp - interval '7' day
    AND severity_id >= 4
ORDER BY severity_id DESC;
```

---

## 📊 **OpenSearch Dashboard Access**

1. **Get OpenSearch endpoint:**
   ```bash
   terraform output opensearch_dashboard_endpoint
   ```

2. **Get admin password:**
   ```bash
   aws secretsmanager get-secret-value \
     --secret-id opensearch-admin-password \
     --query SecretString \
     --output text
   ```

3. **Access dashboard:**
   - URL: `https://<opensearch-endpoint>/_dashboards`
   - Username: `admin`
   - Password: (from step 2)

---

## 🎉 **Summary**

### **What This Gets You:**

✅ **Unified Data Lake**
- All security logs in one place (Security Lake S3)
- Standard OCSF format for consistency
- Automatic AWS source ingestion

✅ **Real-Time Monitoring (OpenSearch)**
- Live dashboards
- Alerting on suspicious activity
- Anomaly detection
- Fast searches

✅ **Historical Analysis (Athena)**
- SQL queries on all logs
- Cost-effective for large datasets
- Compliance reporting
- Forensic investigations

✅ **Cost Optimized**
- Security Lake handles lifecycle automatically
- OpenSearch only for recent/hot data
- Athena pay-per-query model

---

## 📈 **Estimated Costs (Example)**

**Assumptions:** 1TB logs/month, 3-node OpenSearch cluster

| Service | Monthly Cost |
|---------|-------------|
| Security Lake Storage | ~$25 (S3 + lifecycle) |
| OpenSearch (r6g.xlarge x3) | ~$750 |
| Athena Queries (~100GB scanned) | ~$5 |
| Lambda Ingestion | ~$10 |
| **Total** | **~$790/month** |

---

## 🚀 **Next Steps**

1. **Deploy Security Lake** (Step 1)
2. **Run Glue Crawler** (Step 2)
3. **Test Athena queries**
4. **Deploy OpenSearch** (Step 3)
5. **Deploy Lambda ingestion** (Step 4)
6. **Create dashboards in OpenSearch**
7. **Set up alerting rules**

Need help with any step? Check `SECURITY-LAKE-ARCHITECTURE.md` for detailed explanations!

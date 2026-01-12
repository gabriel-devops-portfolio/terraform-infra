# 🏗️ Unified Security Lake Architecture

## 🎯 **Architecture Overview**

**Goal:** Centralize ALL security logs into Security Lake → Use OpenSearch for real-time monitoring/alerting → Use Athena for querying

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        WORKLOAD ACCOUNT (290793900072)                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐│
│  │  CloudTrail  │  │ VPC Flow Logs│  │ CloudWatch   │  │  GuardDuty  ││
│  │              │  │              │  │     Logs     │  │             ││
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬──────┘│
│         │                 │                 │                 │        │
│         │                 │                 │                 │        │
└─────────┼─────────────────┼─────────────────┼─────────────────┼────────┘
          │                 │                 │                 │
          │                 │                 │                 │
          ▼                 ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      SECURITY ACCOUNT (404068503087)                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    AWS SECURITY LAKE (OCSF Format)                 │  │
│  │                                                                     │  │
│  │  S3 Bucket: org-security-lake-data-404068503087                   │  │
│  │  Format: OCSF (Open Cybersecurity Schema Framework)               │  │
│  │  Storage: Parquet files partitioned by date/source                │  │
│  │                                                                     │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │  │
│  │  │ CloudTrail  │  │VPC Flow Logs│  │  CloudWatch │  │ GuardDuty│ │  │
│  │  │   Logs      │  │             │  │    Logs     │  │ Findings │ │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └──────────┘ │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌──────────┐ │  │
│  │  │Security Hub │  │   Config    │  │  Detective  │  │   WAF    │ │  │
│  │  │  Findings   │  │   Changes   │  │    Data     │  │   Logs   │ │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └──────────┘ │  │
│  └───────────────────────┬───────────────────────────────────────────┘  │
│                          │                                               │
│                          │ (Glue Catalog + Crawler)                      │
│                          ▼                                               │
│         ┌────────────────────────────────────────────┐                  │
│         │                                             │                  │
│    ┌────▼─────┐                              ┌───────▼──────┐           │
│    │          │                              │              │           │
│    │ AMAZON   │◄─────────────────────────────┤   AMAZON     │           │
│    │ ATHENA   │  Query Security Lake Data    │  OPENSEARCH  │           │
│    │          │                              │   SERVICE    │           │
│    └──────────┘                              └──────┬───────┘           │
│         │                                           │                    │
│         │                                           │                    │
│         ▼                                           ▼                    │
│  ┌─────────────────┐                      ┌──────────────────┐         │
│  │  Ad-hoc Queries │                      │  Real-time       │         │
│  │  Investigations │                      │  - Dashboards    │         │
│  │  Compliance     │                      │  - Alerting      │         │
│  │  Reports        │                      │  - Visualization │         │
│  └─────────────────┘                      │  - Monitoring    │         │
│                                            └──────────────────┘         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 **Data Flow Architecture**

### **Phase 1: Log Collection → Security Lake**

| Source | Original Destination | New Destination | Transformation Method |
|--------|---------------------|-----------------|----------------------|
| **CloudTrail** | S3: `cloudtrail-logs` | Security Lake | EventBridge → Lambda → OCSF → Security Lake |
| **VPC Flow Logs** | S3: `vpc-flow-logs` | Security Lake | EventBridge → Lambda → OCSF → Security Lake |
| **CloudWatch Logs** | Kinesis/Firehose | Security Lake | Firehose → Lambda → OCSF → Security Lake |
| **GuardDuty** | GuardDuty service | Security Lake | ✅ **Native integration** |
| **Security Hub** | Security Hub service | Security Lake | ✅ **Native integration** |
| **Config** | Config service | Security Lake | EventBridge → Lambda → OCSF → Security Lake |
| **WAF Logs** | S3: `waf-logs` | Security Lake | EventBridge → Lambda → OCSF → Security Lake |

### **Phase 2: Security Lake → Analytics**

```
Security Lake (OCSF Parquet Files)
        │
        ├──────► AWS Glue Crawler (Catalog metadata)
        │               │
        │               ▼
        │        Glue Data Catalog
        │               │
        ├───────────────┼──────────────┐
        │               │              │
        ▼               ▼              ▼
   OpenSearch     Amazon Athena   QuickSight
   (Real-time)    (SQL Queries)   (Dashboards)
```

---

## 🔧 **Implementation Strategy**

### **Option 1: Native Security Lake Integration (Recommended)**

AWS Security Lake has **native integrations** for:
- ✅ Amazon GuardDuty
- ✅ AWS Security Hub
- ✅ AWS CloudTrail
- ✅ VPC Flow Logs
- ✅ Route 53 Resolver Query Logs
- ✅ AWS WAF

**Benefits:**
- Automatic OCSF conversion
- No Lambda required for native sources
- Managed service handles partitioning
- Built-in data normalization

**Configuration:**
```hcl
resource "aws_securitylake_data_lake" "main" {
  meta_store_manager_role_arn = aws_iam_role.security_lake.arn

  configuration {
    region = "us-east-1"

    # Lifecycle configuration
    lifecycle_configuration {
      expiration {
        days = 365
      }
      transition {
        days          = 30
        storage_class = "GLACIER"
      }
    }
  }
}

# Subscribe AWS sources
resource "aws_securitylake_aws_log_source" "cloudtrail" {
  source_name    = "CLOUD_TRAIL_MGMT"
  source_version = "2.0"

  # All accounts in organization
  accounts = ["290793900072", "404068503087"]
}

resource "aws_securitylake_aws_log_source" "vpc_flow" {
  source_name    = "VPC_FLOW"
  source_version = "2.0"
  accounts       = ["290793900072"]
}

resource "aws_securitylake_aws_log_source" "guardduty" {
  source_name    = "SH_FINDINGS"
  source_version = "2.0"
  accounts       = ["290793900072"]
}
```

---

### **Option 2: Custom Integration (For Custom Logs)**

For CloudWatch Logs and custom applications:

**Step 1: Firehose → Lambda → Security Lake**
```hcl
# Kinesis Data Firehose with transformation
resource "aws_kinesis_firehose_delivery_stream" "logs_to_security_lake" {
  name        = "logs-to-security-lake"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn   = aws_iam_role.firehose.arn
    bucket_arn = aws_s3_bucket.security_lake_data.arn
    prefix     = "ext/cloudwatch/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"

    # Transform to OCSF
    processing_configuration {
      enabled = true

      processors {
        type = "Lambda"

        parameters {
          parameter_name  = "LambdaArn"
          parameter_value = aws_lambda_function.ocsf_transformer.arn
        }
      }
    }

    # Parquet conversion
    data_format_conversion_configuration {
      enabled = true

      input_format_configuration {
        deserializer {
          open_x_json_ser_de {}
        }
      }

      output_format_configuration {
        serializer {
          parquet_ser_de {}
        }
      }

      schema_configuration {
        database_name = aws_glue_catalog_database.security_lake.name
        table_name    = aws_glue_catalog_table.cloudwatch_logs.name
        role_arn      = aws_iam_role.firehose.arn
      }
    }
  }
}
```

**Step 2: Lambda OCSF Transformer**
```python
# Lambda function to convert logs to OCSF format
import json
import base64
from datetime import datetime

def lambda_handler(event, context):
    output = []

    for record in event['records']:
        # Decode log data
        payload = json.loads(base64.b64decode(record['data']))

        # Transform to OCSF 1.1.0 schema
        ocsf_event = {
            "activity_id": 1,  # Create
            "category_uid": 6,  # Application Activity
            "class_uid": 6001,  # Application Lifecycle
            "metadata": {
                "version": "1.1.0",
                "product": {
                    "name": "CloudWatch Logs",
                    "vendor_name": "AWS"
                },
                "log_name": payload.get('logGroup'),
                "logged_time": int(datetime.utcnow().timestamp() * 1000)
            },
            "severity_id": 1,  # Informational
            "time": payload.get('timestamp'),
            "cloud": {
                "account": {
                    "uid": payload.get('accountId')
                },
                "region": payload.get('region'),
                "provider": "AWS"
            },
            "unmapped": payload  # Original data
        }

        # Encode output
        output.append({
            'recordId': record['recordId'],
            'result': 'Ok',
            'data': base64.b64encode(
                json.dumps(ocsf_event).encode('utf-8')
            ).decode('utf-8')
        })

    return {'records': output}
```

---

## 🔍 **OpenSearch Integration**

### **Architecture: Security Lake → OpenSearch**

```
Security Lake S3 Bucket
        │
        ▼
  EventBridge Rule (New object created)
        │
        ▼
  Lambda Function (S3 → OpenSearch)
        │
        ▼
  Amazon OpenSearch Service
        │
        ├──► Dashboards (Kibana)
        ├──► Alerting
        └──► Anomaly Detection
```

**Implementation:**

```hcl
# OpenSearch Domain
resource "aws_opensearch_domain" "security_logs" {
  domain_name    = "security-logs"
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type            = "r6g.large.search"
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
    volume_size = 100
    volume_type = "gp3"
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
      master_user_password = random_password.opensearch_admin.result
    }
  }

  tags = {
    Name = "security-logs-opensearch"
  }
}

# Lambda to push logs from S3 to OpenSearch
resource "aws_lambda_function" "s3_to_opensearch" {
  filename         = "s3_to_opensearch.zip"
  function_name    = "s3-to-opensearch"
  role            = aws_iam_role.lambda_s3_opensearch.arn
  handler         = "index.handler"
  runtime         = "python3.11"
  timeout         = 300
  memory_size     = 512

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = aws_opensearch_domain.security_logs.endpoint
      OPENSEARCH_INDEX    = "security-logs"
    }
  }
}

# EventBridge Rule - Trigger on new S3 objects
resource "aws_cloudwatch_event_rule" "security_lake_new_data" {
  name        = "security-lake-new-data"
  description = "Trigger when new data arrives in Security Lake"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.security_lake_data.id]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.security_lake_new_data.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.s3_to_opensearch.arn
}
```

**Lambda Function (s3_to_opensearch.py):**
```python
import json
import boto3
import os
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth

s3 = boto3.client('s3')
region = os.environ['AWS_REGION']
service = 'es'
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(credentials.access_key, credentials.secret_key,
                   region, service, session_token=credentials.token)

opensearch = OpenSearch(
    hosts=[{'host': os.environ['OPENSEARCH_ENDPOINT'], 'port': 443}],
    http_auth=awsauth,
    use_ssl=True,
    verify_certs=True,
    connection_class=RequestsHttpConnection
)

def handler(event, context):
    # Get S3 object details
    bucket = event['detail']['bucket']['name']
    key = event['detail']['object']['key']

    # Read Parquet file from S3
    obj = s3.get_object(Bucket=bucket, Key=key)

    # Parse Parquet (use pyarrow)
    import pyarrow.parquet as pq
    import io

    parquet_file = pq.read_table(io.BytesIO(obj['Body'].read()))
    records = parquet_file.to_pylist()

    # Bulk index to OpenSearch
    actions = []
    for record in records:
        actions.append({
            "index": {
                "_index": os.environ['OPENSEARCH_INDEX'],
                "_id": record.get('event_uid', record.get('time'))
            }
        })
        actions.append(record)

    if actions:
        opensearch.bulk(body=actions)

    return {
        'statusCode': 200,
        'body': f'Indexed {len(records)} records'
    }
```

---

## 🔍 **Athena Queries**

### **Glue Crawler Configuration**

```hcl
# Glue Database for Security Lake
resource "aws_glue_catalog_database" "security_lake" {
  name = "security_lake"
}

# Glue Crawler to catalog Security Lake data
resource "aws_glue_crawler" "security_lake" {
  name          = "security-lake-crawler"
  role          = aws_iam_role.glue_crawler.arn
  database_name = aws_glue_catalog_database.security_lake.name

  s3_target {
    path = "s3://${aws_s3_bucket.security_lake_data.id}/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  schedule = "cron(0 */6 * * ? *)"  # Every 6 hours
}
```

### **Example Athena Queries**

**1. Query CloudTrail Events:**
```sql
SELECT
    time,
    actor.user.name as user,
    activity_name,
    api.operation as api_call,
    cloud.region,
    src_endpoint.ip as source_ip
FROM security_lake.cloudtrail
WHERE time >= current_timestamp - interval '24' hour
    AND severity_id >= 3  -- Medium or higher
ORDER BY time DESC
LIMIT 100;
```

**2. Query VPC Flow Logs - Denied Connections:**
```sql
SELECT
    time,
    src_endpoint.ip as source_ip,
    dst_endpoint.ip as destination_ip,
    dst_endpoint.port as dest_port,
    traffic.bytes as bytes_transferred,
    connection_info.protocol_num as protocol
FROM security_lake.vpc_flow_logs
WHERE time >= current_timestamp - interval '1' hour
    AND disposition_id = 2  -- Denied
ORDER BY time DESC;
```

**3. Query GuardDuty Findings - High Severity:**
```sql
SELECT
    time,
    finding.title,
    finding.types,
    severity,
    resources[1].instance_details.instance_id as instance,
    cloud.account.uid as account_id
FROM security_lake.guardduty_findings
WHERE time >= current_timestamp - interval '7' day
    AND severity_id >= 4  -- High or Critical
ORDER BY severity_id DESC, time DESC;
```

**4. Cross-Source Correlation:**
```sql
-- Find instances with GuardDuty findings AND suspicious network activity
SELECT DISTINCT
    g.resources[1].instance_details.instance_id as instance_id,
    g.finding.title as guardduty_finding,
    COUNT(DISTINCT v.dst_endpoint.ip) as unique_destinations,
    SUM(v.traffic.bytes) as total_bytes
FROM security_lake.guardduty_findings g
JOIN security_lake.vpc_flow_logs v
    ON g.resources[1].instance_details.instance_id = v.src_endpoint.instance_uid
WHERE g.time >= current_timestamp - interval '24' hour
    AND v.time >= current_timestamp - interval '24' hour
    AND g.severity_id >= 4
GROUP BY 1, 2
HAVING COUNT(DISTINCT v.dst_endpoint.ip) > 100  -- Suspicious
ORDER BY total_bytes DESC;
```

---

## 📊 **OpenSearch Dashboards**

### **Pre-built Dashboard Examples**

**1. Security Overview Dashboard:**
- Total events by severity
- Top 10 threat types
- Geographic heat map of attacks
- Timeline of security events
- Failed login attempts

**2. Network Security Dashboard:**
- VPC Flow Logs denied connections
- Top talkers (source/destination IPs)
- Protocol distribution
- Bandwidth usage by connection
- Anomalous connection patterns

**3. CloudTrail Audit Dashboard:**
- API calls by user/service
- High-risk API operations (DeleteBucket, ModifySecurityGroup)
- Failed authentication attempts
- Cross-region API calls
- Root account usage

### **Alerting Rules:**

```json
{
  "name": "High Severity GuardDuty Finding",
  "type": "monitor",
  "monitor_type": "query_level_monitor",
  "enabled": true,
  "schedule": {
    "period": {
      "interval": 5,
      "unit": "MINUTES"
    }
  },
  "inputs": [{
    "search": {
      "indices": ["security-logs"],
      "query": {
        "bool": {
          "filter": [{
            "range": {
              "time": {
                "gte": "now-5m"
              }
            }
          }, {
            "term": {
              "class_uid": 2001
            }
          }, {
            "range": {
              "severity_id": {
                "gte": 4
              }
            }
          }]
        }
      }
    }
  }],
  "triggers": [{
    "name": "Alert on high severity finding",
    "severity": "1",
    "condition": {
      "script": {
        "source": "ctx.results[0].hits.total.value > 0"
      }
    },
    "actions": [{
      "name": "Send SNS notification",
      "destination_id": "sns-topic-id",
      "message_template": {
        "source": "High severity GuardDuty finding detected: {{ctx.results.0.hits.hits.0._source.finding.title}}"
      }
    }]
  }]
}
```

---

## 💰 **Cost Optimization**

### **Storage Tiers:**
```
Security Lake S3:
├─ Hot (0-30 days): S3 Standard → $0.023/GB
├─ Warm (30-90 days): S3 IA → $0.0125/GB
└─ Cold (90+ days): S3 Glacier → $0.004/GB
```

### **Data Lifecycle:**
```hcl
resource "aws_s3_bucket_lifecycle_configuration" "security_lake_data" {
  bucket = aws_s3_bucket.security_lake_data.id

  rule {
    id     = "security-lake-lifecycle"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555  # 7 years compliance
    }
  }
}
```

---

## 🎯 **Implementation Roadmap**

### **Phase 1: Security Lake Setup (Week 1)**
- [ ] Create Security Lake in security account
- [ ] Enable native AWS source integrations
- [ ] Configure Glue Crawler
- [ ] Test Athena queries

### **Phase 2: OpenSearch Setup (Week 2)**
- [ ] Deploy OpenSearch domain
- [ ] Create Lambda S3→OpenSearch ingestion
- [ ] Set up EventBridge triggers
- [ ] Build initial dashboards

### **Phase 3: Custom Log Sources (Week 3)**
- [ ] Deploy Kinesis Firehose for CloudWatch Logs
- [ ] Create OCSF transformation Lambda
- [ ] Configure subscription filters
- [ ] Test end-to-end flow

### **Phase 4: Alerting & Automation (Week 4)**
- [ ] Create OpenSearch alerting rules
- [ ] Set up SNS topics for notifications
- [ ] Build automated response Lambda functions
- [ ] Create runbooks for common scenarios

---

## 📚 **Additional Resources**

- [AWS Security Lake Documentation](https://docs.aws.amazon.com/security-lake/)
- [OCSF Schema 1.1.0](https://schema.ocsf.io/)
- [OpenSearch Security Analytics](https://opensearch.org/docs/latest/security-analytics/)
- [Athena Query Examples](https://docs.aws.amazon.com/athena/)

---

**Created:** January 12, 2026
**Status:** Architecture Design Complete
**Next Step:** Implement Phase 1 - Security Lake Setup

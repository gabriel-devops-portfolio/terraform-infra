# OpenSearch Data Source Analysis - IMPORTANT CLARIFICATION

## 🔍 **Critical Finding: OpenSearch is NOT reading from Security Lake**

After thorough analysis of your Terraform configuration, I need to correct my previous statement:

### ❌ **What I Said Before (INCORRECT)**
> "OpenSearch reads from Security Lake S3 bucket"

### ✅ **Actual Configuration (CORRECT)**
**OpenSearch is reading DIRECTLY from the VPC Flow Logs S3 bucket, NOT from Security Lake**

---

## 📊 **Current Architecture**

```
┌─────────────────────────────────────────────────────────────────┐
│                  Workload Account (290793900072)                 │
│                                                                   │
│  ┌──────────────┐              ┌──────────────┐                 │
│  │ Workload VPC │              │  Egress VPC  │                 │
│  │ (Private)    │              │  (Public)    │                 │
│  └──────┬───────┘              └──────┬───────┘                 │
│         │                             │                          │
│         │ VPC Flow Logs (Parquet)    │                          │
│         └──────────────┬──────────────┘                          │
│                        │                                         │
│                        ▼                                         │
│          Cross-Account S3 PutObject                              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         │ HTTPS (TLS)
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│               Security Account (404068503087)                    │
│                                                                   │
│  ┌──────────────────────────────────────────────────────┐       │
│  │  S3: org-vpc-flow-logs-security-<account-id>         │       │
│  │  • Contains: VPC Flow Logs (Parquet)                 │       │
│  │  • Format: Hive-partitioned Parquet                  │       │
│  └────────────┬────────────────┬──────────────────────┘         │
│               │                │                                 │
│               │                │                                 │
│      ┌────────▼───────┐  ┌────▼────────────────┐               │
│      │  Security Lake │  │  OpenSearch Domain  │               │
│      │  Data Lake     │  │  (t3.medium)        │               │
│      │                │  │                     │               │
│      │ • Native AWS   │  │ • Reads RAW Parquet │               │
│      │   ingestion    │  │   from VPC Flow     │               │
│      │ • OCSF         │  │   Logs bucket       │               │
│      │   transform    │  │ • NOT from Security │               │
│      │ • Class 4001   │  │   Lake OCSF data    │               │
│      └────────────────┘  └─────────────────────┘               │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
```

---

## 📝 **Evidence from Configuration Files**

### 1. **S3 Bucket Policy** (`cross-account-roles/s3-buckets.tf`)

```hcl
resource "aws_s3_bucket_policy" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  policy = jsonencode({
    Statement = [
      {
        Sid    = "OpenSearchReadAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.opensearch.arn  # ← OpenSearch IAM role
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.vpc_flow_logs.arn,          # ← VPC Flow Logs bucket
          "${aws_s3_bucket.vpc_flow_logs.arn}/*"    # ← NOT Security Lake bucket
        ]
      }
    ]
  })
}
```

**Analysis**: OpenSearch IAM role has explicit permission to read from `org-vpc-flow-logs-security-*` bucket.

---

### 2. **Security Lake Configuration** (`security-lake/main.tf`)

```hcl
# Security Lake ingests VPC Flow Logs
resource "aws_securitylake_aws_log_source" "vpc_flow" {
  source {
    accounts    = var.member_account_ids
    regions     = [local.region]
    source_name = "VPC_FLOW"  # Native AWS source
  }
}

# Security Lake Data Lake bucket
resource "aws_securitylake_data_lake" "main" {
  meta_store_manager_role_arn = aws_iam_role.security_lake_manager.arn
  # Bucket: aws-security-data-lake-us-east-1-<account-id>
}
```

**Analysis**: Security Lake has its OWN bucket (`aws-security-data-lake-*`) for OCSF-transformed data, but OpenSearch is NOT connected to this bucket.

---

### 3. **OpenSearch Configuration** (`opensearch/main.tf`)

```hcl
resource "aws_opensearch_domain" "security_logs" {
  domain_name    = "security-logs"
  engine_version = "OpenSearch_2.11"

  # No explicit Security Lake integration
  # No S3 data source configuration pointing to Security Lake bucket
}
```

**Analysis**: OpenSearch domain has no configuration linking it to Security Lake's S3 bucket.

---

### 4. **No Security Lake Subscriber Configured**

**Missing Resource**:
```hcl
# THIS DOES NOT EXIST IN YOUR CONFIGURATION:
resource "aws_securitylake_subscriber" "opensearch" {
  subscriber_name = "opensearch-subscriber"

  source {
    # Would configure OpenSearch to receive OCSF data from Security Lake
  }
}
```

**Analysis**: There is no `aws_securitylake_subscriber` resource to connect OpenSearch to Security Lake.

---

## 🔄 **Data Flow Reality**

### **Current Flow (What's Actually Happening)**

```
Workload VPC → VPC Flow Logs (Parquet)
            → S3 Bucket: org-vpc-flow-logs-security-*
            → OpenSearch (reads RAW Parquet files)
            ✅ OpenSearch indexes RAW VPC Flow Log fields

Workload VPC → VPC Flow Logs (Parquet)
            → S3 Bucket: org-vpc-flow-logs-security-*
            → Security Lake (native ingestion)
            → OCSF Transformation (class 4001)
            → S3 Bucket: aws-security-data-lake-*
            ❌ OpenSearch NOT connected (no subscriber)
```

### **What This Means**

1. **OpenSearch sees**: Raw VPC Flow Log fields
   - `srcaddr`, `dstaddr`, `srcport`, `dstport`
   - `protocol`, `bytes`, `packets`
   - `action` (ACCEPT/REJECT)
   - **NOT OCSF format**

2. **Security Lake has**: OCSF-normalized data
   - `class_uid: 4001` (Network Activity)
   - `src_endpoint.ip`, `dst_endpoint.ip`
   - `traffic.bytes`, `traffic.packets`
   - `disposition: "Allowed" or "Blocked"`
   - **But OpenSearch can't access it**

---

## ⚠️ **Implications**

### **Pros of Current Setup**
✅ OpenSearch can query VPC Flow Logs immediately (no transformation delay)
✅ Raw Parquet format is efficient for storage and queries
✅ No additional Security Lake subscriber costs
✅ Direct S3 access is simpler architecture

### **Cons of Current Setup**
❌ OpenSearch data is NOT in OCSF standard format
❌ Cannot correlate with other OCSF sources (CloudTrail, Security Hub) easily
❌ Queries need to use raw VPC Flow Log schema, not standardized OCSF schema
❌ Security Lake OCSF data is essentially unused by OpenSearch

---

## 🎯 **Two Architecture Options**

### **Option 1: Keep Current (OpenSearch reads raw VPC Flow Logs)**

**Configuration**: No changes needed (current setup)

**Pros**:
- ✅ Simpler architecture
- ✅ Faster data availability (no transformation delay)
- ✅ Lower costs (no subscriber fees)
- ✅ Efficient Parquet queries

**Cons**:
- ❌ Not OCSF standardized
- ❌ Harder to correlate with other security sources
- ❌ Security Lake OCSF transformation is wasted effort

**Best For**: If you primarily query VPC Flow Logs in isolation and don't need OCSF standardization.

---

### **Option 2: Connect OpenSearch to Security Lake (Read OCSF data)**

**Configuration**: Add Security Lake subscriber for OpenSearch

**Changes Required**:

1. **Create Security Lake Subscriber** (`security-lake/main.tf`):
```hcl
resource "aws_securitylake_subscriber" "opensearch" {
  subscriber_name = "opensearch-ocsf-subscriber"

  access_type = "S3"

  source {
    aws_log_source_resource {
      source_name    = "VPC_FLOW"
      source_version = "2.0"
    }
  }

  subscriber_identity {
    principal = aws_iam_role.security_lake_subscriber.arn
  }
}
```

2. **Update OpenSearch IAM Policy** (`cross-account-roles/iam-roles.tf`):
```hcl
resource "aws_iam_role_policy" "opensearch_security_lake" {
  name = "OpenSearchSecurityLakeAccess"
  role = aws_iam_role.opensearch.id

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
          "arn:aws:s3:::aws-security-data-lake-${local.region}-${local.security_account_id}",
          "arn:aws:s3:::aws-security-data-lake-${local.region}-${local.security_account_id}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetTable",
          "glue:GetDatabase",
          "glue:GetPartitions"
        ]
        Resource = "*"
      }
    ]
  })
}
```

3. **Update S3 Bucket Policy** (`cross-account-roles/s3-buckets.tf`):
```hcl
# Modify VPC Flow Logs bucket policy to REMOVE OpenSearch access
# Add policy to Security Lake bucket to GRANT OpenSearch access
```

**Pros**:
- ✅ OCSF standardized data format
- ✅ Easy correlation with CloudTrail, Security Hub, Route 53
- ✅ Unified security data model
- ✅ Better for compliance reporting (standardized schema)

**Cons**:
- ❌ More complex setup
- ❌ Potential transformation delay (minutes)
- ❌ Security Lake subscriber costs (~$0.0045/GB ingested)
- ❌ Queries use different schema (OCSF fields vs raw VPC Flow)

**Best For**: If you want unified OCSF-based security analytics across multiple data sources.

---

## 💰 **Cost Comparison**

### **Option 1: Current Setup (Raw VPC Flow)**
- VPC Flow Logs: $50/month
- S3 Storage: $2.75/month
- OpenSearch: $111/month
- **Total**: ~$164/month

### **Option 2: Security Lake OCSF**
- VPC Flow Logs: $50/month
- S3 Storage: $2.75/month
- Security Lake Ingestion: $0.45/month (100GB × $0.0045)
- Security Lake Subscriber: $0.45/month (query access)
- OpenSearch: $111/month
- **Total**: ~$165/month (+$1/month)

**Minimal cost difference** - decision should be based on OCSF requirements.

---

## 🤔 **Recommendation**

### **If Your Priority Is:**

1. **Quick Setup & Simple Queries** → **Keep Current (Option 1)**
   - You're already set up and working
   - Raw VPC Flow Log schema is well-documented
   - No changes needed

2. **OCSF Standardization & Multi-Source Correlation** → **Switch to Security Lake (Option 2)**
   - Need to query VPC Flow + CloudTrail + Security Hub together
   - Want industry-standard OCSF format for compliance
   - Plan to use security analytics tools that expect OCSF

### **My Recommendation**:
**Switch to Option 2 (Security Lake OCSF)** because:
- You've ALREADY set up Security Lake (effort already spent)
- OCSF is industry standard for security data exchange
- Easier to add new data sources in future (all in OCSF)
- Only $1/month more expensive
- Better for long-term security operations

---

## 📚 **Next Steps (If You Want Option 2)**

1. Create Security Lake subscriber resource
2. Update OpenSearch IAM role permissions
3. Update OpenSearch index mappings for OCSF schema
4. Create OCSF-based queries and dashboards
5. Test data flow: VPC → Security Lake → OpenSearch
6. Update documentation to reflect OCSF architecture

Let me know if you want me to implement Option 2! 🚀

---

**Document Version**: 1.0
**Last Updated**: January 13, 2026
**Status**: Configuration Analysis Complete

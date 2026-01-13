# Athena Module Deployment Guide

## 🎯 Deployment Method

### Option 1: Deploy Everything (Recommended)

```bash
cd security-account/backend-bootstrap

# Initialize Terraform
terraform init

# Review changes (will show Athena queries being created)
terraform plan

# Deploy all security infrastructure including Athena queries
terraform apply
```

### Option 2: Deploy Only Athena Module

```bash
cd security-account/backend-bootstrap

# Target only the Athena module
terraform apply -target=module.athena
```

## ✅ What Gets Deployed

When you run `terraform apply` in `backend-bootstrap/`, it will deploy:

1. **Cross-Account Roles** → IAM roles, S3 buckets, KMS keys
2. **OpenSearch** → Log visualization
3. **Security Lake** → OCSF data lake with Glue database
4. **Athena Queries** (NEW!) → 7 named queries + 4 view creation queries
5. **SOC Alerting** → SNS topics and monitoring
6. **Config Drift Detection** → AWS Config rules

## 📊 Deployed Athena Queries

After deployment, you'll have these queries available in Athena console:

1. ✅ `vpc-traffic-anomalies` - Detect rejected connections and unusual ports
2. ✅ `terraform-state-access` - Monitor Terraform state file access
3. ✅ `privileged-activity-monitoring` - Track root and assumed role activity
4. ✅ `guardduty-high-severity-findings` - Query critical security findings
5. ✅ `failed-authentication-attempts` - Detect AccessDenied patterns
6. ✅ `s3-public-access-changes` - Monitor bucket policy modifications
7. ✅ `security-group-changes` - Track security group rule changes

Plus 4 view creation queries for reusable views.

## 🔄 Deployment Flow

```
terraform apply (in backend-bootstrap/)
         ↓
┌────────────────────────────────┐
│  1. Cross-Account Roles        │ ← Creates S3 buckets, IAM roles
└────────────────────────────────┘
         ↓
┌────────────────────────────────┐
│  2. Security Lake              │ ← Creates Glue database
└────────────────────────────────┘
         ↓
┌────────────────────────────────┐
│  3. Athena Module (NEW!)       │ ← Creates 11 named queries
│     - VPC traffic queries      │
│     - Terraform state queries  │
│     - Privileged activity      │
│     - GuardDuty queries        │
│     - Auth failure queries     │
│     - S3 access queries        │
│     - Security group queries   │
└────────────────────────────────┘
         ↓
┌────────────────────────────────┐
│  4. OpenSearch & SOC Alerting  │ ← Visualization and alerts
└────────────────────────────────┘
```

## 🧪 Post-Deployment Verification

### 1. Verify Athena Queries Were Created

```bash
# List all named queries
aws athena list-named-queries --region us-east-1

# Get query details
aws athena get-named-query --named-query-id <query-id>
```

### 2. Test a Query in Athena Console

1. Go to Athena Console: https://console.aws.amazon.com/athena
2. Select workgroup: `security-lake-queries`
3. Click "Saved queries"
4. Select `vpc-traffic-anomalies`
5. Click "Run query"

### 3. Create Views (One-Time Setup)

After deployment, run these queries in Athena console to create reusable views:

1. `create-view-vpc-traffic-anomalies`
2. `create-view-terraform-state-access`
3. `create-view-privileged-activity`
4. `create-view-guardduty-findings`

## 🎯 Benefits of This Approach

✅ **Single deployment command** - No need to deploy Athena separately
✅ **Proper dependencies** - Athena waits for Security Lake to be ready
✅ **Centralized configuration** - All account IDs in one place
✅ **Consistent state** - Everything in same Terraform state file
✅ **Easier rollback** - Can rollback entire security stack together

## 🔧 Troubleshooting

### Query Fails: "Database not found"

**Cause**: Security Lake module hasn't created Glue database yet

**Solution**:
```bash
# Check if Security Lake deployed successfully
terraform state list | grep security-lake

# Verify Glue database exists
aws glue get-database --name amazon_security_lake_glue_db_us_east_1
```

### Query Returns No Results

**Cause**: No data in Security Lake or crawler hasn't run

**Solution**:
```bash
# Check if crawler has run
aws glue get-crawler --name security-lake-crawler

# Run crawler manually
aws glue start-crawler --name security-lake-crawler

# Wait 5-10 minutes, then try query again
```

### Module Not Found Error

**Cause**: Athena module path incorrect

**Solution**:
```bash
# Verify module structure
ls -la security-account/athena/
# Should show: main.tf, variables.tf, outputs.tf, providers.tf

# Re-initialize Terraform
cd security-account/backend-bootstrap
terraform init -upgrade
```

## 📝 Next Steps

1. ✅ Deploy: `cd security-account/backend-bootstrap && terraform apply`
2. ⏳ Create views: Run the 4 "create-view-*" queries in Athena console
3. ⏳ Test queries: Execute sample queries to verify data access
4. ⏳ Set up dashboards: Import queries into OpenSearch or QuickSight
5. ⏳ Configure alerts: Use EventBridge to trigger alerts on query results

## 📚 Related Documentation

- [README.md](./README.md) - Comprehensive Athena configuration guide
- [Backend Bootstrap](../backend-bootstrap/README.md) - Main deployment workflow
- [Security Lake](../security-lake/README.md) - OCSF data lake configuration

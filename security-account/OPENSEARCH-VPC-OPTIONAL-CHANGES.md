# OpenSearch Module Update - VPC Optional Configuration

**Date**: 2026-01-12
**Purpose**: Make VPC deployment optional for OpenSearch in security account

---

## 🎯 Changes Made

### Problem
The OpenSearch module required VPC, CIDR, and private subnet IDs which are not needed when deploying OpenSearch in the security account with public access.

### Solution
Made VPC configuration **optional** - OpenSearch can now be deployed either:
1. **With VPC** (private access) - For production workload accounts
2. **Without VPC** (public access with IP restrictions) - For security account

---

## 📝 Files Modified

### 1. `/security-account/opensearch/variables.tf`

**Changes:**
- Made `vpc_id` optional (default: `null`)
- Made `vpc_cidr` optional (default: `null`)
- Made `private_subnet_ids` optional (default: `null`)

**Before:**
```hcl
variable "private_subnet_ids" {
  description = "List of private subnet IDs for OpenSearch"
  type        = list(string)
}
```

**After:**
```hcl
variable "private_subnet_ids" {
  description = "List of private subnet IDs for OpenSearch (optional - leave null for public access)"
  type        = list(string)
  default     = null
}
```

### 2. `/security-account/opensearch/main.tf`

**Changes:**
- Security group creation is now conditional (only when `vpc_id != null`)
- VPC options block is now dynamic (only when `private_subnet_ids != null`)

**Before:**
```hcl
resource "aws_security_group" "opensearch" {
  name   = "opensearch-security-logs"
  vpc_id = var.vpc_id
  # ...
}

vpc_options {
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.opensearch.id]
}
```

**After:**
```hcl
resource "aws_security_group" "opensearch" {
  count = var.vpc_id != null ? 1 : 0

  name   = "opensearch-security-logs"
  vpc_id = var.vpc_id
  # ...
}

dynamic "vpc_options" {
  for_each = var.private_subnet_ids != null ? [1] : []
  content {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.opensearch[0].id]
  }
}
```

### 3. `/security-account/backend-bootstrap/main.tf`

**Changes:**
- Added comment explaining public access deployment
- No VPC variables passed to OpenSearch module

**Configuration:**
```hcl
module "opensearch" {
  source = "../opensearch"

  # Deploy OpenSearch with public access (no VPC/subnets needed in security account)
  # VPC variables are optional and default to null for public access deployment
}
```

---

## 🚀 Usage Examples

### Deployment Option 1: Public Access (Security Account)

```hcl
module "opensearch" {
  source = "./opensearch"

  # No VPC variables needed - deploys with public access
  # Access controlled via access policies and IP whitelisting
}
```

**Result:**
- ✅ OpenSearch accessible via public endpoint
- ✅ Access controlled by IAM policies
- ✅ Fine-grained access control enabled
- ✅ TLS encryption enforced
- ✅ No VPC/subnet costs

### Deployment Option 2: VPC Private Access (Workload Account)

```hcl
module "opensearch" {
  source = "./opensearch"

  # Provide VPC variables for private deployment
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr_block
  private_subnet_ids = module.vpc.private_subnet_ids
}
```

**Result:**
- ✅ OpenSearch in private subnets
- ✅ Security group restricts access to VPC
- ✅ No public endpoint
- ✅ VPC Flow Logs enabled

---

## 🔒 Security Considerations

### Public Access Deployment (Current for Security Account)

**Security Controls:**
1. **IAM Access Policies**: Restrict which AWS accounts/roles can access
2. **Fine-Grained Access Control**: Username/password authentication required
3. **TLS Encryption**: All traffic encrypted in transit (TLS 1.2+)
4. **Encryption at Rest**: Data encrypted with KMS
5. **CloudWatch Logging**: All access logged
6. **IP Whitelisting**: Can add IP-based restrictions in access policy

**Example Access Policy with IP Restriction:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::ACCOUNT_ID:root"
      },
      "Action": "es:*",
      "Resource": "arn:aws:es:REGION:ACCOUNT_ID:domain/security-logs/*",
      "Condition": {
        "IpAddress": {
          "aws:SourceIp": [
            "203.0.113.0/24",
            "198.51.100.0/24"
          ]
        }
      }
    }
  ]
}
```

### VPC Deployment (Recommended for Workload Account)

**Advantages:**
- ✅ Network isolation
- ✅ Private subnet deployment
- ✅ Security group controls
- ✅ No internet exposure
- ✅ VPC Flow Logs

**Disadvantages:**
- ❌ Requires VPC infrastructure
- ❌ NAT Gateway costs
- ❌ More complex networking
- ❌ Requires VPN/Direct Connect for external access

---

## 🧪 Testing

### Test Public Deployment

```bash
cd /Users/CaptGab/terraform-infra/security-account/backend-bootstrap

# Initialize
terraform init

# Plan (should show no VPC resources for OpenSearch)
terraform plan

# Look for in plan output:
# ✅ aws_opensearch_domain.security_logs will be created
# ✅ aws_kms_key.opensearch will be created
# ❌ No aws_security_group for OpenSearch (count = 0)
# ❌ No VPC options in OpenSearch domain
```

### Verify OpenSearch Endpoint

```bash
# After apply, get OpenSearch endpoint
terraform output opensearch_endpoint

# Should return public HTTPS endpoint like:
# https://search-security-logs-xxxxx.us-east-1.es.amazonaws.com

# Test access (requires credentials)
curl -X GET "https://search-security-logs-xxxxx.us-east-1.es.amazonaws.com" \
  -u "admin:PASSWORD_FROM_SECRETS_MANAGER"
```

---

## 📊 Cost Impact

### Before (VPC Deployment)
- OpenSearch instances: $X/month
- Security group: FREE
- NAT Gateway: ~$32/month (if required)
- **Total: $X + $32/month**

### After (Public Deployment in Security Account)
- OpenSearch instances: $X/month
- No VPC infrastructure costs
- **Total: $X/month**

**Savings: ~$32/month from NAT Gateway removal**

---

## ⚠️ Important Notes

### When to Use Each Deployment Type

| Scenario | Deployment Type | Reason |
|----------|----------------|--------|
| **Security Account** | Public Access | Central logging, accessed by security team only |
| **Workload Account** | VPC Private | Production data, requires network isolation |
| **Development** | Public Access | Cost savings, easier access for developers |
| **Compliance (PCI/HIPAA)** | VPC Private | Regulatory requirements for network isolation |

### Migration Path

If you need to migrate from public to VPC deployment later:

```hcl
# Step 1: Create VPC infrastructure
module "vpc" {
  source = "./vpc"
  # ...
}

# Step 2: Update OpenSearch module call
module "opensearch" {
  source = "./opensearch"

  # Add VPC variables
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr_block
  private_subnet_ids = module.vpc.private_subnet_ids
}

# Step 3: Terraform will recreate OpenSearch in VPC
terraform apply
```

---

## ✅ Summary

### What Changed
- ✅ VPC variables are now optional in OpenSearch module
- ✅ Security account deploys OpenSearch with public access
- ✅ No VPC/subnet infrastructure required
- ✅ Backward compatible - can still deploy in VPC if needed

### Benefits
- 💰 Cost savings (~$32/month from no NAT Gateway)
- 🚀 Simpler deployment (no VPC required)
- 🔧 Easier access for security team
- 🔄 Still supports VPC deployment when needed

### Security Maintained
- ✅ TLS encryption enforced
- ✅ Fine-grained access control enabled
- ✅ KMS encryption at rest
- ✅ CloudWatch logging enabled
- ✅ IAM-based access control

---

**Ready to deploy!** The OpenSearch module now works without VPC/subnet requirements in the security account.

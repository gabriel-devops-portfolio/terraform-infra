# Creating Resources in Member Accounts - Complete Guide

**Date**: 2026-01-12
**Purpose**: Step-by-step guide for deploying infrastructure to member accounts using OrganizationAccountAccessRole

---

## 🎯 Overview

Your member accounts (Security & Workload) have **full administrator access** via the `OrganizationAccountAccessRole`. This role is automatically created by AWS Organizations and has the `AdministratorAccess` managed policy attached.

### What You Can Do With This Role ✅

- ✅ Create EC2 instances, VPCs, subnets
- ✅ Deploy EKS clusters
- ✅ Create RDS databases
- ✅ Manage S3 buckets
- ✅ Create IAM users, roles, policies
- ✅ Configure CloudWatch, CloudTrail
- ✅ Deploy Lambda functions
- ✅ Set up load balancers
- ✅ **Everything** - Full admin access!

### What the Root Account SCP Does ⚠️

The Root Account SCP **ONLY** blocks the **root user** (root@email.com), not IAM roles:

- ❌ Root user: Blocked by SCP
- ✅ OrganizationAccountAccessRole: **Full admin access** (NOT affected by SCP)
- ✅ IAM users: Normal access (NOT affected by SCP)
- ✅ IAM roles: Normal access (NOT affected by SCP)

---

## Method 1: AWS Console (Switch Role) 🖥️

### Step-by-Step

1. **Login to Management Account**
   - Go to AWS Console
   - Login with your management account credentials

2. **Get Your Workload Account ID**
   ```bash
   cd /Users/CaptGab/terraform-infra/management-account
   terraform output workload_account_id
   # Output: 123456789012 (example)
   ```

3. **Switch Role in Console**
   - Click your account name (top-right corner)
   - Select **"Switch Role"**
   - Enter:
     - **Account**: `123456789012` (your workload account ID)
     - **Role**: `OrganizationAccountAccessRole`
     - **Display Name**: `Workload Admin` (optional, for easy identification)
     - **Color**: Choose a color (optional)
   - Click **"Switch Role"**

4. **Verify You're in the Member Account**
   - Top-right should show: `Workload Admin @ 123456789012`
   - You now have **FULL ADMIN ACCESS**

5. **Create Resources!**
   - Go to EC2 → Launch instance ✅ Works!
   - Go to VPC → Create VPC ✅ Works!
   - Go to S3 → Create bucket ✅ Works!
   - Go to IAM → Create user ✅ Works!

### Switch Back to Management Account

- Click account name → "Back to [Management Account Name]"

---

## Method 2: AWS CLI (Assume Role) 💻

### Step 1: Assume the Role

```bash
# Get account ID
cd /Users/CaptGab/terraform-infra/management-account
WORKLOAD_ACCOUNT_ID=$(terraform output -raw workload_account_id)

# Assume role
aws sts assume-role \
  --role-arn "arn:aws:iam::${WORKLOAD_ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name "admin-session" \
  --duration-seconds 3600

# Output will be JSON with credentials
```

### Step 2: Export Credentials

**Manual Method:**
```bash
# Copy from assume-role output
export AWS_ACCESS_KEY_ID="ASIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
```

**Automated Method (Recommended):**
```bash
# Create a helper script
cat > ~/assume-workload-role.sh <<'EOF'
#!/bin/bash
WORKLOAD_ACCOUNT_ID=$(cd /Users/CaptGab/terraform-infra/management-account && terraform output -raw workload_account_id)

CREDENTIALS=$(aws sts assume-role \
  --role-arn "arn:aws:iam::${WORKLOAD_ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name "admin-session" \
  --query 'Credentials' \
  --output json)

export AWS_ACCESS_KEY_ID=$(echo $CREDENTIALS | jq -r '.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $CREDENTIALS | jq -r '.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $CREDENTIALS | jq -r '.SessionToken')

echo "✅ Assumed role in workload account"
echo "Account: $WORKLOAD_ACCOUNT_ID"
echo "Session expires in 1 hour"
EOF

chmod +x ~/assume-workload-role.sh

# Use it:
source ~/assume-workload-role.sh
```

### Step 3: Create Resources

```bash
# Now you have admin access - create anything!

# List VPCs
aws ec2 describe-vpcs --region us-east-1

# Create VPC
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region us-east-1 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=my-vpc}]'

# Create S3 bucket
aws s3 mb s3://my-workload-bucket-12345 --region us-east-1

# List IAM roles
aws iam list-roles --query 'Roles[*].RoleName'

# Launch EC2 instance (example)
aws ec2 run-instances \
  --image-id ami-0c55b159cbfafe1f0 \
  --instance-type t3.micro \
  --region us-east-1
```

### Step 4: Return to Management Account

```bash
# Unset credentials
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

# Or close terminal and open new one
```

---

## Method 3: Terraform (RECOMMENDED) 🚀

This is the **best practice** for infrastructure deployment.

### Step 1: Configure Provider

Create a Terraform configuration that assumes the role:

```hcl
# File: workload-account/providers.tf

# Get account ID from management account state
data "terraform_remote_state" "org" {
  backend = "local"

  config = {
    path = "../management-account/terraform.tfstate"
  }
}

# Provider that assumes role in workload account
provider "aws" {
  region = "us-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::${data.terraform_remote_state.org.outputs.workload_account_id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-admin"
  }
}

# Optional: Provider for security account
provider "aws" {
  alias  = "security"
  region = "us-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::${data.terraform_remote_state.org.outputs.security_account_id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-security"
  }
}
```

### Step 2: Create Resources

```hcl
# File: workload-account/main.tf

# Create VPC in workload account (using default provider)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "workload-vpc"
    ManagedBy = "terraform"
  }
}

# Create S3 bucket in workload account
resource "aws_s3_bucket" "app_data" {
  bucket = "my-workload-app-data-${data.terraform_remote_state.org.outputs.workload_account_id}"

  tags = {
    Name      = "app-data"
    ManagedBy = "terraform"
  }
}

# Create IAM role in workload account
resource "aws_iam_role" "app_role" {
  name = "app-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Create security group in workload account
resource "aws_security_group" "app" {
  name        = "app-security-group"
  description = "Security group for application"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create EKS cluster in workload account
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "workload-eks"
  cluster_version = "1.28"

  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private[*].id

  # Full admin access via assumed role!
}

# Store logs in security account (cross-account)
resource "aws_s3_bucket" "audit_logs" {
  provider = aws.security  # Uses security account provider

  bucket = "audit-logs-${data.terraform_remote_state.org.outputs.security_account_id}"

  tags = {
    Name      = "audit-logs"
    ManagedBy = "terraform"
  }
}
```

### Step 3: Deploy

```bash
cd /Users/CaptGab/terraform-infra/workload-account

# Initialize
terraform init

# Plan (verify assume role works)
terraform plan

# Apply (create resources with full admin access!)
terraform apply
```

---

## Method 4: AWS Profile Configuration 📝

For permanent CLI access, configure AWS profiles:

### Step 1: Create Profile Configuration

```bash
# Edit ~/.aws/config
cat >> ~/.aws/config <<EOF

[profile workload-admin]
role_arn = arn:aws:iam::$(cd /Users/CaptGab/terraform-infra/management-account && terraform output -raw workload_account_id):role/OrganizationAccountAccessRole
source_profile = default
region = us-east-1

[profile security-admin]
role_arn = arn:aws:iam::$(cd /Users/CaptGab/terraform-infra/management-account && terraform output -raw security_account_id):role/OrganizationAccountAccessRole
source_profile = default
region = us-east-1
EOF
```

### Step 2: Use Profile

```bash
# Use workload account profile
aws s3 ls --profile workload-admin
aws ec2 describe-instances --profile workload-admin

# Use security account profile
aws s3 ls --profile security-admin

# Set as default for session
export AWS_PROFILE=workload-admin
aws s3 ls  # Now uses workload account automatically
```

---

## 🧪 Testing Your Access

Run the provided test script:

```bash
cd /Users/CaptGab/terraform-infra/management-account
chmod +x test-admin-access.sh
./test-admin-access.sh
```

**Expected Output:**
```
✅ Test 1: Verify OrganizationAccountAccessRole exists
✅ SUCCESS: Can assume OrganizationAccountAccessRole

✅ Test 2: Verify admin permissions (list VPCs)
✅ SUCCESS: Can list VPCs (has admin permissions)

✅ Test 3: Verify IAM admin permissions
✅ SUCCESS: Can access IAM (has admin permissions)

✅ Test 4: Verify S3 admin permissions
✅ SUCCESS: Can list S3 buckets (has admin permissions)

✅ All Tests Passed!
```

---

## 📊 Permissions Summary

| Access Method | Account | Permissions | Affected by Root SCP? |
|---------------|---------|-------------|----------------------|
| **Root User** | All | ❌ Blocked | ✅ YES - SCP blocks root |
| **OrganizationAccountAccessRole** | Member | ✅ FULL ADMIN | ❌ NO - SCP doesn't affect IAM roles |
| **IAM Users** | Member | ✅ Based on policies | ❌ NO - SCP doesn't affect IAM users |
| **IAM Roles** | Member | ✅ Based on policies | ❌ NO - SCP doesn't affect IAM roles |

---

## 🚨 Common Issues & Solutions

### Issue 1: "Access Denied" When Assuming Role

**Error:**
```
An error occurred (AccessDenied) when calling the AssumeRole operation
```

**Causes & Solutions:**

1. **Not in Management Account**
   ```bash
   # Check current account
   aws sts get-caller-identity

   # Should show management account ID
   ```

2. **Role Doesn't Exist Yet**
   ```bash
   # Deploy organization first
   cd management-account
   terraform apply
   ```

3. **Wrong Account ID**
   ```bash
   # Get correct account ID
   terraform output workload_account_id
   ```

### Issue 2: "Cannot Create Resources" Despite Assuming Role

**Check:**

1. **Verify you assumed the role correctly**
   ```bash
   aws sts get-caller-identity

   # Should show:
   # - Account: workload account ID
   # - Arn: ...assumed-role/OrganizationAccountAccessRole/...
   ```

2. **Check SCP isn't blocking (shouldn't be)**
   ```bash
   # SCPs only block root user, not IAM roles
   # OrganizationAccountAccessRole should work
   ```

3. **Region mismatch**
   ```bash
   # Specify region explicitly
   aws ec2 describe-vpcs --region us-east-1
   ```

---

## 📚 Real-World Examples

### Example 1: Deploy VPC in Workload Account

```bash
# Assume role
source ~/assume-workload-role.sh

# Create VPC
aws ec2 create-vpc \
  --cidr-block 10.0.0.0/16 \
  --region us-east-1 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=production-vpc}]'

# Create subnet
aws ec2 create-subnet \
  --vpc-id vpc-xxxxx \
  --cidr-block 10.0.1.0/24 \
  --availability-zone us-east-1a
```

### Example 2: Deploy S3 Bucket in Security Account

```bash
# Switch to security account
SECURITY_ACCOUNT_ID=$(cd /Users/CaptGab/terraform-infra/management-account && terraform output -raw security_account_id)

aws sts assume-role \
  --role-arn "arn:aws:iam::${SECURITY_ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name security-admin

# Create bucket for logs
aws s3 mb s3://security-logs-${SECURITY_ACCOUNT_ID} --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket security-logs-${SECURITY_ACCOUNT_ID} \
  --versioning-configuration Status=Enabled
```

### Example 3: Deploy EKS via Terraform

```hcl
# File: workload-account/eks.tf
provider "aws" {
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::${var.workload_account_id}:role/OrganizationAccountAccessRole"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "production-eks"
  cluster_version = "1.28"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Full admin access via OrganizationAccountAccessRole!

  eks_managed_node_groups = {
    general = {
      desired_size = 3
      min_size     = 2
      max_size     = 5

      instance_types = ["t3.medium"]
    }
  }
}
```

---

## ✅ Summary

### You Have Full Admin Access ✅

- **OrganizationAccountAccessRole**: Automatically created with full admin permissions
- **Root Account SCP**: Only blocks root user, NOT IAM roles
- **Can Create Resources**: EC2, VPC, S3, EKS, RDS, IAM, everything!

### Best Practices 🎯

1. **Use Terraform** for infrastructure deployment (Method 3)
2. **Use AWS Console** for quick testing (Method 1)
3. **Use AWS CLI profiles** for daily work (Method 4)
4. **Never use root account** for operations (blocked by SCP anyway)

### Next Steps 🚀

1. Test admin access: `./test-admin-access.sh`
2. Configure AWS CLI profiles for easy access
3. Deploy infrastructure using Terraform with assume_role
4. Monitor CloudTrail for all assumed role activity

---

**You're all set! Start deploying infrastructure to your member accounts with full admin access.** 🎉

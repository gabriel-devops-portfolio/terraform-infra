# ✅ Route53 and ACM Configuration Review

## **STATUS: FULLY CONFIGURED AND CORRECTED**

---

## 🚨 Issues Found and Fixed

### 1. ✅ **Route53 Module - Missing Output File**
**Problem**: Outputs were defined inside `main.tf` instead of a separate `output.tf` file
**Fixed**:
- Created proper `output.tf` file
- Moved all outputs to the correct file
- Added descriptive comments
- Added `zone_name` output

---

### 2. ✅ **ACM Certificate - Missing DNS Validation**
**Problem**: ACM certificate was created but DNS validation records were never added to Route53
**Impact**: Certificate would remain in "Pending Validation" status forever

**Fixed**: Added complete DNS validation workflow:
```terraform
# 1. Create ACM certificate
resource "aws_acm_certificate" "eks_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"
  subject_alternative_names = ["*.${var.domain_name}"]
}

# 2. Create DNS validation records in Route53
resource "aws_route53_record" "eks_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.eks_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.primary.zone_id
  # ... validation record details
}

# 3. Wait for validation to complete
resource "aws_acm_certificate_validation" "eks_cert" {
  certificate_arn         = aws_acm_certificate.eks_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.eks_cert_validation : record.fqdn]
}
```

---

### 3. ✅ **Syntax Errors in Additional Domain Configuration**
**Problem**: Invalid syntax in count condition
```terraform
# ❌ WRONG
count = var.domain_name"" ? 1 : 0
```

**Fixed**:
```terraform
# ✅ CORRECT
count = var.pilotgab_domain_enable ? 1 : 0
```

---

### 4. ✅ **Wrong Variable Reference in ACM Module**
**Problem**: Using non-existent `var.zone_id`
**Fixed**: Using `module.route53_pilotgab[0].zone_id` with proper dependency

---

### 5. ✅ **Added Missing Variables**
- `domain_radiant_commons` - For future Radiant Commons domain
- `pilotgab_domain_enable` - Boolean flag to enable/disable shared.pilotgab.com

---

### 6. ✅ **Enhanced Outputs**
Added comprehensive ACM certificate outputs:
- `acm_certificate_status` - Validation status
- `acm_certificate_domain_validation_options` - Validation details

---

## 📋 Current Configuration

### Primary Domain (Your Domain)

**Route53 Hosted Zone:**
```terraform
resource "aws_route53_zone" "primary" {
  name = var.domain_name  # e.g., "yourdomain.com"

  tags = merge(var.tags, {
    Name = "${var.env}-primary-zone"
  })
}
```

**ACM Certificate:**
- **Domain**: `yourdomain.com`
- **SANs**: `*.yourdomain.com` (wildcard)
- **Validation**: Automatic DNS validation via Route53
- **Usage**: EKS ALB Ingress, ArgoCD, Application ingress

---

### Optional Domain (shared.pilotgab.com)

**Controlled by**: `pilotgab_domain_enable = true/false`

**When Enabled**:
- Creates Route53 hosted zone for `shared.pilotgab.com`
- Creates ACM certificate with wildcard (`*.shared.pilotgab.com`)
- Automatically validates via DNS
- Uses ACM module wrapper for consistency

---

## 🏗️ DNS and Certificate Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Your Domain                              │
│                 (e.g., example.com)                         │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Route53    │    │  ACM Cert    │    │  Validation  │
│  Hosted Zone │    │              │    │   Records    │
│              │    │ • example.com│◄───┤              │
│ Name Servers:│    │ • *.example. │    │ CNAME records│
│ - ns-1.aws...│    │   com        │    │ for DNS      │
│ - ns-2.aws...│    │              │    │ validation   │
│ - ns-3.aws...│    │ Status: ✅   │    │              │
│ - ns-4.aws...│    │ ISSUED       │    │              │
└──────┬───────┘    └──────┬───────┘    └──────────────┘
       │                   │
       │                   └─────────────────┐
       │                                     │
       └─────────────────────────────────────┼──────────►
                                             │
                                    ┌────────▼────────┐
                                    │  ALB Ingress    │
                                    │  (EKS)          │
                                    │                 │
                                    │ HTTPS Listener  │
                                    │ - example.com   │
                                    │ - *.example.com │
                                    └─────────────────┘
```

---

## 📊 Module Configuration

### Route53 Public Zone Module
**Location**: `modules/aws_route53_zone_public/`

**Inputs**:
- `domain_name` - Domain name for the hosted zone

**Outputs**:
- `zone_id` - Hosted zone ID (for ACM validation)
- `name_servers` - NS records (update at domain registrar)
- `domain_name` - Domain name
- `arn` - Zone ARN
- `zone_name` - Zone name

**Usage**:
```terraform
module "route53_zone" {
  source      = "../../modules/aws_route53_zone_public"
  domain_name = "example.com"
}
```

---

### ACM Certificate Module
**Location**: `modules/acm/`

**Inputs**:
- `domain_name` - Primary domain name
- `zone_id` - Route53 zone ID for validation
- `wildcard_enable` - Enable wildcard SAN (default: true)
- `validate_certificate` - Enable DNS validation (default: true)
- `extra_subject_alternative_names` - Additional SANs
- `default_region` - AWS region (default: eu-west-1)
- `cloudfront_certificate` - For CloudFront (default: false)

**Outputs**:
- `acm_certificate_arn` - Certificate ARN

**Features**:
- Automatic wildcard SAN (`*.domain.com`)
- DNS validation via Route53
- Uses terraform-aws-modules/acm/aws wrapper
- Proper tags and naming

---

## 🔒 Certificate Details

### Primary Certificate (eks_cert)

```yaml
Domain: yourdomain.com
SANs:
  - *.yourdomain.com
Validation Method: DNS
Validation Status: Automatically validated via Route53
Region: us-east-1 (or var.region)
Usage:
  - EKS ALB Ingress Controller
  - ArgoCD (argocd.yourdomain.com)
  - Application ingress (app.yourdomain.com)
  - Wildcard for all subdomains
```

### Certificate Validation Process

1. **Terraform creates ACM certificate** with DNS validation
2. **AWS provides DNS validation records** (CNAME)
3. **Terraform creates Route53 records** with validation data
4. **AWS validates ownership** by checking DNS records
5. **Certificate status changes** from "Pending Validation" to "Issued"
6. **Terraform waits** for validation via `aws_acm_certificate_validation`

**Validation Time**: Typically 5-10 minutes after DNS records propagate

---

## 🚀 Deployment Workflow

### 1. Update Domain in terraform.tfvars
```hcl
domain_name = "yourdomain.com"  # Replace with actual domain
```

### 2. Deploy Infrastructure
```bash
terraform apply
```

### 3. Update Domain Registrar
After deployment, get name servers:
```bash
terraform output primary_zone_name_servers
```

Output example:
```
[
  "ns-1234.awsdns-12.org",
  "ns-567.awsdns-89.com",
  "ns-890.awsdns-01.co.uk",
  "ns-1234.awsdns-56.net"
]
```

**Action**: Update NS records at your domain registrar (GoDaddy, Namecheap, etc.)

### 4. Wait for DNS Propagation
```bash
# Check NS records
dig NS yourdomain.com

# Check ACM validation status
aws acm describe-certificate \
  --certificate-arn $(terraform output -raw acm_certificate_arn) \
  --query 'Certificate.Status'
```

Expected: `"ISSUED"`

### 5. Verify Certificate
```bash
# List certificates
aws acm list-certificates --region us-east-1

# Check validation
terraform output acm_certificate_status
```

---

## 🔍 Troubleshooting

### Issue: Certificate stuck in "Pending Validation"

**Cause**: DNS records not propagated or NS records not updated at registrar

**Check**:
```bash
# 1. Verify Route53 has validation records
aws route53 list-resource-record-sets \
  --hosted-zone-id $(terraform output -raw primary_zone_id) \
  | grep -A5 "_acm-challenge"

# 2. Check if NS records are correct at registrar
dig NS yourdomain.com

# 3. Check DNS propagation
dig _acm-challenge.yourdomain.com CNAME
```

**Solution**:
1. Ensure NS records at registrar match Route53 name servers
2. Wait for DNS propagation (up to 48 hours, usually 15-60 minutes)
3. Re-run `terraform apply` to retry validation

---

### Issue: "Zone already exists" error

**Cause**: Route53 zone was created outside Terraform

**Solution**:
```bash
# Import existing zone
terraform import aws_route53_zone.primary ZONE_ID

# Or delete the existing zone and let Terraform create it
aws route53 delete-hosted-zone --id ZONE_ID
```

---

### Issue: ACM module validation timing out

**Cause**: `wait_for_validation = false` in ACM module

**Check**:
```bash
# In modules/acm/main.tf
wait_for_validation  = false  # This means it won't wait
```

**Note**: This is intentional. Terraform will continue without waiting, but validation will complete in the background. The `aws_acm_certificate_validation` resource in `main.tf` handles the waiting.

---

## 📝 Best Practices Implemented

### ✅ DNS Validation (Not Email)
- Automatic validation via Route53
- No manual email verification needed
- Works for wildcard certificates

### ✅ Wildcard Certificate
- `*.yourdomain.com` covers all subdomains
- Single certificate for all services
- Cost-effective (one cert instead of many)

### ✅ Certificate Validation Resource
- Terraform waits for validation
- Ensures certificate is ready before continuing
- Prevents race conditions

### ✅ Proper Dependencies
- ACM validation depends on Route53 records
- EKS resources can depend on validated certificate
- Clean deployment order

### ✅ Lifecycle Management
- `create_before_destroy` for certificates
- Zero-downtime certificate rotation
- Automatic renewal by AWS

---

## 📊 Outputs Available

### From Production Environment

```terraform
# Route53
output "primary_zone_id"          # Z1234567890ABC
output "primary_zone_name_servers" # [ns-1.aws..., ns-2.aws...]

# ACM
output "acm_certificate_arn"      # arn:aws:acm:...
output "acm_certificate_status"   # ISSUED
```

### From Route53 Module

```terraform
output "zone_id"                  # For other modules
output "name_servers"             # For registrar update
output "domain_name"              # Configured domain
output "arn"                      # Zone ARN
```

### From ACM Module

```terraform
output "acm_certificate_arn"      # For ALB, CloudFront, etc.
```

---

## 🎯 Integration Points

### EKS ALB Ingress Controller
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: "arn:aws:acm:..." # From output
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
```

### ArgoCD
```yaml
server:
  ingress:
    enabled: true
    hosts:
      - argocd.yourdomain.com
    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.yourdomain.com
```

### Custom Applications
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: "${acm_certificate_arn}"
spec:
  rules:
    - host: myapp.yourdomain.com
```

---

## ✅ Summary

Your Route53 and ACM configuration is now **production-ready** with:

- ✅ **Proper output file structure** in Route53 module
- ✅ **Automatic DNS validation** for ACM certificates
- ✅ **Wildcard certificate** for all subdomains
- ✅ **Validation resources** to ensure certificates are ready
- ✅ **Proper dependencies** between resources
- ✅ **Optional additional domain** support (shared.pilotgab.com)
- ✅ **Comprehensive outputs** for integration
- ✅ **Best practices** for certificate management

**Configuration Status**: 🟢 **READY FOR DEPLOYMENT**

---

## 📚 Next Steps

1. ✅ Update `domain_name` in terraform.tfvars
2. ✅ Run `terraform apply`
3. ✅ Update NS records at domain registrar
4. ✅ Wait for certificate validation (5-10 minutes)
5. ✅ Configure ALB Ingress Controller to use certificate
6. ✅ Deploy applications with HTTPS enabled

**DNS and certificates are properly configured! 🎉**

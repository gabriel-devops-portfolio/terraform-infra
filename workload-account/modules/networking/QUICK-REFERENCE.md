# 🚀 Quick Deployment Reference

## Required Variables

```hcl
module "networking" {
  source = "./modules/networking"

  env    = "production"  # or "staging", "dev"
  region = "us-east-1"
  
  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # Workload VPC (Spoke)
  workload_vpc_cidr          = "10.0.0.0/16"
  workload_private_subnets   = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  workload_database_subnets  = ["10.0.48.0/24", "10.0.49.0/24", "10.0.50.0/24"]

  # Egress VPC (Hub)
  egress_vpc_cidr            = "10.1.0.0/16"
  egress_public_subnets      = ["10.1.0.0/24", "10.1.1.0/24", "10.1.2.0/24"]
  firewall_subnets           = ["10.1.10.0/28", "10.1.10.16/28", "10.1.10.32/28"]
  tgw_subnets                = ["10.1.10.48/28", "10.1.10.64/28", "10.1.10.80/28"]

  enable_nat = true

  tags = {
    Project     = "MyApp"
    ManagedBy   = "Terraform"
    CostCenter  = "Engineering"
  }
}
```

---

## Subnet Sizing Guide

| Purpose | Size | IPs Available | Use Case |
|---------|------|---------------|----------|
| Workload Private | `/20` | 4,096 | EKS nodes, pods, internal services |
| Database | `/24` | 256 | RDS, Aurora, DocumentDB |
| Public (NAT) | `/24` | 256 | NAT Gateways only |
| Firewall | `/28` | 16 | AWS Network Firewall endpoints |
| TGW | `/28` | 16 | Transit Gateway attachments |

---

## Traffic Flow Summary

### ✅ Egress (Workload → Internet)
1. **EKS Pod** → Private subnet route table
2. → **Transit Gateway** (via TGW attachment)
3. → **TGW Subnet** in Egress VPC
4. → **Network Firewall** (allowlist check)
5. → **NAT Gateway** (public subnet)
6. → **Internet Gateway** → Internet

### ✅ Ingress (Internet → Workload)
1. **Internet** → Internet Gateway
2. → **IGW Edge Route Table** (ingress inspection)
3. → **Network Firewall** (inspection)
4. → **Transit Gateway**
5. → **Workload VPC** → ALB/NLB → EKS

---

## Outputs Available

```hcl
# VPC IDs
workload_vpc_id
egress_vpc_id

# Subnets (pass to compute module)
workload_private_subnets
egress_public_subnets

# Transit Gateway
tgw_id

# Firewall
firewall_name
firewall_policy_arn

# VPC Endpoints (for SCP enforcement)
vpce_secretsmanager_id
vpce_kms_id
vpce_s3_id
```

---

## Post-Deployment Validation

### 1. Check TGW Attachments
```bash
aws ec2 describe-transit-gateway-attachments \
  --filters "Name=state,Values=available"
```

### 2. Check Firewall Status
```bash
aws network-firewall describe-firewall \
  --firewall-name production-egress-firewall
```

### 3. Check Route Tables
```bash
# Workload VPC should have 0.0.0.0/0 → TGW
aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=*workload*"

# Should show default route to Transit Gateway
```

### 4. Test Egress Filtering
```bash
# Deploy test pod in EKS
kubectl run test-curl --image=curlimages/curl -it --rm -- sh

# Inside pod:
curl -I https://github.com              # ✅ Should work
curl -I https://example.com             # ❌ Should fail (not in allowlist)
curl -I https://s3.amazonaws.com        # ✅ Should work
```

---

## Firewall Allowlist Management

### Add New Domains
Edit `routes.firewall.tf`:

```hcl
resource "aws_networkfirewall_rule_group" "egress_allowlist" {
  # ...existing code...
  
  rule_group {
    rules_source {
      rules_source_list {
        targets = [
          ".amazonaws.com",
          ".github.com",
          ".githubusercontent.com",
          ".docker.elastic.co",
          ".ghcr.io",
          
          # ADD YOUR DOMAINS HERE
          ".yourdomain.com",
          ".npmjs.org",          # For npm packages
          ".pythonhosted.org",   # For pip packages
        ]
      }
    }
  }
}
```

### Monitor Blocked Traffic
```bash
# View firewall logs
aws logs tail /aws/networkfirewall/production-egress-firewall --follow

# Filter for drops
aws logs tail /aws/networkfirewall/production-egress-firewall \
  --filter-pattern "DROP" \
  --follow
```

---

## Common Integration Patterns

### Pass Outputs to Compute Module
```hcl
module "compute" {
  source = "./modules/compute"

  vpc_id          = module.networking.workload_vpc_id
  private_subnets = module.networking.workload_private_subnets
  
  # ...other variables...
}
```

### Add Additional Spoke VPCs
```hcl
# In transit-gtw.tf, add:
resource "aws_ec2_transit_gateway_vpc_attachment" "workload_2" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = module.workload_vpc_2.vpc_id
  subnet_ids         = module.workload_vpc_2.private_subnets
}

# Add route in TGW route table
resource "aws_ec2_transit_gateway_route" "return_to_workload_2" {
  destination_cidr_block         = module.workload_vpc_2.vpc_cidr
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.inspection.id
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.workload_2.id
}
```

---

## Cost Estimation (us-east-1)

### Monthly Costs (approximate)
- **NAT Gateways**: $32.85 × 3 AZs = **$98.55**
- **Network Firewall**: $0.395/hr × 730hrs = **$288.35**
- **Transit Gateway**: $0.05/attachment/hr × 2 × 730hrs = **$73.00**
- **TGW Data Processing**: ~$0.02/GB (variable)
- **VPC Endpoints**: ~$7.20/endpoint/month × 15 = **$108.00**

**Total Base Cost**: ~**$567/month** (before data transfer)

💡 **Cost Optimization**: This is a shared infrastructure cost. As you add more workload VPCs, the per-workload cost decreases.

---

## Troubleshooting

### Issue: No internet access from workload VPC
**Check**:
1. Route table has 0.0.0.0/0 → TGW ✅
2. TGW attachment is in "available" state ✅
3. Firewall has allowlist entry for your domain ✅
4. Security groups allow egress ✅

```bash
# Verify route
aws ec2 describe-route-tables \
  --route-table-ids <workload-rt-id> \
  | jq '.RouteTables[].Routes'
```

### Issue: Firewall blocking legitimate traffic
**Check firewall logs**:
```bash
aws logs tail /aws/networkfirewall/production-egress-firewall \
  --filter-pattern "DROP" \
  --since 10m
```

Add the domain to allowlist in `routes.firewall.tf`.

### Issue: High data transfer costs
**Monitor**:
```bash
# Check TGW bytes processed
aws cloudwatch get-metric-statistics \
  --namespace AWS/TransitGateway \
  --metric-name BytesIn \
  --dimensions Name=TransitGateway,Value=<tgw-id> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-07T00:00:00Z \
  --period 3600 \
  --statistics Sum
```

---

## Security Checklist

- [x] No IGW in workload VPC
- [x] No NAT in workload VPC
- [x] Firewall fail-close policy
- [x] VPC Flow Logs enabled
- [x] Firewall change protection
- [x] VPC endpoint policies (S3, KMS, Secrets)
- [x] Multi-AZ deployment
- [x] TGW inspection mode enabled
- [ ] Enable GuardDuty (optional)
- [ ] Enable Network Firewall alert logs (optional)
- [ ] Add CloudWatch alarms (recommended)

---

## Next Steps

1. ✅ **Deploy networking module**
2. ✅ **Verify TGW attachments and routes**
3. ✅ **Deploy compute module** (pass networking outputs)
4. ✅ **Test egress filtering** from EKS pods
5. ✅ **Set up monitoring** (CloudWatch alarms)
6. ✅ **Enable firewall logs** for audit trail
7. ✅ **Document approved domains** for firewall allowlist

---

**Questions?** Check the [ARCHITECTURE-REVIEW.md](./ARCHITECTURE-REVIEW.md) for detailed explanations.

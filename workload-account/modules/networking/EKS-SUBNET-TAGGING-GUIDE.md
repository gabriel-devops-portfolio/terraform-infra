# EKS Subnet Tagging Strategy - Configuration Review

## Overview
This document explains the Kubernetes/EKS subnet tagging strategy for the hub-and-spoke VPC architecture and why tags are applied differently to workload VPC vs egress VPC.

---

## ✅ Configuration Status: PRODUCTION-READY

### Subnet Tagging ✓
- **Workload VPC Private Subnets**: ✅ Tagged for EKS internal load balancers, Karpenter discovery
- **Workload VPC Database Subnets**: ✅ Tagged for RDS identification
- **Egress VPC Subnets**: ✅ No EKS tags (correct - no workloads run here)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    Hub & Spoke Architecture                   │
└──────────────────────────────────────────────────────────────┘

┌────────────────────────────┐      ┌──────────────────────────┐
│   Workload VPC (Spoke)     │      │   Egress VPC (Hub)       │
│   10.10.0.0/16             │      │   10.0.0.0/16            │
│                            │      │                          │
│  ┌──────────────────────┐  │      │  ┌────────────────────┐ │
│  │ Private Subnets      │  │      │  │ Public Subnets     │ │
│  │ - 10.10.0.0/24       │  │      │  │ - 10.0.0.0/24      │ │
│  │ - 10.10.1.0/24       │  │      │  │ - 10.0.1.0/24      │ │
│  │ - 10.10.2.0/24       │  │      │  │ - 10.0.2.0/24      │ │
│  │                      │  │      │  │                    │ │
│  │ EKS Tags:            │  │      │  │ NO EKS Tags        │ │
│  │ ✅ k8s.io/role/     │  │      │  │ (No workloads)     │ │
│  │    internal-elb     │  │      │  │                    │ │
│  │ ✅ k8s.io/cluster/  │  │      │  └────────────────────┘ │
│  │    prod-eks-cluster │  │      │                          │
│  │ ✅ karpenter.sh/    │  │      │  ┌────────────────────┐ │
│  │    discovery        │  │      │  │ Firewall Subnets   │ │
│  │                      │  │      │  │ - 10.0.16.0/28     │ │
│  │ Contains:            │  │      │  │ - 10.0.17.0/28     │ │
│  │ - EKS nodes          │  │      │  │ - 10.0.18.0/28     │ │
│  │ - EKS pods           │  │      │  │                    │ │
│  │ - ALB/NLB            │  │      │  │ NO EKS Tags        │ │
│  └──────────────────────┘  │      │  │ (Inspection only)  │ │
│                            │      │  └────────────────────┘ │
│  ┌──────────────────────┐  │      │                          │
│  │ Database Subnets     │  │      │  ┌────────────────────┐ │
│  │ - 10.10.32.0/28      │  │      │  │ TGW Subnets        │ │
│  │ - 10.10.33.0/28      │  │      │  │ - 10.0.19.0/28     │ │
│  │ - 10.10.34.0/28      │  │      │  │ - 10.0.20.0/28     │ │
│  │                      │  │      │  │ - 10.0.21.0/28     │ │
│  │ Tags:                │  │      │  │                    │ │
│  │ ✅ network-tier=    │  │      │  │ NO EKS Tags        │ │
│  │    database         │  │      │  │ (Routing only)     │ │
│  │                      │  │      │  └────────────────────┘ │
│  │ NO EKS Tags          │  │      │                          │
│  │ (Database only)      │  │      │                          │
│  └──────────────────────┘  │      └──────────────────────────┘
└────────────────────────────┘
```

---

## EKS Subnet Tags Explained

### Why These Tags Matter

Kubernetes and AWS services use these tags to automatically discover subnets for resource placement:

1. **`kubernetes.io/cluster/<cluster-name>`**: Identifies subnets belonging to a specific EKS cluster
2. **`kubernetes.io/role/internal-elb`**: Tells AWS Load Balancer Controller to use these subnets for internal ALB/NLB
3. **`kubernetes.io/role/elb`**: Tells AWS Load Balancer Controller to use these subnets for public ALB/NLB
4. **`karpenter.sh/discovery`**: Tells Karpenter which subnets to launch nodes in

---

## Workload VPC - Private Subnet Tags ✅

### Configuration
```hcl
private_subnet_tags = {
  "kubernetes.io/role/internal-elb"     = "1"
  "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  "karpenter.sh/discovery"              = "${var.cluster_name}"
}
```

### Applied Tags (Example for prod-eks-cluster)
```
kubernetes.io/role/internal-elb     = "1"
kubernetes.io/cluster/prod-eks-cluster = "shared"
karpenter.sh/discovery              = "prod-eks-cluster"
```

### Purpose

#### 1. `kubernetes.io/role/internal-elb = "1"`
**Used by**: AWS Load Balancer Controller

**What it does**:
- Identifies subnets for **internal** Application Load Balancers (ALB) and Network Load Balancers (NLB)
- When you create a Kubernetes Service with `type: LoadBalancer` and annotation `service.beta.kubernetes.io/aws-load-balancer-internal: "true"`, the AWS Load Balancer Controller creates the load balancer in these subnets

**Example**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: internal-app
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
  - port: 80
```
**Result**: Internal NLB created in private subnets (10.10.0.0/24, 10.10.1.0/24, 10.10.2.0/24)

---

#### 2. `kubernetes.io/cluster/prod-eks-cluster = "shared"`
**Used by**: EKS, Kubernetes Cloud Provider

**What it does**:
- Identifies subnets that belong to the EKS cluster
- Value `"shared"` means subnets can be used by multiple clusters (vs `"owned"`)
- Required for Kubernetes to manage AWS resources (security groups, load balancers, etc.)

**Why "shared"?**:
- Future-proof: Allows multiple clusters to coexist
- Network design: Hub-and-spoke may serve multiple workload clusters
- Best practice: Unless subnets are dedicated to a single cluster, use "shared"

---

#### 3. `karpenter.sh/discovery = "prod-eks-cluster"`
**Used by**: Karpenter (Kubernetes autoscaler)

**What it does**:
- Tells Karpenter which subnets to launch EC2 instances (nodes) in
- Karpenter discovers subnets automatically using this tag
- No need to hardcode subnet IDs in Karpenter configuration

**Karpenter Provisioner Example**:
```yaml
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["spot", "on-demand"]
  # Subnets auto-discovered via karpenter.sh/discovery tag
  # No need to specify subnet IDs manually!
```

**Result**: Karpenter launches nodes in private subnets (10.10.0.0/24, 10.10.1.0/24, 10.10.2.0/24)

---

## Workload VPC - Database Subnet Tags ✅

### Configuration
```hcl
database_subnet_tags = {
  "network-tier" = "database"
}
```

### Purpose
- **NO EKS tags**: Database subnets should NOT have EKS tags
- **Reason**: RDS instances should not be confused with EKS resources
- **Tag purpose**: Organizational identification only

**What NOT to do**:
```hcl
# ❌ WRONG - Do NOT add EKS tags to database subnets
database_subnet_tags = {
  "kubernetes.io/role/internal-elb" = "1"  # ❌ NO
  "karpenter.sh/discovery" = "..."         # ❌ NO
}
```

**Why?**:
- Karpenter might try to launch nodes in database subnets
- Load balancers might be created in database subnets
- Violates network segmentation best practices

---

## Egress VPC - No EKS Tags ✅

### Configuration
```hcl
# Public subnets
public_subnet_tags = {
  "Network" = "Public"
  "Tier"    = "Egress"
}

# Firewall/TGW subnets (intra subnets)
intra_subnet_tags = {
  "Network" = "Inspection"
  "Tier"    = "Firewall-TGW"
}
```

### Purpose
- **NO EKS tags**: Egress VPC has no workloads
- **Function**: Inspection and egress routing only
- **Components**: NAT Gateways, Network Firewall, Transit Gateway

**What NOT to do**:
```hcl
# ❌ WRONG - Do NOT add EKS tags to egress VPC
public_subnet_tags = {
  "kubernetes.io/role/elb" = "1"  # ❌ NO - No workloads here
}
```

**Why?**:
- No EKS nodes run in egress VPC
- No EKS load balancers should be created here
- Hub-and-spoke separation: workloads stay in spoke (workload VPC)

---

## Public vs Internal Load Balancers

### When to Use `kubernetes.io/role/elb` (Public)?

If you need **internet-facing** load balancers, you would:

1. Create public subnets in workload VPC (currently not done - by design)
2. Tag them with `kubernetes.io/role/elb = "1"`
3. Deploy public-facing services

**Example Configuration** (if needed):
```hcl
# In workload VPC module (NOT currently implemented)
public_subnets = ["10.10.240.0/24", "10.10.241.0/24", "10.10.242.0/24"]

public_subnet_tags = {
  "kubernetes.io/role/elb" = "1"
  "kubernetes.io/cluster/${var.cluster_name}" = "shared"
}
```

**Current Architecture**: ❌ No public subnets in workload VPC (by design)

**Reason**: Hub-and-spoke with centralized egress (zero-trust)

---

### Current Architecture: Internal-Only Load Balancers

**Design Decision**: All EKS load balancers are **internal**

**Traffic Flow for External Access**:
```
Internet → Egress VPC (Public Subnet) → ALB/CloudFront
    ↓
Firewall Inspection
    ↓
Transit Gateway
    ↓
Workload VPC (Private Subnet) → EKS Internal NLB → Pods
```

**If you need external access**:
1. Deploy ALB/CloudFront in egress VPC public subnets
2. Point to internal NLB in workload VPC
3. Traffic inspected by Network Firewall

---

## Tag Value Format

### `kubernetes.io/cluster/<cluster-name> = "shared"`

**Values**:
- `"shared"`: Subnets can be used by multiple clusters
- `"owned"`: Subnets are exclusively owned by one cluster

**When to use each**:

#### Use `"shared"` (Recommended):
- ✅ Subnets serve multiple EKS clusters
- ✅ Future-proof (might add more clusters later)
- ✅ Hub-and-spoke architecture
- ✅ Cost optimization (shared networking resources)

#### Use `"owned"`:
- ⚠️ Subnets are dedicated to one cluster
- ⚠️ Cluster has full control over subnet resources
- ⚠️ More aggressive cleanup (deletes resources on cluster deletion)

**Current Configuration**: ✅ `"shared"` (correct for hub-and-spoke)

---

## Variable Configuration

### Networking Module Variable
```hcl
variable "cluster_name" {
  description = "EKS cluster name for subnet tagging"
  type        = string
  default     = ""
}
```

**Default behavior**: If not provided, uses `"${var.env}-cluster"`

---

### Production Environment Configuration
```hcl
locals {
  cluster_name = "${var.env}-eks-cluster"
}

module "network" {
  source = "../../modules/networking"

  cluster_name = local.cluster_name  # "prod-eks-cluster"

  # ... other config
}
```

**Result**: Subnets tagged with `kubernetes.io/cluster/prod-eks-cluster`

---

## Validation Checklist

### ✅ Workload VPC Private Subnets
- [x] `kubernetes.io/role/internal-elb = "1"` → For internal load balancers
- [x] `kubernetes.io/cluster/prod-eks-cluster = "shared"` → For EKS cluster association
- [x] `karpenter.sh/discovery = "prod-eks-cluster"` → For Karpenter node placement

### ✅ Workload VPC Database Subnets
- [x] `network-tier = "database"` → For organizational tagging
- [x] NO EKS tags → Prevents workload placement

### ✅ Egress VPC Subnets
- [x] NO EKS tags → No workloads run here
- [x] Organizational tags only → For identification

---

## AWS Load Balancer Controller Behavior

### How It Discovers Subnets

When you create a Kubernetes Service with `type: LoadBalancer`, the AWS Load Balancer Controller:

1. **Looks for cluster tag**: `kubernetes.io/cluster/<cluster-name> = "shared" | "owned"`
2. **Checks load balancer type**:
   - Internal: Looks for `kubernetes.io/role/internal-elb = "1"`
   - Public: Looks for `kubernetes.io/role/elb = "1"`
3. **Selects subnets**: Chooses all subnets with matching tags across multiple AZs

---

### Example: Creating Internal NLB

**Kubernetes Service**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-internal: "true"
spec:
  type: LoadBalancer
  selector:
    app: myapp
  ports:
  - port: 80
    targetPort: 8080
```

**AWS Load Balancer Controller Decision Process**:
```
1. Cluster name: prod-eks-cluster
2. Load balancer type: Internal (annotation)
3. Search for subnets with:
   - kubernetes.io/cluster/prod-eks-cluster = "shared"
   - kubernetes.io/role/internal-elb = "1"
4. Found subnets:
   - 10.10.0.0/24 (us-east-1a) ✅
   - 10.10.1.0/24 (us-east-1b) ✅
   - 10.10.2.0/24 (us-east-1c) ✅
5. Create NLB across these 3 subnets
```

**Result**: Internal NLB with private IPs in workload VPC

---

## Karpenter Node Placement

### How Karpenter Discovers Subnets

Karpenter automatically discovers subnets using the `karpenter.sh/discovery` tag:

**Karpenter Controller Logic**:
```
1. Read provisioner configuration
2. Look for tag: karpenter.sh/discovery = <cluster-name>
3. Find all subnets in VPC with this tag
4. Launch nodes in discovered subnets (round-robin across AZs)
```

---

### Example: Karpenter Node Launch

**Provisioner Configuration**:
```yaml
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["on-demand"]
    - key: node.kubernetes.io/instance-type
      operator: In
      values: ["m6i.large", "m6i.xlarge"]
  limits:
    resources:
      cpu: 1000
  # Subnets auto-discovered via karpenter.sh/discovery tag
```

**Karpenter Discovery Process**:
```
1. Cluster name: prod-eks-cluster
2. Search for subnets with:
   - karpenter.sh/discovery = "prod-eks-cluster"
3. Found subnets:
   - subnet-abc123 (10.10.0.0/24, us-east-1a) ✅
   - subnet-def456 (10.10.1.0/24, us-east-1b) ✅
   - subnet-ghi789 (10.10.2.0/24, us-east-1c) ✅
4. Launch nodes in these subnets
```

**Result**: Nodes spread across 3 AZs in workload VPC private subnets

---

## Common Issues & Troubleshooting

### Issue 1: Load Balancer Not Created

**Symptom**: Kubernetes Service stuck in `Pending` state
```bash
kubectl get svc my-app
NAME     TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)
my-app   LoadBalancer   10.100.1.5    <pending>     80:30123/TCP
```

**Possible Causes**:
1. Missing subnet tags
2. Wrong cluster name in tags
3. No subnets with appropriate role tag

**Troubleshooting**:
```bash
# Check AWS Load Balancer Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify subnet tags
aws ec2 describe-subnets \
  --filters "Name=tag:kubernetes.io/cluster/prod-eks-cluster,Values=shared" \
  --query 'Subnets[*].[SubnetId,Tags]'
```

**Fix**: Ensure subnets have correct tags (applied automatically with this configuration)

---

### Issue 2: Karpenter Not Launching Nodes

**Symptom**: Pods stuck in `Pending`, Karpenter not scaling
```bash
kubectl get pods
NAME                READY   STATUS    RESTARTS   AGE
my-app-abc123-xyz   0/1     Pending   0          5m
```

**Possible Causes**:
1. Missing `karpenter.sh/discovery` tag
2. Wrong cluster name
3. Insufficient capacity

**Troubleshooting**:
```bash
# Check Karpenter logs
kubectl logs -n karpenter deployment/karpenter

# Check for subnet discovery errors
# Look for: "discovered subnets" in logs

# Verify subnet tags
aws ec2 describe-subnets \
  --filters "Name=tag:karpenter.sh/discovery,Values=prod-eks-cluster" \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,CidrBlock]'
```

**Fix**: Ensure subnets have `karpenter.sh/discovery` tag (applied automatically)

---

### Issue 3: Nodes Launched in Wrong Subnets

**Symptom**: Karpenter launches nodes in database subnets

**Root Cause**: Database subnets mistakenly tagged with `karpenter.sh/discovery`

**Prevention**: ✅ Already handled - database subnets have NO EKS tags

---

## Migration Notes

### If Cluster Name Changes

If you rename the cluster, subnet tags must be updated:

**Old Tags**:
```
kubernetes.io/cluster/old-cluster-name = "shared"
karpenter.sh/discovery = "old-cluster-name"
```

**New Tags** (after renaming):
```
kubernetes.io/cluster/new-cluster-name = "shared"
karpenter.sh/discovery = "new-cluster-name"
```

**How to update**:
1. Change `cluster_name` variable in production environment
2. Run `terraform plan` to see tag changes
3. Run `terraform apply` to update subnet tags
4. Restart AWS Load Balancer Controller and Karpenter

---

## Best Practices ✓

### Implemented ✅
- [x] Use `cluster_name` variable for consistency
- [x] Tag only workload subnets with EKS tags
- [x] Exclude database subnets from EKS discovery
- [x] Exclude egress VPC subnets from EKS discovery
- [x] Use `"shared"` cluster tag value for flexibility
- [x] Include all three required tags (cluster, role, karpenter)

### Recommended
- [ ] Document cluster name in deployment guide
- [ ] Add CloudWatch alarms for load balancer creation failures
- [ ] Monitor Karpenter node placement across AZs
- [ ] Periodic audit of subnet tags (automation)

---

## Summary

### Tag Configuration Summary

| Subnet Type | VPC | EKS Tags | Purpose |
|------------|-----|----------|---------|
| Private Subnets | Workload | ✅ Yes | EKS nodes, pods, internal LBs |
| Database Subnets | Workload | ❌ No | RDS only, no workloads |
| Public Subnets | Egress | ❌ No | NAT, no workloads |
| Firewall Subnets | Egress | ❌ No | Inspection only |
| TGW Subnets | Egress | ❌ No | Routing only |

### Required Tags for EKS Subnets

1. **`kubernetes.io/cluster/<cluster-name> = "shared"`**
   - Required for EKS cluster association
   - Value: `"shared"` for multi-cluster support

2. **`kubernetes.io/role/internal-elb = "1"`**
   - Required for internal load balancers
   - AWS Load Balancer Controller uses this

3. **`karpenter.sh/discovery = "<cluster-name>"`**
   - Required for Karpenter autoscaling
   - Tells Karpenter where to launch nodes

### ✅ Configuration Status: COMPLETE

All subnet tags are correctly configured for:
- ✅ AWS Load Balancer Controller discovery
- ✅ Karpenter node placement
- ✅ EKS cluster resource management
- ✅ Network segmentation (database, egress isolated)

---

**Last Updated**: January 4, 2026
**Module Version**: 1.0
**EKS Version**: 1.31

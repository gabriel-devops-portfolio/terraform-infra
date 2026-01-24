# Karpenter Deployment & Scaling Readiness Check

## ✅ Configuration Alignment Summary

### 1. Terraform Infrastructure (Production main.tf)
- ✅ Cluster Name: `pilotgab-prod` (via `local.cluster_name`)
- ✅ Instance Profile: `KarpenterNodeInstanceProfile-pilotgab-prod`
- ✅ IRSA Role: `pilotgab-prod-Karpenter-IRSA`
- ✅ Discovery Tags: `karpenter.sh/discovery = pilotgab-prod`
  - Applied to EKS cluster
  - Applied to private subnets (via networking module)
  - Applied to node security group (via EKS module)

### 2. Karpenter Helm Chart (gitops-apps/prod/apps/apps-karpenter.yaml)
- ✅ Cluster Name: `pilotgab-prod`
- ✅ Instance Profile: `KarpenterNodeInstanceProfile-pilotgab-prod`
- ✅ IRSA Role ARN: `arn:aws:iam::290793900072:role/pilotgab-prod-Karpenter-IRSA`
- ⚠️ **ACTION REQUIRED**: Cluster Endpoint: `REPLACE_WITH_YOUR_EKS_CLUSTER_ENDPOINT`

### 3. EC2NodeClasses (karpenter/node-class.yaml)
- ✅ Instance Profile: `KarpenterNodeInstanceProfile-pilotgab-prod`
- ✅ Discovery Tags: `karpenter.sh/discovery: pilotgab-prod`
- ⚠️ **ISSUE**: Hardcoded AMI: `ami-04bcf82576ac8eb1c`
- ⚠️ **SECURITY**: `kubelet-custom` has `httpTokens: optional` (should be `required`)

### 4. NodePools (karpenter/node-pool.yaml)
- ✅ Namespace: `karpenter`
- ✅ Node Labels: `node.type: production`, `env: production`
- ✅ References: `kubelet-custom` EC2NodeClass

---

## 🚀 Deployment Flow (Step-by-Step)

### Phase 1: Terraform Infrastructure
```bash
cd workload-account/environments/production

# 1. Initialize and validate
terraform init
terraform validate

# 2. Plan to review resources
terraform plan

# Expected new resources:
# + aws_iam_policy.karpenter_controller
# + aws_iam_role_policy_attachment.karpenter_ssm_policy
# + aws_iam_instance_profile.karpenter
# + module.karpenter_irsa (IAM role)

# 3. Apply infrastructure
terraform apply
```

**Verify Terraform Outputs:**
```bash
# Get cluster endpoint
terraform output -raw kubernetes_cluster_endpoint

# Get OIDC provider ARN
terraform output -raw oidc_provider_arn

# Verify instance profile exists
aws iam get-instance-profile \
  --instance-profile-name KarpenterNodeInstanceProfile-pilotgab-prod

# Verify IRSA role exists
aws iam get-role --role-name pilotgab-prod-Karpenter-IRSA
```

### Phase 2: Update Karpenter Helm Values
```bash
# Get your actual EKS cluster endpoint
CLUSTER_ENDPOINT=$(aws eks describe-cluster \
  --name pilotgab-prod \
  --region us-east-1 \
  --query 'cluster.endpoint' \
  --output text)

echo "Cluster Endpoint: $CLUSTER_ENDPOINT"

# Update gitops-apps/prod/apps/apps-karpenter.yaml
# Replace: REPLACE_WITH_YOUR_EKS_CLUSTER_ENDPOINT
# With: $CLUSTER_ENDPOINT (e.g., https://ABC123.gr7.us-east-1.eks.amazonaws.com)
```

### Phase 3: Deploy Karpenter Helm Chart via ArgoCD
```bash
# Commit updated apps-karpenter.yaml to GitOps repo
cd gitops-apps/prod/apps
git add apps-karpenter.yaml
git commit -m "feat: configure Karpenter for pilotgab-prod cluster"
git push

# Apply ArgoCD Application manifest
kubectl apply -f apps-karpenter.yaml

# Or if using ArgoCD CLI:
argocd app create karpenter \
  --repo https://github.com/your-org/gitops-apps.git \
  --path prod/apps \
  --dest-namespace karpenter \
  --dest-server https://kubernetes.default.svc \
  --sync-policy automated
```

**Wait for Karpenter controller to be ready:**
```bash
# Watch deployment
kubectl get pods -n karpenter -w

# Expected output:
# NAME                         READY   STATUS    RESTARTS   AGE
# karpenter-xxxxxxxxxx-xxxxx   1/1     Running   0          30s

# Check controller logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=50

# Look for:
# ✅ "successfully created kubernetes client"
# ✅ "discovered subnets: [subnet-xxx, subnet-yyy, subnet-zzz]"
# ✅ "discovered security groups: [sg-xxxxx]"
# ❌ If you see permission errors, check IRSA role
```

**Verify IRSA annotation on service account:**
```bash
kubectl get sa karpenter -n karpenter -o yaml | grep eks.amazonaws.com/role-arn

# Expected:
# eks.amazonaws.com/role-arn: arn:aws:iam::290793900072:role/pilotgab-prod-Karpenter-IRSA
```

### Phase 4: Deploy Karpenter Provisioners (NodePools + EC2NodeClasses)
```bash
# Option A: Copy files to GitOps repo
cp karpenter/node-class.yaml gitops-apps/prod/karpenter/
cp karpenter/node-pool.yaml gitops-apps/prod/karpenter/

git add gitops-apps/prod/karpenter/
git commit -m "feat: add Karpenter NodePools and EC2NodeClasses"
git push

# Then apply apps-karpenter-provisioners.yaml via ArgoCD

# Option B: Apply directly (for testing)
kubectl apply -f karpenter/node-class.yaml
kubectl apply -f karpenter/node-pool.yaml
```

**Verify provisioners are created:**
```bash
# Check EC2NodeClasses
kubectl get ec2nodeclass -n karpenter

# Expected:
# NAME              AGE
# default           10s
# kubelet-custom    10s
# penumbra-nodes    10s

# Check NodePools
kubectl get nodepool -n karpenter

# Expected:
# NAME              AGE
# default-fleet     10s
# on-demand-fleet   10s
# penumbra          10s
# spot-fleet        10s

# Describe a NodePool to verify configuration
kubectl describe nodepool penumbra
```

### Phase 5: Test Autoscaling
```bash
# Deploy a test workload with high resource requests
kubectl create deployment inflate \
  --image=public.ecr.aws/eks-distro/kubernetes/pause:3.7 \
  --replicas=0

kubectl scale deployment inflate --replicas=10

kubectl set resources deployment inflate \
  --requests=cpu=1,memory=1Gi

# Watch Karpenter create nodes
kubectl get nodes -w

# Watch Karpenter controller logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f

# Expected log output:
# "created launch template lt-xxxxx"
# "launching instance i-xxxxx"
# "registered node ip-10-0-x-x.ec2.internal"
```

---

## 🔍 How Karpenter Will Scale Successfully

### Discovery Process
1. **Controller starts** → Reads `clusterName: pilotgab-prod` from Helm values
2. **Discovers subnets** → Queries AWS for subnets tagged `karpenter.sh/discovery: pilotgab-prod`
3. **Discovers security groups** → Queries AWS for SGs tagged `karpenter.sh/discovery: pilotgab-prod`
4. **Reads NodePools** → Watches for unschedulable pods matching NodePool requirements

### Scaling Trigger
1. **Pod pending** → Scheduler can't place pod on existing nodes
2. **Karpenter evaluates** → Checks which NodePool can satisfy pod requirements
3. **Selects instance type** → Uses pricing API to find cheapest matching instance
4. **Creates launch template** → Uses EC2NodeClass spec (AMI, block devices, userdata)
5. **Launches instance** → Calls `ec2:RunInstances` with instance profile `KarpenterNodeInstanceProfile-pilotgab-prod`
6. **Node joins cluster** → Uses IAM role from instance profile to authenticate via aws-auth ConfigMap
7. **Pod scheduled** → Kubernetes scheduler places pod on new node

### IAM Flow
```
Pod Pending
    ↓
Karpenter Controller (uses IRSA role: pilotgab-prod-Karpenter-IRSA)
    ↓
AWS API Calls:
  - ec2:RunInstances (launch instance)
  - iam:PassRole (pass KarpenterNodeInstanceProfile-pilotgab-prod to instance)
    ↓
New EC2 Instance (uses instance profile: KarpenterNodeInstanceProfile-pilotgab-prod)
    ↓
Node IAM Role Permissions:
  - EKS Worker (join cluster)
  - ECR Read (pull images)
  - SSM (optional management)
    ↓
Node Joins Cluster → Pod Scheduled
```

---

## ⚠️ Critical Issues to Fix Before Deployment

### 1. Hardcoded AMI ID (High Priority)
**Problem**: `ami-04bcf82576ac8eb1c` may not exist or be outdated in us-east-1

**Fix Option A** (Recommended): Use SSM Parameter
```yaml
# Update all 3 EC2NodeClasses in node-class.yaml
amiSelectorTerms:
  - alias: al2@latest  # Automatically uses latest EKS-optimized AL2 AMI
```

**Fix Option B**: Get latest AMI ID
```bash
aws ssm get-parameter \
  --name /aws/service/eks/optimized-ami/1.31/amazon-linux-2/recommended/image_id \
  --region us-east-1 \
  --query 'Parameter.Value' \
  --output text

# Update all amiSelectorTerms with new AMI ID
```

### 2. IMDSv2 Not Enforced on `kubelet-custom` (Security)
**Problem**: `httpTokens: optional` allows IMDSv1 (security risk)

**Fix**: Update `node-class.yaml` line ~75:
```yaml
# In kubelet-custom EC2NodeClass
metadataOptions:
  httpEndpoint: enabled
  httpPutResponseHopLimit: 2
  httpTokens: required  # Change from 'optional' to 'required'
```

### 3. No KMS Encryption on EBS Volumes (Security)
**Problem**: EBS volumes not encrypted with KMS

**Fix**: Add to all EC2NodeClasses:
```yaml
blockDeviceMappings:
  - deviceName: /dev/xvda
    ebs:
      volumeSize: 150Gi
      volumeType: gp3
      deleteOnTermination: true
      encrypted: true
      kmsKeyID: arn:aws:kms:us-east-1:290793900072:key/YOUR_KMS_KEY_ID
```

Get KMS key ARN:
```bash
cd workload-account/environments/production
terraform output -raw eks_kms_key_arn
```

### 4. Missing Cluster Endpoint
**Problem**: `REPLACE_WITH_YOUR_EKS_CLUSTER_ENDPOINT` placeholder

**Fix**: Run command from Phase 2 and update `apps-karpenter.yaml`

---

## ✅ Pre-Deployment Checklist

### Terraform
- [ ] Run `terraform plan` and review Karpenter IAM resources
- [ ] Run `terraform apply` to create IAM policy, role, instance profile
- [ ] Verify instance profile exists: `aws iam get-instance-profile --instance-profile-name KarpenterNodeInstanceProfile-pilotgab-prod`
- [ ] Verify IRSA role exists: `aws iam get-role --role-name pilotgab-prod-Karpenter-IRSA`

### Discovery Tags
- [ ] Verify subnets tagged:
  ```bash
  aws ec2 describe-subnets \
    --filters "Name=tag:karpenter.sh/discovery,Values=pilotgab-prod" \
    --region us-east-1 \
    --query 'Subnets[*].[SubnetId,AvailabilityZone]' \
    --output table
  ```
- [ ] Verify security group tagged:
  ```bash
  aws ec2 describe-security-groups \
    --filters "Name=tag:karpenter.sh/discovery,Values=pilotgab-prod" \
    --region us-east-1 \
    --query 'SecurityGroups[*].[GroupId,GroupName]' \
    --output table
  ```

### Karpenter Helm Chart
- [ ] Get cluster endpoint: `aws eks describe-cluster --name pilotgab-prod --region us-east-1 --query 'cluster.endpoint' --output text`
- [ ] Update `apps-karpenter.yaml` with actual cluster endpoint
- [ ] Verify IRSA role ARN matches: `arn:aws:iam::290793900072:role/pilotgab-prod-Karpenter-IRSA`
- [ ] Verify instance profile matches: `KarpenterNodeInstanceProfile-pilotgab-prod`

### EC2NodeClasses & NodePools
- [ ] Update AMI selector to use `alias: al2@latest` or latest AMI ID
- [ ] Fix `httpTokens: required` on `kubelet-custom`
- [ ] Add KMS encryption to all block device mappings
- [ ] Verify discovery tags: `karpenter.sh/discovery: pilotgab-prod`

### Network & Firewall
- [ ] Verify TGW routes allow egress to AWS APIs:
  - ec2.us-east-1.amazonaws.com
  - sts.us-east-1.amazonaws.com
  - pricing.us-east-1.amazonaws.com
  - ssm.us-east-1.amazonaws.com
  - ecr.us-east-1.amazonaws.com (ECR API and dkr.ecr)
  - s3.us-east-1.amazonaws.com

---

## 🎯 Expected Outcome

After completing all phases, you will have:

1. **Karpenter controller running** in `karpenter` namespace
2. **4 NodePools** ready to provision nodes:
   - `penumbra`: Compute-optimized, 30-day lifecycle
   - `on-demand-fleet`: Mixed families, on-demand
   - `spot-fleet`: Mixed families, spot instances
   - `default-fleet`: Tainted, 15-min lifecycle
3. **3 EC2NodeClasses** defining node configurations:
   - `penumbra-nodes`: Custom userdata, 100Gi disk
   - `default`: IMDSv2, 250Gi disk
   - `kubelet-custom`: Custom kubelet config, 150Gi disk

**When a pod is pending:**
- Karpenter will automatically create a node matching pod requirements
- Node will join cluster within 2-3 minutes
- Pod will be scheduled on the new node
- When nodes are underutilized, Karpenter will consolidate workloads

---

## 🐛 Troubleshooting

### Controller not starting
```bash
kubectl describe pod -n karpenter -l app.kubernetes.io/name=karpenter
# Check Events for errors
```

### Permission errors in logs
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter | grep -i "error\|denied"

# Common issues:
# - IRSA role not created
# - Wrong role ARN in service account annotation
# - Missing PassRole permission
```

### Nodes not launching
```bash
# Check if subnets/SGs discovered
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter | grep -i "discovered"

# Check NodePool status
kubectl get nodepool -n karpenter -o yaml

# Check EC2NodeClass status
kubectl get ec2nodeclass -n karpenter -o yaml
```

### AMI not found errors
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter | grep -i "ami"

# Fix: Update to alias: al2@latest or valid AMI ID for us-east-1
```

---

## 📚 Summary

Your Karpenter configuration is **90% ready** to scale successfully. The alignment between Terraform, Helm values, and provisioner manifests is correct.

**Critical actions before deployment:**
1. ✅ Update cluster endpoint in `apps-karpenter.yaml`
2. ⚠️ Fix hardcoded AMI (use `alias: al2@latest`)
3. ⚠️ Enforce IMDSv2 (`httpTokens: required`)
4. 📝 Optional: Add KMS encryption to EBS volumes

Once deployed, Karpenter will:
- ✅ Discover subnets and security groups via `karpenter.sh/discovery: pilotgab-prod` tags
- ✅ Use IRSA role `pilotgab-prod-Karpenter-IRSA` for AWS API calls
- ✅ Launch nodes with instance profile `KarpenterNodeInstanceProfile-pilotgab-prod`
- ✅ Automatically scale nodes based on pending pod requirements
- ✅ Consolidate underutilized nodes to save costs

# ArgoCD Deployment - Quick Reference

## ✅ Configuration Review Complete

**Status**: ✅ **PRODUCTION-READY**
**Date**: January 4, 2026

---

## What Was Fixed

### **1. Module Configuration**
- ✅ **Added wait settings** - `wait = true`, `timeout = 600`
- ✅ **Updated chart version** - 7.8.23 (was 5.43.4)
- ✅ **Fixed variable types** - `enableLocalRedis` now bool (was string)
- ✅ **Added outputs** - 4 new outputs for namespace, status, version
- ✅ **Fixed provider config** - Moved to root module (best practice)
- ✅ **Updated versions** - AWS 5.0+, Terraform 1.5+

### **2. Values File Created**
- ✅ **Created** `k8s-manifest/argocd-values.yaml`
- ✅ **High Availability** - Replicas + autoscaling
- ✅ **AWS ALB Integration** - Internal load balancer
- ✅ **GitHub OAuth** - Optional SSO configuration
- ✅ **RBAC** - Least privilege by default
- ✅ **Resource Limits** - CPU/memory constraints
- ✅ **Security** - Non-root containers

### **3. Documentation**
- ✅ **Complete README** - 900+ lines
- ✅ **Deployment guide** - Step-by-step
- ✅ **Troubleshooting** - Common issues
- ✅ **Maintenance** - Upgrade procedures

---

## Pre-Deployment Checklist

### **Prerequisites** ✅

- [x] EKS cluster deployed (`module.kubernetes`)
- [ ] AWS Load Balancer Controller installed
- [ ] Route53 hosted zone configured
- [ ] ACM certificate created
- [ ] GitHub OAuth app created (optional)

### **Required Variables**

Check `terraform.tfvars`:
```hcl
# ArgoCD
argocd_version         = "7.8.23"
github_oauth_client_id = ""  # Optional: Add your GitHub OAuth Client ID
domain_name            = "yourdomain.com"
```

---

## Deployment Commands

### **Step 1: Install AWS Load Balancer Controller**

```bash
# Create IAM policy for ALB controller
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Create IRSA for ALB controller
eksctl create iamserviceaccount \
  --cluster=prod-eks-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve

# Install ALB controller
helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=prod-eks-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### **Step 2: Deploy ArgoCD**

```bash
cd /Users/CaptGab/CascadeProjects/terraform-infra/organization/workload-account/environments/production

# Plan
terraform plan -target=module.argocd

# Apply
terraform apply -target=module.argocd
```

**Expected Time**: 5-10 minutes

### **Step 3: Verify Deployment**

```bash
# Check Helm release
helm list -n argocd

# Check pods (wait for all to be Running)
kubectl get pods -n argocd -w

# Check ingress (wait for ADDRESS to populate)
kubectl get ingress -n argocd

# Get ALB DNS
kubectl get ingress argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### **Step 4: Create Route53 Record**

```bash
# Get ALB ARN
ALB_ARN=$(kubectl get ingress argocd-server -n argocd -o jsonpath='{.metadata.annotations.alb\.ingress\.kubernetes\.io/arn}')

# Get ALB Hosted Zone ID
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].CanonicalHostedZoneId' \
  --output text)

# Get ALB DNS name
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --load-balancer-arns $ALB_ARN \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

# Create Route53 record (or add via Terraform)
aws route53 change-resource-record-sets \
  --hosted-zone-id <YOUR_ZONE_ID> \
  --change-batch '{
    "Changes": [{
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "argocd.yourdomain.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "'$ALB_ZONE_ID'",
          "DNSName": "'$ALB_DNS'",
          "EvaluateTargetHealth": true
        }
      }
    }]
  }'
```

### **Step 5: Access ArgoCD**

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Open in browser
open https://argocd.yourdomain.com

# Or use CLI
argocd login argocd.yourdomain.com --username admin --password <password>

# Change admin password
argocd account update-password
```

---

## Post-Deployment

### **1. Configure GitHub OAuth** (Optional)

```bash
# Create secret with GitHub client secret
kubectl -n argocd create secret generic dex-github-secret \
  --from-literal=clientSecret='<your-github-client-secret>'

# Update terraform.tfvars
github_oauth_client_id = "<your-github-client-id>"

# Redeploy
terraform apply -target=module.argocd
```

### **2. Add Git Repository**

```bash
argocd repo add https://github.com/your-org/your-repo \
  --username <username> \
  --password <github-token>
```

### **3. Create First Application**

```bash
argocd app create my-app \
  --repo https://github.com/your-org/your-repo \
  --path kubernetes/manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

### **4. Configure Slack Notifications** (Optional)

```bash
kubectl -n argocd create secret generic argocd-notifications-secret \
  --from-literal=slack-token='<slack-bot-token>'

kubectl patch configmap argocd-notifications-cm -n argocd --patch '
data:
  service.slack: |
    token: $slack-token
'
```

---

## Verification Checklist

- [ ] All pods in `argocd` namespace are Running
- [ ] Ingress has ADDRESS (ALB DNS name)
- [ ] Can access https://argocd.yourdomain.com
- [ ] Can login with admin credentials
- [ ] Changed admin password
- [ ] Added Git repository
- [ ] Created test application
- [ ] Application synced successfully

---

## Quick Commands

```bash
# List all applications
argocd app list

# Get application details
argocd app get <app-name>

# Sync application
argocd app sync <app-name>

# View application logs
argocd app logs <app-name>

# Delete application
argocd app delete <app-name>

# Port-forward to ArgoCD server (if no ingress)
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

---

## Troubleshooting

### **Pods Not Starting**
```bash
kubectl get events -n argocd --sort-by='.lastTimestamp'
kubectl logs -n argocd deploy/argocd-server
```

### **Can't Access UI**
```bash
kubectl get ingress -n argocd
kubectl describe ingress argocd-server -n argocd
```

### **Application Not Syncing**
```bash
argocd app get <app-name>
kubectl logs -n argocd deploy/argocd-repo-server
```

---

## Module Files

```
modules/argocd-helm/
├── README.md           # ✅ Complete documentation (900+ lines)
├── main.tf             # ✅ Helm release with wait/timeout
├── input.tf            # ✅ Updated variables
├── outputs.tf          # ✅ NEW - 4 outputs
├── versions.tf         # ✅ Updated to AWS 5.0+
└── auth.tf             # ✅ Provider notes

environments/production/
├── main.tf             # ✅ Calls argocd module
├── terraform.tfvars    # ✅ Configure argocd_version
└── k8s-manifest/
    └── argocd-values.yaml  # ✅ NEW - Complete config
```

---

## Summary

### **Configuration Status** ✅

| Component | Status |
|-----------|--------|
| Helm Release | ✅ Configured with wait/timeout |
| Values File | ✅ Created (HA + ALB + OAuth) |
| Outputs | ✅ Added 4 outputs |
| Provider Auth | ✅ Fixed (moved to root) |
| Versions | ✅ Updated (AWS 5.0+) |
| Documentation | ✅ Complete (900+ lines) |

### **Features** ✅

- ✅ High Availability (replicas + autoscaling)
- ✅ AWS Load Balancer integration (internal)
- ✅ GitHub OAuth SSO (optional)
- ✅ RBAC with least privilege
- ✅ Resource limits
- ✅ Security hardening
- ✅ Notifications ready

### **Ready to Deploy!** 🚀

Run:
```bash
terraform apply -target=module.argocd
```

**Your ArgoCD module is production-ready for GitOps!** 🎉

---

**Last Updated**: January 4, 2026
**Status**: ✅ Production-Ready

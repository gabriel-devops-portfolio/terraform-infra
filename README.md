# AWS Multi-Account Terraform Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Organization-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📋 Overview

Enterprise-grade AWS multi-account infrastructure managed with Terraform, implementing AWS best practices for security, compliance, and workload isolation. This project establishes a complete AWS Organization with centralized security monitoring, cross-account access controls, and production-ready Kubernetes environments.

### Key Features

- ✅ **Multi-Account AWS Organization** with hierarchical OUs
- 🔒 **Centralized Security Account** for logging and compliance
- 🚀 **Production & Staging Environments** with EKS clusters
- 📊 **ArgoCD GitOps** deployment for continuous delivery
- 🛡️ **Service Control Policies (SCPs)** for governance
- 🔐 **Cross-Account IAM Roles** with least privilege access
- 📦 **Remote State Management** with S3 + DynamoDB locking
- 🌐 **Hub-and-Spoke Network Architecture** with Transit Gateway
- 📈 **Comprehensive Monitoring** with Prometheus, Grafana, and CloudWatch

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        AWS ORGANIZATION                              │
│                      (Management Account)                            │
│                                                                       │
│  ┌────────────────────┐              ┌────────────────────┐        │
│  │   Security OU      │              │   Workloads OU     │        │
│  │                    │              │                    │        │
│  │  ┌──────────────┐  │              │  ┌──────────────┐ │        │
│  │  │ Security Acct│  │              │  │ Workload Acct│ │        │
│  │  │ 404068503087 │  │              │  │ 290793900072 │ │        │
│  │  │              │  │              │  │              │ │        │
│  │  │ • CloudTrail │  │              │  │ • Prod EKS   │ │        │
│  │  │ • GuardDuty  │  │              │  │ • Staging    │ │        │
│  │  │ • SecurityHub│  │              │  │ • RDS        │ │        │
│  │  │ • Config     │  │              │  │ • S3 Buckets │ │        │
│  │  │ • Audit Logs │  │              │  │ • ArgoCD     │ │        │
│  │  │ • TF State   │  │◄─────────────┤  │ • Networking │ │        │
│  │  └──────────────┘  │  Cross-      │  └──────────────┘ │        │
│  │                    │  Account     │                    │        │
│  └────────────────────┘  Roles       └────────────────────┘        │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure

```
terraform-infra/organization/
├── management-account/          # AWS Organization & SCPs
│   ├── org-account.tf          # Organization setup
│   ├── outputs.tf              # Organization outputs
│   ├── variables.tf            # Configuration variables
│   └── README.md               # Management account docs
│
├── security-account/           # Centralized Security Hub
│   ├── backend-bootstrap/      # Remote state infrastructure
│   │   ├── bucket-state.tf     # S3 backend bucket
│   │   ├── bucket-policy.tf    # Access policies
│   │   ├── dynamodb.tf         # State locking table
│   │   └── kms.tf              # Encryption keys
│   │
│   └── cross-account-roles/    # IAM roles for security services
│       ├── iam-roles.tf        # 10 security roles
│       ├── s3-buckets.tf       # Log aggregation buckets
│       ├── kms.tf              # Log encryption keys
│       └── README.md           # Security setup guide
│
├── workload-account/           # Application workloads
│   ├── cross-account-roles/    # Trust relationships
│   │   └── iam-roles.tf        # 8 cross-account roles
│   │
│   ├── environments/
│   │   ├── production/         # Production environment
│   │   │   ├── main.tf         # EKS, RDS, networking
│   │   │   ├── backend.tf      # Remote state config
│   │   │   ├── terraform.tfvars# Environment variables
│   │   │   └── k8s-manifest/   # Kubernetes manifests
│   │   │
│   │   └── staging/            # Staging environment
│   │       └── main.tf         # Staging resources
│   │
│   └── modules/                # Reusable Terraform modules
│       ├── networking/         # Hub-and-spoke VPC, TGW, NAT
│       ├── eks/                # EKS cluster module
│       ├── data/               # RDS, S3 data layer
│       ├── security/           # Security groups, NACLs
│       ├── argocd-helm/        # ArgoCD deployment
│       ├── irsa/               # IAM roles for service accounts
│       ├── kms/                # KMS encryption keys
│       ├── acm/                # SSL/TLS certificates
│       ├── eks-roles/          # Kubernetes RBAC roles
│       └── rbac/               # Fine-grained access control
│
└── argocd/                     # Standalone ArgoCD infrastructure
    ├── argocd.tf               # Helm chart deployment
    ├── vpc-eks.tf              # Dedicated EKS cluster
    ├── monitoring.tf           # Prometheus + Grafana
    └── README.md               # ArgoCD setup guide
```

---

## 🔐 Security Architecture

### Accounts

| Account Type | Account ID | Purpose | Key Services |
|-------------|-----------|---------|--------------|
| **Management** | Root | Organization admin | AWS Organizations, SCPs |
| **Security** | 404068503087 | Security & compliance | CloudTrail, GuardDuty, SecurityHub, Config |
| **Workload** | 290793900072 | Application runtime | EKS, RDS, VPC, ArgoCD |

### Cross-Account Roles

#### Security Account (10 Roles)
1. **TerraformExecutionRole** - Infrastructure automation
2. **GuardDutyOrganizationAdminRole** - Threat detection
3. **SecurityHubOrganizationAdminRole** - Security findings
4. **ConfigAggregatorRole** - Compliance monitoring
5. **SecurityLakeRole** - Security data lake (OCSF)
6. **SecurityLakeSubscriberRole** - Query security data
7. **DetectiveOrganizationAdminRole** - Security investigations
8. **CloudWatchLogsReceiverRole** - Log aggregation
9. **AthenaSecurityQueryRole** - SQL queries on logs
10. **OpenSearchSecurityRole** - Log visualization

#### Workload Account (8 Roles)
1. **TerraformExecutionRole** - Terraform operations
2. **GuardDutyMemberRole** - GuardDuty integration
3. **SecurityHubMemberRole** - SecurityHub integration
4. **ConfigAggregateAuthorization** - Config data sharing
5. **SecurityLakeQueryRole** - Security data access
6. **CloudWatchLogsSenderRole** - Log forwarding
7. **BackupRole** - AWS Backup operations
8. **InspectorRole** - Vulnerability scanning

### Centralized Logging

All logs flow to the Security Account:

- 📋 **CloudTrail Logs** (7-year retention)
- 🌊 **VPC Flow Logs** (1-year retention)
- 🛡️ **Security Lake** (OCSF format, 2-year retention)
- 📊 **Athena Query Results** (90-day retention)

---

## 🌐 Network Architecture

### Hub-and-Spoke Topology

```
┌─────────────────────────────────────────────────────┐
│              Workload VPC (Spoke)                   │
│              CIDR: 10.0.0.0/16                      │
│                                                      │
│  ┌──────────────┐  ┌──────────────┐                │
│  │   Private    │  │   Database   │                │
│  │   Subnets    │  │   Subnets    │                │
│  │ • EKS Nodes  │  │ • RDS        │                │
│  │ • Apps       │  │ • ElastiCache│                │
│  └──────┬───────┘  └──────────────┘                │
│         │                                            │
│         └─────────────┬──────────────────┐          │
│                       │                  │          │
│              ┌────────▼───────┐          │          │
│              │ Transit Gateway│          │          │
│              └────────┬───────┘          │          │
│                       │                  │          │
└───────────────────────┼──────────────────┼──────────┘
                        │                  │
┌───────────────────────▼──────────────────▼──────────┐
│               Egress VPC (Hub)                       │
│               CIDR: 10.1.0.0/16                      │
│                                                      │
│  ┌──────────────┐  ┌──────────────┐                │
│  │   Public     │  │   Firewall   │                │
│  │   Subnets    │  │   Subnets    │                │
│  │ • NAT GW     │  │ • AWS Network│                │
│  │ • ALB        │  │   Firewall   │                │
│  └──────────────┘  └──────────────┘                │
│                                                      │
│          Internet Gateway                           │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
              INTERNET
```

**Key Features:**
- Multi-AZ deployment for high availability
- Network Firewall for outbound traffic inspection
- Transit Gateway for scalable VPC connectivity
- Private subnets for workloads (no direct internet access)
- NAT Gateway in hub VPC for controlled egress

---

## 🚀 Workload Environments

### Production Environment

**EKS Cluster Configuration:**
- Kubernetes Version: 1.28
- Node Groups: 2 managed node groups (3-10 nodes)
- Instance Types: t3.medium, t3.large
- Networking: Private subnets only
- Add-ons: CoreDNS, kube-proxy, VPC-CNI, EBS CSI

**Data Layer:**
- RDS PostgreSQL (Multi-AZ)
- S3 buckets with versioning
- KMS encryption at rest
- Automated backups

**GitOps with ArgoCD:**
- Helm chart deployment
- LoadBalancer service type
- IRSA for AWS integration
- Prometheus + Grafana monitoring
- Fluent Bit logging to CloudWatch

### Staging Environment

Mirrors production with scaled-down resources for testing.

---

## 📦 Modules

Reusable, production-ready Terraform modules:

| Module | Purpose | Key Resources |
|--------|---------|---------------|
| `networking` | Hub-spoke VPC architecture | VPC, TGW, NAT, subnets |
| `eks` | EKS cluster setup | EKS, node groups, add-ons |
| `data` | Data persistence layer | RDS, S3, security groups |
| `security` | Security controls | KMS, security groups, NACLs |
| `argocd-helm` | GitOps deployment | Helm, ArgoCD chart |
| `irsa` | IAM roles for K8s | IAM roles with OIDC |
| `kms` | Encryption keys | KMS keys and policies |
| `acm` | SSL/TLS certificates | ACM certificates |
| `eks-roles` | Kubernetes RBAC | ClusterRoles, RoleBindings |

---

## 🛠️ Prerequisites

- **Terraform**: >= 1.5.0
- **AWS CLI**: >= 2.x configured with appropriate credentials
- **kubectl**: >= 1.28 (for EKS management)
- **Helm**: >= 3.x (for ArgoCD deployment)
- **Access**: AWS Organization admin rights for initial setup

---

## 🚦 Getting Started

### 1. Management Account Setup

```bash
cd management-account/
terraform init
terraform plan
terraform apply
```

Creates AWS Organization, OUs, and member accounts.

### 2. Security Account Bootstrap

```bash
cd security-account/backend-bootstrap/
terraform init
terraform apply
```

Creates S3 backend and DynamoDB table for remote state.

### 3. Security Account Roles

```bash
cd security-account/cross-account-roles/
terraform init
terraform apply
```

Provisions IAM roles and S3 buckets for log aggregation.

### 4. Workload Account Roles

```bash
cd workload-account/cross-account-roles/
terraform init
terraform apply
```

Creates trust relationships with Security Account.

### 5. Production Environment

```bash
cd workload-account/environments/production/
terraform init
terraform plan
terraform apply
```

Deploys EKS, RDS, networking, and ArgoCD.

### 6. Configure kubectl

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name production-eks-cluster
```

### 7. Access ArgoCD

```bash
# Get LoadBalancer URL
terraform output argocd_server

# Get admin password
terraform output argocd_password
```

---

## 🔧 Configuration

### Terraform Variables

Key variables in `terraform.tfvars`:

```hcl
# Environment
env    = "production"
region = "us-east-1"

# Networking
workload_vpc_cidr = "10.0.0.0/16"
egress_vpc_cidr   = "10.1.0.0/16"

# EKS
cluster_version = "1.28"
node_group_desired_size = 3

# Database
db_instance_class = "db.t3.medium"
db_allocated_storage = 100
```

### Backend Configuration

Remote state stored in Security Account:

```hcl
backend "s3" {
  bucket         = "org-security-account-state-prod"
  key            = "workload/production.tfstate"
  region         = "us-east-1"
  dynamodb_table = "terraform-locks-prod"
  encrypt        = true
  role_arn       = "arn:aws:iam::404068503087:role/TerraformExecutionRole"
}
```

---

## 📊 Monitoring & Observability

### Metrics Collection
- **Prometheus** - Kubernetes and application metrics
- **Grafana** - Visualization dashboards
- **CloudWatch** - AWS service metrics and logs

### Log Aggregation
- **Fluent Bit** - Log collection from pods
- **CloudWatch Logs** - Centralized log storage
- **Security Account** - Cross-account log streaming

### Alerting
- **AlertManager** - Kubernetes alerts
- **CloudWatch Alarms** - AWS resource alerts
- **GuardDuty** - Security threat detection
- **SecurityHub** - Compliance findings

---

## 🔒 Service Control Policies (SCPs)

Implemented organization-wide governance:

1. **Prevent Root User Actions** - Restrict root account usage
2. **Require MFA for Sensitive Operations** - Enforce MFA
3. **Region Restrictions** - Limit to approved regions
4. **Resource Tagging Enforcement** - Mandate cost allocation tags

---

## 📝 Documentation

Detailed guides for each component:

- [Management Account Setup](management-account/README.md)
- [Security Services Configuration](management-account/SECURITY-SERVICES-GUIDE.md)
- [Security Account Cross-Account Access](security-account/cross-account-roles/README.md)
- [Workload Account Deployment](workload-account/cross-account-roles/README.md)
- [Production Environment Guide](workload-account/environments/production/DEPLOYMENT-GUIDE.md)
- [Disaster Recovery Implementation](workload-account/environments/production/DR-IMPLEMENTATION-COMPLETE.md)
- [ArgoCD Setup](argocd/README.md)
- [Network Architecture Review](workload-account/modules/networking/ARCHITECTURE-REVIEW.md)
- [VPC Flow Logs Configuration](workload-account/VPC-FLOW-LOGS-CONFIGURATION.md)

---

## 🔄 CI/CD with ArgoCD

GitOps workflow:

1. **Code Commit** → Git repository
2. **ArgoCD Detection** → Monitors repo for changes
3. **Automatic Sync** → Applies manifests to EKS
4. **Health Checks** → Verifies deployment status
5. **Rollback** → Automatic on failure

---

## 🧪 Testing

### Pre-deployment Validation
```bash
terraform fmt -check -recursive
terraform validate
terraform plan
```

### Post-deployment Testing
```bash
# Verify EKS cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Check ArgoCD
kubectl get pods -n argocd

# Validate network connectivity
kubectl run test-pod --image=busybox --rm -it -- ping google.com
```

---

## 📈 Cost Optimization

- **Right-sizing**: EKS nodes auto-scale based on demand
- **Spot Instances**: Optional for non-critical workloads
- **S3 Lifecycle Policies**: Automatic tiering to Glacier
- **Resource Tagging**: Cost allocation by environment/team
- **NAT Gateway**: Centralized in hub VPC reduces costs

---

## 🔐 Security Best Practices

✅ **Implemented:**
- Multi-account isolation
- Least privilege IAM roles
- Encryption at rest (KMS)
- Encryption in transit (TLS)
- VPC Flow Logs enabled
- CloudTrail organization trail
- GuardDuty threat detection
- SecurityHub compliance checks
- AWS Config rules
- Network Firewall for egress
- Private subnets for workloads
- No direct internet access to apps
- IRSA for pod-level IAM

---

## 🚨 Disaster Recovery

Comprehensive DR strategy:

- **RTO**: 4 hours
- **RPO**: 1 hour
- **Multi-AZ deployment** for high availability
- **Automated backups** to S3 with cross-region replication
- **Infrastructure as Code** for rapid rebuild
- **Documented runbooks** for incident response

See [DR Implementation Guide](workload-account/environments/production/DR-IMPLEMENTATION-COMPLETE.md)

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Support

For issues, questions, or contributions:
- 📧 Email: support@example.com
- 💬 Slack: #terraform-infra
- 📝 Issues: GitHub Issues

---

## 🎯 Roadmap

- [ ] Multi-region failover
- [ ] Service mesh (Istio/Linkerd)
- [ ] Advanced monitoring with Datadog
- [ ] Auto-remediation with Lambda
- [ ] Cost anomaly detection
- [ ] Compliance automation (CIS benchmarks)

---

**Last Updated**: January 2026  
**Maintained By**: Infrastructure Team  
**Status**: ✅ Production Ready

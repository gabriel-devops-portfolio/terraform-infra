# AWS Multi-Account Organization with Security-First Infrastructure

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Organization-FF9900?logo=amazon-aws)](https://aws.amazon.com/)
[![Security](https://img.shields.io/badge/Security-Production_Grade-success)](https://aws.amazon.com/security/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 📋 Overview

Production-grade AWS multi-account infrastructure managed with Terraform, implementing AWS Well-Architected Framework best practices for security, compliance, governance, and workload isolation. This infrastructure establishes a complete AWS Organization with centralized security monitoring, Service Control Policies (SCPs), cross-account access controls, and production-ready network architecture.

### Key Features

- ✅ **Multi-Account AWS Organization** with hierarchical OUs (Security + Workloads)
- 🔒 **Centralized Security Account** for logging, monitoring, and compliance
- �️ **Production-Grade SCPs** including root account protection (60+ exceptions)
- 🔐 **Cross-Account IAM Roles** with least privilege access
- 📦 **Remote State Management** with S3 + DynamoDB locking + KMS encryption
- 🌐 **Hub-and-Spoke Network Architecture** with Transit Gateway
- � **Security Lake** for OCSF-compliant security data aggregation
- 📊 **OpenSearch** for log visualization and analysis
- ⚡ **AWS Config** for drift detection and compliance monitoring
- 🚨 **SOC Alerting** with SNS/SQS for security incident response

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AWS ORGANIZATION                                   │
│                         (Management Account)                                 │
│                    • Organization Management                                 │
│                    • Consolidated Billing                                    │
│                    • Service Control Policies                                │
│                                                                               │
│  ┌─────────────────────┐              ┌──────────────────────┐             │
│  │   Security OU       │              │   Workloads OU       │             │
│  │                     │              │                      │             │
│  │  ┌───────────────┐  │              │  ┌────────────────┐ │             │
│  │  │ Security Acct │  │              │  │ Workload Acct  │ │             │
│  │  │ 404068503087  │  │              │  │ 290793900072   │ │             │
│  │  │               │  │              │  │                │ │             │
│  │  │ • CloudTrail  │  │              │  │ ┌────────────┐ │ │             │
│  │  │ • GuardDuty   │  │              │  │ │ Spoke VPC  │ │ │             │
│  │  │ • SecurityHub │  │              │  │ │ 10.0.0.0/16│ │ │             │
│  │  │ • Config      │  │              │  │ │            │ │ │             │
│  │  │ • Sec Lake    │  │              │  │ │ • EKS      │ │ │             │
│  │  │ • OpenSearch  │  │              │  │ │ • RDS      │ │ │             │
│  │  │ • Athena      │  │              │  │ │ • Private  │ │ │             │
│  │  │ • TF State    │  │◄────────────┤  │ │   Subnets  │ │ │             │
│  │  │ • Audit Logs  │  │ Cross-       │  │ └─────┬──────┘ │ │             │
│  │  └───────────────┘  │ Account      │  │       │        │ │             │
│  │                     │ Roles        │  │       │        │ │             │
│  │  SCPs Applied:      │              │  │ ┌─────▼──────┐ │ │             │
│  │  • Deny Leave Org   │              │  │ │  Hub VPC   │ │ │             │
│  │  • Encrypt Transit  │              │  │ │ (Egress)   │ │ │             │
│  │                     │              │  │ │ 10.1.0.0/16│ │ │             │
│  │                     │              │  │ │            │ │ │             │
│  │                     │              │  │ │ • NAT GW   │ │ │             │
│  │                     │              │  │ │ • IGW      │ │ │             │
│  │                     │              │  │ │ • Firewall │ │ │             │
│  │                     │              │  │ │ • ALB      │ │ │             │
│  │                     │              │  │ └────────────┘ │ │             │
│  │                     │              │  │       │        │ │             │
│  │                     │              │  └───────┼────────┘ │             │
│  │                     │              │          │          │             │
│  │                     │              │  SCPs Applied:      │             │
│  │                     │              │  • Deny Leave Org   │             │
│  │                     │              │  • Deny Root Acct   │             │
│  │                     │              │  • Require MFA      │             │
│  │                     │              │  • Encrypt Transit  │             │
│  └─────────────────────┘              └──────────┼──────────┘             │
│                                                   │                         │
└───────────────────────────────────────────────────┼─────────────────────────┘
                                                    │
                                          ┌─────────▼──────────┐
                                          │     INTERNET       │
                                          └────────────────────┘
```

---

## 📁 Project Structure

```
terraform-infra/
├── management-account/             # AWS Organization & SCPs
│   ├── org-account.tf             # Organization, OUs, accounts, SCPs
│   ├── outputs.tf                 # Account IDs, ARNs, OU IDs
│   ├── variables.tf               # Email addresses for accounts
│   ├── providers.tf               # AWS provider configuration
│   ├── README.md                  # Comprehensive setup guide
│   ├── SECURITY-SERVICES-GUIDE.md # Security services documentation
│   ├── ROOT-ACCOUNT-SCP-GUIDE.md  # Root account SCP documentation
│   ├── ROOT-ACCOUNT-SCP-QUICK-REF.md  # Quick reference card
│   ├── ROOT-ACCOUNT-IMPLEMENTATION-SUMMARY.md  # Implementation guide
│   ├── DEPLOYMENT-CHECKLIST.md    # Deployment checklist
│   └── MEMBER-ACCOUNT-ADMIN-ACCESS-GUIDE.md  # Admin access guide
│
├── security-account/              # Centralized Security Hub
│   ├── backend-bootstrap/         # Remote state infrastructure
│   │   ├── main.tf                # Module orchestration with dependencies
│   │   ├── backend.tf             # Local backend (bootstrap)
│   │   ├── bucket-state.tf        # S3 backend bucket
│   │   ├── bucket-policy.tf       # Bucket access policies
│   │   ├── bucket-logging.tf      # S3 access logging
│   │   ├── dynamodb.tf            # State locking table
│   │   ├── remote-state.tf        # Remote backend config
│   │   ├── config-drift-detection.tf  # AWS Config setup
│   │   ├── variables.tf           # Configuration variables
│   │   └── MODULE-DEPENDENCIES-GUIDE.md  # Dependency documentation
│   │
│   ├── cross-account-roles/       # IAM roles for security services
│   │   ├── iam-roles.tf           # 10 security roles (including OpenSearch with Security Lake permissions)
│   │   ├── s3-buckets.tf          # 4 log aggregation buckets
│   │   ├── kms.tf                 # Log encryption keys
│   │   ├── outputs.tf             # Role ARNs, bucket names
│   │   ├── providers.tf           # AWS provider
│   │   ├── variables.tf           # Account IDs, region
│   │   └── README.md              # Security setup guide
│   │
│   ├── opensearch/                # OpenSearch for log analysis
│   │   ├── main.tf                # OpenSearch domain (VPC optional)
│   │   ├── variables.tf           # Configuration options
│   │   ├── outputs.tf             # Endpoint, domain info
│   │   └── OPENSEARCH-VPC-OPTIONAL-CHANGES.md  # VPC documentation
│   │
│   ├── athena/                    # Athena OCSF queries
│   │   └── main.tf                # 11 OCSF named queries + multi-source correlation
│   │
│   ├── security-lake/             # Security data lake (OCSF 1.1.0)
│   │   ├── main.tf                # Security Lake + OpenSearch subscriber
│   │   ├── glue.tf                # Glue catalog for OCSF queries
│   │   ├── variables.tf           # Configuration (includes opensearch_role_arn)
│   │   └── outputs.tf             # Data lake info + subscriber ARN
│   │
│   ├── soc-alerting/              # SOC alerting infrastructure
│   │   ├── sns.tf                 # SNS topics
│   │   ├── dlq.tf                 # Dead letter queues
│   │   ├── alerting-dlq-monitor.tf  # DLQ monitoring
│   │   ├── README.md              # Alerting setup
│   │   └── monitors/              # Alert monitors
│   │
│   ├── dashboards/                # Security dashboards
│   │   ├── guardduty-severity.md
│   │   ├── privileged-activity.md
│   │   ├── terraform-state-access.md
│   │   └── vpc-anomalies.md
│   │
│   └── config-drift-detection/    # AWS Config for compliance
│       ├── variables.tf
│       └── [config rules]
│
├── workload-account/              # Application workloads
│   ├── cross-account-roles/       # Trust relationships
│   │   ├── iam-roles.tf           # 8 cross-account roles
│   │   ├── outputs.tf             # Role ARNs
│   │   ├── providers.tf           # AWS provider
│   │   ├── variables.tf           # Account IDs
│   │   ├── README.md              # Workload setup guide
│   │   └── USAGE-GUIDE.md         # Usage documentation
│   │
│   ├── environments/
│   │   ├── production/            # Production environment
│   │   │   ├── main.tf            # EKS, RDS, networking
│   │   │   ├── backend.tf         # Remote state config
│   │   │   ├── providers.tf       # AWS provider
│   │   │   ├── terraform.tfvars   # Environment variables
│   │   │   └── outputs.tf         # Resource outputs
│   │   │
│   │   └── staging/               # Staging environment
│   │       ├── main.tf            # Staging resources
│   │       ├── backend.tf         # Remote state config
│   │       └── terraform.tfvars   # Staging variables
│   │
│   └── modules/                   # Reusable Terraform modules
│       ├── networking/            # Hub-spoke VPC, TGW, NAT, FW
│       ├── eks/                   # EKS cluster with add-ons
│       ├── data/                  # RDS, S3 data layer
│       ├── security/              # KMS, security groups
│       ├── kms/                   # KMS encryption keys
│       ├── acm/                   # SSL/TLS certificates
│       ├── eks-roles/             # Kubernetes RBAC roles
│       └── irsa/                  # IAM roles for service accounts
│
└── security-detections/           # Security detection runbooks
    ├── runbooks/
    │   ├── root-account.md        # Root account detection
    │   ├── root-account-incident.md  # Incident response
    │   ├── guardduty.md           # GuardDuty alerts
    │   ├── terraform-state.md     # State file access
    │   ├── vpc-scanning.md        # Network scanning
    │   └── dlq-alerting.md        # DLQ monitoring
    │
    ├── templates/
    │   ├── incident-report.md
    │   ├── escalation-checklist.md
    │   └── post-incident-review.md
    │
    ├── mitre-mapping.yaml         # MITRE ATT&CK mapping
    └── SOC-QUICK-REFERENCE.md     # Quick SOC reference
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

### Centralized Logging & OCSF Analytics

All logs flow to the Security Account in OCSF 1.1.0 format:

- 📋 **CloudTrail Logs** → OCSF API Activity (class_uid 3005) - 365-day retention
- 🌊 **VPC Flow Logs** → OCSF Network Activity (class_uid 4001) - 365-day retention
- 🛡️ **Security Hub Findings** → OCSF Security Finding (class_uid 2001) - Includes GuardDuty, Config, Inspector, Macie
- 🌐 **Route 53 DNS** → OCSF DNS Activity (class_uid 4003) - 365-day retention
- 📄 **Terraform State Access Logs** → Lambda → OCSF API Activity (3005) - Custom injection
- 📊 **Athena Query Results** (90-day retention)

**Unified Analytics:**
- **OpenSearch**: Real-time OCSF dashboards, alerting, and visualization
- **Athena**: SQL queries with multi-source correlation (11 pre-built OCSF queries)
- **Security Lake Subscriber**: Grants OpenSearch direct S3 access to OCSF data (~$1/month)

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
- Networking: Private subnets only (no direct internet access)
- Add-ons: CoreDNS, kube-proxy, VPC-CNI, EBS CSI Driver
- OIDC Provider: Enabled for IRSA (IAM Roles for Service Accounts)

**Data Layer:**
- RDS PostgreSQL (Multi-AZ)
- S3 buckets with versioning and encryption
- KMS encryption at rest for all data
- Automated daily backups with 7-day retention

**Network Architecture:**
- Private subnets for EKS nodes and RDS
- Database subnets isolated from application layer
- Transit Gateway attachment to Egress VPC (Hub)
- All internet-bound traffic routed through centralized NAT Gateway
- Network Firewall inspection for egress traffic (optional)

### Staging Environment

Mirrors production architecture with scaled-down resources for testing:
- Smaller EKS node groups (2-5 nodes)
- Single-AZ RDS instance (db.t3.small)
- Reduced storage and backup retention
- Same security controls and network topology

---

## �️ Terraform Modules

Reusable, production-ready infrastructure modules:

| Module | Purpose | Key Resources |
|--------|---------|---------------|
| `networking` | Hub-spoke VPC architecture | VPC, TGW, NAT, subnets, route tables |
| `eks` | EKS cluster setup | EKS cluster, node groups, add-ons, OIDC |
| `data` | Data persistence layer | RDS, S3, security groups, backup policies |
| `security` | Security controls | KMS keys, security groups, NACLs |
| `kms` | Encryption keys | KMS keys with rotation, aliases, policies |
| `acm` | SSL/TLS certificates | ACM certificates, DNS validation |
| `eks-roles` | Kubernetes RBAC | ClusterRoles, RoleBindings, ServiceAccounts |
| `irsa` | IAM roles for K8s | IAM roles with OIDC provider trust |

---

## 🔍 Compliance & Governance

### OCSF 1.1.0 Standardization

All security data normalized to Open Cybersecurity Schema Framework (OCSF) format:

**OCSF Classes:**
- **4001**: Network Activity (VPC Flow Logs)
- **3005**: API Activity (CloudTrail, Terraform State Logs)
- **2001**: Security Finding (GuardDuty, Config, Inspector, Macie via Security Hub)
- **4003**: DNS Activity (Route 53 Resolver Logs)

**Benefits:**
- ✅ Unified field names across all security tools (OpenSearch, Athena)
- ✅ Multi-source correlation in single queries (VPC + CloudTrail + Security Hub)
- ✅ Industry-standard schema for SIEM integration
- ✅ Future-proof for new security tools and data sources

### AWS Config Rules (30+ rules)

- **Encryption**: S3 bucket encryption, EBS volume encryption, RDS encryption
- **Access Control**: Public S3 buckets, security group ingress, IAM password policy
- **Networking**: VPC flow logs enabled, default security group closed
- **Monitoring**: CloudTrail enabled, Config enabled, GuardDuty enabled
- **Compliance**: CIS AWS Foundations Benchmark v1.4.0

### SecurityHub Standards

- **CIS AWS Foundations Benchmark v1.4.0** - 50+ automated checks
- **AWS Foundational Security Best Practices** - 200+ controls
- **PCI-DSS v3.2.1** - Payment card industry compliance

### Audit & Compliance Reports

- **CloudTrail**: 365-day API activity retention (OCSF class_uid 3005)
- **AWS Config**: Configuration snapshots every 6 hours
- **Security Lake**: OCSF 1.1.0 format for SIEM integration (365-day retention)
- **Athena Queries**: 11 pre-built OCSF compliance queries for auditors
  - VPC traffic anomalies (class_uid 4001)
  - Terraform state access monitoring (class_uid 3005)
  - Privileged activity tracking (class_uid 3005)
  - Security findings analysis (class_uid 2001)
  - Multi-source threat correlation (4001 + 3005 + 2001)
- **OpenSearch Dashboards**: Real-time OCSF security insights with subscriber access

---

## 🎯 Production Readiness Checklist

### Infrastructure ✅
- [x] Multi-account AWS Organization deployed
- [x] Service Control Policies (SCPs) applied
- [x] Cross-account IAM roles configured
- [x] Remote state backend with encryption and locking
- [x] Hub-and-spoke network topology with Transit Gateway
- [x] EKS cluster with managed node groups
- [x] RDS Multi-AZ with automated backups
- [x] KMS encryption for all data at rest

### Security ✅
- [x] Root account protected with production-grade SCP
- [x] MFA enforced for production operations
- [x] CloudTrail logging to centralized security account
- [x] GuardDuty enabled across all accounts
- [x] SecurityHub compliance monitoring
- [x] AWS Config drift detection
- [x] VPC Flow Logs enabled and centralized
- [x] Security Lake for OCSF data aggregation (365-day retention)
- [x] Security Lake Subscriber for OpenSearch (OCSF S3 access)
- [x] OpenSearch for real-time OCSF log analysis
- [x] Athena for SQL-based OCSF queries (11 pre-built queries)
- [x] Multi-source correlation queries (VPC + CloudTrail + Security Hub)
- [x] SOC alerting with SNS/SQS

### Monitoring ✅
- [x] CloudWatch dashboards for EKS, RDS, VPC
- [x] CloudWatch alarms for critical metrics
- [x] GuardDuty high-severity alert routing
- [x] SecurityHub critical finding notifications
- [x] Config compliance violation alerts
- [x] DLQ monitoring for alert delivery
- [x] OpenSearch dashboards for security insights

### Documentation ✅
- [x] Architecture diagrams
- [x] Deployment procedures
- [x] Runbooks for incident response
- [x] Root account SCP comprehensive guide
- [x] Cross-account access documentation
- [x] Module dependency documentation
- [x] Security detection playbooks

---

## 🚨 Incident Response

### Detection Sources

1. **GuardDuty Findings**: Real-time threat detection
2. **SecurityHub Insights**: Compliance violations
3. **Config Rules**: Drift and non-compliance
4. **CloudTrail Events**: Suspicious API activity
5. **VPC Flow Logs**: Network anomalies

### Response Procedures

All runbooks located in `security-detections/runbooks/`:

- **[Root Account Detection](security-detections/runbooks/root-account.md)** - Monitors root account login attempts
- **[Root Account Incident Response](security-detections/runbooks/root-account-incident.md)** - Step-by-step incident handling
- **[GuardDuty Alerts](security-detections/runbooks/guardduty.md)** - Threat finding response
- **[Terraform State Access](security-detections/runbooks/terraform-state.md)** - State file security monitoring
- **[VPC Scanning Detection](security-detections/runbooks/vpc-scanning.md)** - Network reconnaissance response
- **[DLQ Alert Monitoring](security-detections/runbooks/dlq-alerting.md)** - Alert delivery failures

### Escalation Templates

- **[Incident Report Template](security-detections/templates/incident-report.md)**
- **[Escalation Checklist](security-detections/templates/escalation-checklist.md)**
- **[Post-Incident Review](security-detections/templates/post-incident-review.md)**

---

## 📋 Operations

### Routine Maintenance

#### Weekly Tasks
- Review GuardDuty findings and triage threats
- Check SecurityHub compliance score trends
- Review Config rule violations
- Audit CloudTrail for unusual activity
- Verify backup completion for RDS/S3

#### Monthly Tasks
- Review and update IAM policies
- Audit cross-account role usage
- Review S3 bucket policies and access logs
- Update EKS cluster and node AMIs
- Review and optimize AWS costs
- Test disaster recovery procedures

#### Quarterly Tasks
- Security assessment with external auditor
- Review and update SCP policies
- Rotate KMS keys (automated but verify)
- Conduct tabletop exercises for incident response
- Review and update documentation

### Backup Strategy

- **RDS**: Automated daily snapshots, 7-day retention, cross-region replication
- **S3**: Versioning enabled, lifecycle policies, cross-region replication
- **EKS**: Velero backup for persistent volumes and cluster state
- **Terraform State**: Versioned S3 bucket with cross-region replication

---

## 🧪 Testing & Validation

### Pre-Deployment Validation

```bash
# Format check
terraform fmt -check -recursive

# Validation
terraform validate

# Security scanning
tfsec .
checkov -d .

# Plan review
terraform plan -out=tfplan
terraform show -json tfplan | jq
```

### Post-Deployment Testing

```bash
# EKS cluster connectivity
aws eks update-kubeconfig --region us-east-1 --name production-eks-cluster
kubectl get nodes
kubectl get pods --all-namespaces

# RDS connectivity
psql -h <rds-endpoint> -U admin -d mydb

# Network connectivity
kubectl run test-pod --image=busybox --rm -it -- ping 8.8.8.8

# Cross-account role assumption
aws sts assume-role --role-arn arn:aws:iam::404068503087:role/WorkloadReadOnlyRole --role-session-name test

# Security services validation
aws guardduty list-detectors
aws securityhub get-findings
aws configservice describe-compliance-by-config-rule
```

### Security Testing

```bash
# Test root account SCP
cd management-account
bash test-admin-access.sh

# Test MFA enforcement
aws s3 ls  # Should fail without MFA in production

# Test unauthorized access
aws s3 cp test.txt s3://cloudtrail-logs-404068503087/  # Should deny
```

---

## � Cost Optimization

### Implemented Strategies

- **Right-Sizing**: EKS nodes auto-scale based on workload demand (3-10 nodes)
- **Spot Instances**: Optional mixed instance policy for non-critical workloads
- **S3 Lifecycle Policies**: Automatic tiering to Glacier after 90 days
- **Resource Tagging**: Mandatory tags for cost allocation (environment, project, owner)
- **Centralized NAT Gateway**: Hub VPC reduces egress costs
- **RDS Reserved Instances**: 1-year commitment for production databases
- **CloudWatch Log Retention**: 30-day retention for most logs, 365 days for CloudTrail
- **EBS Volume Optimization**: GP3 volumes with optimized IOPS

### Monthly Cost Estimates

| Service | Configuration | Estimated Cost |
|---------|--------------|----------------|
| EKS Cluster | 1 cluster | $73/month |
| EC2 (EKS nodes) | 3x t3.medium | $90/month |
| RDS PostgreSQL | db.t3.medium Multi-AZ | $120/month |
| S3 (logs, backups) | 500 GB standard | $12/month |
| CloudTrail | Organization trail | $5/month |
| GuardDuty | 1 account | $30/month |
| Security Lake | 1TB OCSF data + lifecycle | $25/month |
| Security Lake Subscriber | OpenSearch access | $1/month |
| OpenSearch | 3x r6g.xlarge nodes | $750/month |
| OpenSearch EBS | 3x 200GB gp3 | $90/month |
| Athena | ~100GB OCSF queries | $5/month |
| Glue Crawler | 6 runs/day | $2/month |
| NAT Gateway | 1 gateway | $35/month |
| Transit Gateway | 2 attachments | $70/month |
| **Total (Production)** | | **~$1,308/month** |

*Note: Security Lake + OpenSearch add ~$873/month for centralized OCSF analytics*

---

## 🔐 Security Best Practices Implemented

### Identity & Access Management
✅ Least privilege IAM policies with explicit deny
✅ Cross-account roles instead of IAM users
✅ MFA required for production operations
✅ Root account protected with comprehensive SCP
✅ IRSA (IAM Roles for Service Accounts) in EKS
✅ No long-term access keys (temporary credentials only)

### Data Protection
✅ Encryption at rest with KMS (S3, RDS, EBS)
✅ Encryption in transit with TLS 1.2+ enforced
✅ S3 bucket public access blocked by default
✅ RDS automated backups with 7-day retention
✅ Versioning enabled on all S3 buckets
✅ Cross-region replication for disaster recovery

### Network Security
✅ Private subnets for all workloads (no direct internet)
✅ Hub-and-spoke topology with centralized egress
✅ Network Firewall for outbound traffic inspection (optional)
✅ VPC Flow Logs enabled and centralized
✅ Security groups with least privilege rules
✅ NACLs as secondary defense layer
✅ Transit Gateway for secure inter-VPC routing

### Monitoring & Detection
✅ CloudTrail organization trail with 365-day retention
✅ GuardDuty threat detection (S3, EKS protection)
✅ SecurityHub compliance monitoring (CIS, PCI-DSS)
✅ AWS Config with 30+ compliance rules
✅ Security Lake for OCSF data aggregation
✅ OpenSearch for log visualization
✅ SOC alerting with SNS for high-severity events
✅ DLQ monitoring to ensure no alerts are lost

### Compliance & Governance
✅ Service Control Policies (SCPs) for organizational boundaries
✅ Multi-account isolation (security, workload separation)
✅ Centralized audit logging to security account
✅ Resource tagging enforcement for cost allocation
✅ Config rules for continuous compliance validation
✅ SecurityHub standards (CIS, AWS FSBP, PCI-DSS)

---

## 🚨 Disaster Recovery

### RTO & RPO Targets

- **Recovery Time Objective (RTO)**: 4 hours
- **Recovery Point Objective (RPO)**: 1 hour

### High Availability Design

- **Multi-AZ Deployment**: All critical services span 3 availability zones
- **RDS Multi-AZ**: Automatic failover to standby instance
- **EKS Node Groups**: Distributed across 3 AZs with auto-scaling
- **S3 Cross-Region Replication**: Automatic replication to DR region
- **Transit Gateway**: Resilient routing between VPCs

### Backup Strategy

| Resource | Frequency | Retention | Cross-Region |
|----------|-----------|-----------|--------------|
| RDS Snapshots | Daily | 7 days | Yes (us-west-2) |
| S3 Buckets | Continuous | Versioning | Yes (us-west-2) |
| EKS Volumes | Daily (Velero) | 7 days | Yes |
| Terraform State | On change | Versioned | Yes (us-west-2) |
| CloudTrail Logs | Real-time | 365 days | Yes |

### Recovery Procedures

1. **Infrastructure Rebuild**: Execute Terraform in DR region
2. **Data Restoration**: Restore RDS from cross-region snapshot
3. **Application Deployment**: Deploy workloads to DR EKS cluster
4. **DNS Failover**: Update Route53 to DR endpoints
5. **Validation**: Run smoke tests to verify functionality

Detailed DR runbooks in `workload-account/environments/production/DR-IMPLEMENTATION-COMPLETE.md`

---

## 🤝 Contributing

We welcome contributions to improve this infrastructure!

### How to Contribute

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/amazing-improvement`
3. **Commit** your changes: `git commit -m 'Add amazing improvement'`
4. **Test** thoroughly with `terraform plan` and validation tools
5. **Push** to your branch: `git push origin feature/amazing-improvement`
6. **Submit** a Pull Request with detailed description

### Code Standards

- Use Terraform formatting: `terraform fmt -recursive`
- Validate all changes: `terraform validate`
- Run security scans: `tfsec .` and `checkov -d .`
- Update documentation for any new features
- Follow AWS Well-Architected Framework principles
- Include comments for complex logic

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Support & Contact

For issues, questions, or contributions:

- 📧 **Email**: infrastructure-team@example.com
- 💬 **Slack**: #terraform-infrastructure
- 📝 **Issues**: [GitHub Issues](https://github.com/org/terraform-infra/issues)
- 📚 **Wiki**: [Internal Documentation](https://wiki.example.com/terraform-infra)

---

## 🙏 Acknowledgments

- AWS Well-Architected Framework
- HashiCorp Terraform Best Practices
- CIS AWS Foundations Benchmark
- Open Source Security Foundation (OpenSSF)
- AWS Security Blog Contributors

---

**Last Updated**: January 2025
**Maintained By**: Infrastructure & Security Team
**Status**: ✅ Production Ready
**Version**: 2.0.0

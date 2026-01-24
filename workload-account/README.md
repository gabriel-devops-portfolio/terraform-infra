# Workload Account Infrastructure

This directory contains the Terraform configuration for the application workload account. This account hosts the primary business applications, Kubernetes clusters, and data persistence layers.

## 🏗️ Architecture

The workload infrastructure is designed with a **Zero-Trust** philosophy, ensuring strict network isolation and centralized security controls.

### Core Components

- **Networking (`modules/networking`)**:
  - **Hub-and-Spoke Topology**: Centralized egress via a "Hub" VPC.
  - **Private Workloads**: No direct internet access for EKS or RDS.
  - **Transit Gateway**: Connects the Workload Spoke VPC to the Egress Hub VPC.
  - **AWS Network Firewall**: Inspects all outbound traffic.
- **Compute (`modules/eks`)**:
  - **Amazon EKS**: Managed Kubernetes cluster.
  - **Karpenter**: Intelligent node autoscaling.
  - **Fargate**: Serverless compute for specific workloads.
- **Data (`modules/data`)**:
  - **Amazon RDS**: Managed SQL Server/PostgreSQL databases.
  - **Amazon S3**: Secure object storage with cross-region replication.
- **GitOps**:
  - **ArgoCD**: Declarative continuous delivery for Kubernetes manifests.

## 📁 Directory Structure

```
workload-account/
├── cross-account-roles/   # IAM roles for Security Account access
├── environments/          # Environment-specific configurations
│   ├── production/        # PROD environment (EKS, RDS, VPC)
│   └── staging/           # STAGING environment
└── modules/               # Reusable Terraform modules
    ├── networking/        # VPC, TGW, Firewall
    ├── eks/               # EKS Cluster
    ├── data/              # RDS, S3
    ├── security/          # Fail-close automation, KMS
    └── ...
```

## 🚀 Getting Started

### 1. Prerequisites

- **Terraform >= 1.5.0**
- **AWS CLI** configured with appropriate credentials.
- **Backend Infrastructure**: S3 bucket and DynamoDB table for state locking must be provisioned (see `security-account/backend-bootstrap`).

### 2. Deployment

Navigate to the specific environment you wish to deploy:

```bash
cd environments/production
```

Initialize Terraform:

```bash
terraform init
```

Review the plan:

```bash
terraform plan
```

Apply the configuration:

```bash
terraform apply
```

## 🔐 Security Features

- **Fail-Close Egress**: Automated Lambda function (`inspection_controller`) blocks all traffic if the Network Firewall becomes unhealthy.
- **Private-Only Subnets**: Workloads reside in subnets with no Internet Gateway.
- **Encryption Everywhere**: KMS encryption for EBS, RDS, S3, and EKS Secrets.
- **Least Privilege**: IRSA (IAM Roles for Service Accounts) used for Kubernetes workloads.

## 🤝 Cross-Account Integration

This account is integrated with a centralized **Security Account** (`333333444444`) for:

- **Logging**: CloudTrail and VPC Flow Logs are shipped to the Security Account.
- **Monitoring**: GuardDuty and Security Hub findings are aggregated.
- **DNS**: Route53 Resolver rules for shared services.

See `cross-account-roles/README.md` for more details.

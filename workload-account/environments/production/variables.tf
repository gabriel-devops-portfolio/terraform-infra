############################################
# Global
############################################
variable "env" {
  description = "Environment name (prod, dev, stage)"
  type        = string
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "azs" {
  description = "Availability Zones"
  type        = list(string)
}

############################################
# Workload VPC (Spoke)
############################################
variable "workload_vpc_cidr" {
  description = "CIDR block for workload VPC"
  type        = string
}

variable "workload_private_subnets" {
  description = "Private subnets for EKS, RDS, internal services"
  type        = list(string)
}

variable "workload_database_subnets" {
  description = "Private subnets for , RDS"
  type        = list(string)
}

############################################
# Egress VPC (Hub)
############################################
variable "egress_vpc_cidr" {
  description = "CIDR block for egress VPC"
  type        = string
}

variable "egress_public_subnets" {
  description = "Public subnets for NAT Gateways (one per AZ)"
  type        = list(string)
}

variable "firewall_subnets" {
  description = "AWS Network Firewall subnets (one per AZ, /28)"
  type        = list(string)
}

variable "tgw_subnets" {
  description = "Transit Gateway attachment subnets (one per AZ, /28)"
  type        = list(string)
}



############################################
# NAT / Routing
############################################
variable "enable_nat" {
  description = "Enable NAT Gateways in egress VPC"
  type        = bool
  default     = true
}

############################################
# Compute Module Variables
############################################
variable "domain_name" {
  description = "Domain name for ACM certificate"
  type        = string
}

############################################
# EKS Cluster Variables
############################################
variable "eks_cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.31"
}

variable "eks_config_output_dir_path" {
  description = "Directory path for EKS kubeconfig output"
  type        = string
  default     = "./"
}

variable "eks_cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = []
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log group retention period in days"
  type        = number
  default     = 7
}

variable "accounts" {
  description = "Additional AWS account numbers to add to the aws-auth configmap"
  type        = list(string)
  default     = []
}

variable "auth_users" {
  description = "List of IAM users to add to aws-auth configmap"
  type        = list(any)
  default     = []
}

variable "auth_roles" {
  description = "List of IAM roles to add to aws-auth configmap"
  type        = list(any)
  default     = []
}

variable "eks_node_group_internal" {
  description = "EKS managed node group configuration"
  type        = any
  default = {
    internal = {
      min_size     = 1
      max_size     = 5
      desired_size = 2

      instance_types = ["m6i.large"]
      capacity_type  = "ON_DEMAND"

      labels = {
        Environment = "production"
        NodeGroup   = "internal"
      }

      tags = {
        NodeGroup = "internal"
      }
    }
  }
}

############################################
# EKS Add-on Versions
############################################
variable "ebs_csi_driver_version" {
  description = "AWS EBS CSI Driver add-on version"
  type        = string
  default     = "v1.37.0-eksbuild.1"
}

variable "efs_csi_driver_version" {
  description = "AWS EFS CSI Driver add-on version"
  type        = string
  default     = "v2.1.1-eksbuild.1"
}

############################################
# ArgoCD Configuration
############################################
variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "9.2.4"
}

variable "github_oauth_client_id" {
  description = "GitHub OAuth client ID for ArgoCD SSO"
  type        = string
  default     = ""
  sensitive   = true
}

variable "github_oauth_client_secret" {
  description = "GitHub OAuth client secret for ArgoCD SSO"
  type        = string
  default     = ""
  sensitive   = true
}

############################################
# RDS Configuration
############################################
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 100
}

variable "db_engine_version" {
  description = "SQL Server engine version"
  type        = string
  default     = "16.00.4095.6.v1"
}

############################################
# Disaster Recovery Configuration
############################################
variable "dr_region" {
  description = "Disaster recovery region for cross-region replication"
  type        = string
  default     = "us-west-2"
}

variable "enable_dr_replication" {
  description = "Enable disaster recovery replication"
  type        = bool
  default     = true
}

############################################
# EKS Backup and Restore Configuration
############################################
variable "backup_retention_days" {
  description = "Number of days to retain Velero backups"
  type        = number
  default     = 30
}

variable "etcd_backup_retention_days" {
  description = "Number of days to retain ETCD backups"
  type        = number
  default     = 7
}

variable "backup_schedule" {
  description = "Cron schedule for automated backups (UTC)"
  type        = string
  default     = "0 2 * * *" # Daily at 2 AM UTC
}

variable "enable_velero_backup" {
  description = "Enable Velero for Kubernetes resource backups"
  type        = bool
  default     = true
}

variable "enable_ebs_snapshots" {
  description = "Enable automated EBS volume snapshots"
  type        = bool
  default     = true
}

variable "enable_etcd_backup" {
  description = "Enable ETCD backup (for self-managed clusters)"
  type        = bool
  default     = false
}

variable "enable_cross_region_backup" {
  description = "Enable cross-region backup replication for disaster recovery"
  type        = bool
  default     = true
}

variable "enable_backup_monitoring" {
  description = "Enable CloudWatch monitoring and alerting for backups"
  type        = bool
  default     = true
}

variable "backup_notification_topic_arn" {
  description = "SNS topic ARN for backup failure notifications"
  type        = string
  default     = null
}

############################################
# OpenSearch Configuration (for Jaeger Tracing)
############################################
variable "opensearch_instance_type" {
  description = "Instance type for OpenSearch nodes"
  type        = string
  default     = "t3.small.search"
}

variable "opensearch_instance_count" {
  description = "Number of instances in the OpenSearch cluster"
  type        = number
  default     = 3
}

variable "opensearch_dedicated_master_enabled" {
  description = "Whether to enable dedicated master nodes"
  type        = bool
  default     = true
}

variable "opensearch_master_instance_type" {
  description = "Instance type for dedicated master nodes"
  type        = string
  default     = "t3.small.search"
}

variable "opensearch_master_instance_count" {
  description = "Number of dedicated master nodes"
  type        = number
  default     = 3
}

variable "opensearch_zone_awareness_enabled" {
  description = "Whether to enable zone awareness"
  type        = bool
  default     = true
}

variable "opensearch_availability_zone_count" {
  description = "Number of availability zones for zone awareness"
  type        = number
  default     = 3
}

variable "opensearch_volume_type" {
  description = "EBS volume type for OpenSearch nodes"
  type        = string
  default     = "gp3"
}

variable "opensearch_volume_size" {
  description = "EBS volume size in GB for OpenSearch nodes"
  type        = number
  default     = 20
}

variable "opensearch_iops" {
  description = "IOPS for gp3/io1/io2 volumes"
  type        = number
  default     = 3000
}

variable "opensearch_throughput" {
  description = "Throughput for gp3 volumes in MB/s"
  type        = number
  default     = 125
}

variable "opensearch_log_retention_days" {
  description = "CloudWatch log retention in days for OpenSearch"
  type        = number
  default     = 30
}

variable "jaeger_index_prefix" {
  description = "Index prefix for Jaeger traces in OpenSearch"
  type        = string
  default     = "jaeger-prod"
}

variable "jaeger_namespace" {
  description = "Kubernetes namespace for Jaeger deployment"
  type        = string
  default     = "observability"
}

############################################
# Cross-Account Integration
############################################
variable "security_account_id" {
  description = "AWS Account ID of the security account for OpenSearch access"
  type        = string
}

# Production Environment Configuration

############################
# Global Configuration
############################
env    = "production"
region = "us-east-1"
azs    = ["us-east-1a", "us-east-1b", "us-east-1c"]

tags = {
  Environment = "production"
  Project     = "pilotgab"
  ManagedBy   = "terraform"
  Owner       = "platform-team"
}

############################
# Network Configuration
############################
# Workload VPC (Spoke) - Private workloads
workload_vpc_cidr         = "10.1.0.0/16"
workload_private_subnets  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
workload_database_subnets = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]

# Egress VPC (Hub) - Internet access and security controls
egress_vpc_cidr       = "10.2.0.0/16"
egress_public_subnets = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
firewall_subnets      = ["10.2.11.0/28", "10.2.12.0/28", "10.2.13.0/28"]
tgw_subnets           = ["10.2.21.0/28", "10.2.22.0/28", "10.2.23.0/28"]

enable_nat = true

############################
# Domain Configuration
############################
domain_name = "pilotgab.com"

############################
# EKS Configuration
############################
eks_cluster_version                      = "1.31"
eks_config_output_dir_path               = "./"
eks_cluster_endpoint_public_access_cidrs = []
cloudwatch_log_retention_days            = 30

# EKS Node Groups
eks_node_group_internal = {
  internal = {
    min_size     = 2
    max_size     = 10
    desired_size = 3

    instance_types = ["m6i.large", "m6i.xlarge"]
    capacity_type  = "SPOT"

    labels = {
      Environment  = "production"
      NodeGroup    = "internal"
      WorkloadType = "general"
    }

    taints = []

    tags = {
      NodeGroup                = "internal"
      "karpenter.sh/discovery" = "pilotgab-prod"
    }
  }
}

# EKS Add-on Versions
ebs_csi_driver_version = "v1.37.0-eksbuild.1"
efs_csi_driver_version = "v2.1.1-eksbuild.1"

############################
# ArgoCD Configuration
############################
argocd_version = "9.2.4"
# github_oauth_client_id = "your-github-oauth-client-id" # Set via environment variable

############################
# Database Configuration
############################
db_instance_class    = "db.t3.medium"
db_allocated_storage = 100
db_engine_version    = "16.00.4095.6.v1"

############################
# OpenSearch Configuration (for Jaeger Tracing)
############################
opensearch_instance_type            = "t3.small.search"
opensearch_instance_count           = 3
opensearch_dedicated_master_enabled = true
opensearch_master_instance_type     = "t3.small.search"
opensearch_master_instance_count    = 3
opensearch_zone_awareness_enabled   = true
opensearch_availability_zone_count  = 3

# Storage Configuration
opensearch_volume_type = "gp3"
opensearch_volume_size = 20
opensearch_iops        = 3000
opensearch_throughput  = 125

# Jaeger Configuration
jaeger_index_prefix = "jaeger-prod"
jaeger_namespace    = "observability"

# Logging
opensearch_log_retention_days = 30

############################
# Backup and Disaster Recovery
############################
dr_region             = "us-west-2"
enable_dr_replication = true

# Backup Configuration
backup_retention_days      = 30
etcd_backup_retention_days = 7
backup_schedule            = "0 2 * * *" # Daily at 2 AM UTC

# Backup Features
enable_velero_backup       = true
enable_ebs_snapshots       = true
enable_etcd_backup         = false
enable_cross_region_backup = true
enable_backup_monitoring   = true

# backup_notification_topic_arn = "arn:aws:sns:us-east-1:ACCOUNT:backup-notifications" # Optional

############################
# Cross-Account Integration
############################
security_account_id = "333333444444"

############################
# Authentication (Optional)
############################
accounts = []

# Example IAM users for EKS access (uncomment and modify as needed)
# auth_users = [
#   {
#     userarn  = "arn:aws:iam::ACCOUNT:user/admin"
#     username = "admin"
#     groups   = ["system:masters"]
#   }
# ]

# Example IAM roles for EKS access (uncomment and modify as needed)
# auth_roles = [
#   {
#     rolearn  = "arn:aws:iam::ACCOUNT:role/EKSAdminRole"
#     username = "eks-admin"
#     groups   = ["system:masters"]
#   }
# ]

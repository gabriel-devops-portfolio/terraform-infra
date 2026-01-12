############################################
# Environment
############################################
env    = "prod"
region = "us-east-1"

azs = [
  "us-east-1a",
  "us-east-1b",
  "us-east-1c"
]

############################################
# Workload VPC (Spoke)
############################################
workload_vpc_cidr = "10.10.0.0/16" # 65,536 IPs

# Private subnets for EKS, RDS, internal workloads
workload_private_subnets = [
  "10.10.1.0/24", # AZ-a (256 IPs)
  "10.10.2.0/24", # AZ-b (256 IPs)
  "10.10.3.0/24"  # AZ-c (256 IPs)
]

############################################
# Egress VPC (Hub)
############################################
egress_vpc_cidr = "10.0.0.0/16" # 65,536 IPs

# Public subnets for NAT Gateways
egress_public_subnets = [
  "10.0.1.0/24", # AZ-a (256 IPs)
  "10.0.2.0/24", # AZ-b (256 IPs)
  "10.0.3.0/24"  # AZ-c (256 IPs)
]

# Network Firewall subnets (AWS requires /28)
firewall_subnets = [
  "10.0.101.0/28", # AZ-a (16 IPs, 11 usable)
  "10.0.102.0/28", # AZ-b (16 IPs, 11 usable)
  "10.0.103.0/28"  # AZ-c (16 IPs, 11 usable)
]

# Transit Gateway attachment subnets (/28)
tgw_subnets = [
  "10.0.201.0/28", # AZ-a (16 IPs, 11 usable)
  "10.0.202.0/28", # AZ-b (16 IPs, 11 usable)
  "10.0.203.0/28"  # AZ-c (16 IPs, 11 usable)
]

# Database subnets for RDS, Aurora, DocumentDB
workload_database_subnets = [
  "10.10.11.0/24", # AZ-a (256 IPs)
  "10.10.12.0/24", # AZ-b (256 IPs)
  "10.10.13.0/24"  # AZ-c (256 IPs)
]

############################################
# Tags
############################################
tags = {
  Environment = "production"
  Project     = "enterprise-infrastructure"
  ManagedBy   = "terraform"
  Owner       = "platform-team"
}

############################################
# Compute
############################################
domain_name = "pilotgab.com"

############################################
# EKS Cluster Configuration
############################################
eks_cluster_version                      = "1.31"
eks_config_output_dir_path               = "./kubeconfig"
eks_cluster_endpoint_public_access_cidrs = [] # Private cluster, no public access
cloudwatch_log_retention_days            = 7

# AWS Auth Configuration (Add your IAM users/roles here)
accounts   = [] # Additional AWS account IDs
auth_users = [] # IAM users for kubectl access
auth_roles = [] # IAM roles for kubectl access

# Example IAM user configuration:
# auth_users = [
#   {
#     userarn  = "arn:aws:iam::ACCOUNT_ID:user/admin"
#     username = "admin"
#     groups   = ["system:masters"]
#   }
# ]

# EKS Node Group Configuration
eks_node_group_internal = {
  internal = {
    name           = "internal-node-group"
    min_size       = 2
    max_size       = 10
    desired_size   = 3
    instance_types = ["m6i.large"]
    capacity_type  = "ON_DEMAND"
    disk_size      = 50

    labels = {
      Environment = "production"
      NodeGroup   = "internal"
      Workload    = "general"
    }

    taints = []

    tags = {
      NodeGroup = "internal"
      Backup    = "true"
    }
  }
}

# EKS Add-on Versions (use latest compatible versions)
ebs_csi_driver_version = "v1.37.0-eksbuild.1"
efs_csi_driver_version = "v2.1.1-eksbuild.1"

############################################
# ArgoCD Configuration
############################################
argocd_version         = "7.8.23"
github_oauth_client_id = "" # Add your GitHub OAuth client ID for SSO

############################################
# Additional Domains
############################################
domain_radiant_commons = ""   # Optional: Add if you need additional domain
pilotgab_domain_enable = true # Set to true to enable shared.pilotgab.com

############################################
# Disaster Recovery Configuration
############################################
dr_region             = "us-west-2" # DR region for backup replication
enable_dr_replication = true        # Enable cross-region DR

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
      min_size     = 2
      max_size     = 10
      desired_size = 3

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

############################################
# Additional Domains (Optional)
############################################
variable "domain_radiant_commons" {
  description = "Additional domain for Radiant Commons (optional)"
  type        = string
  default     = ""
}

variable "pilotgab_domain_enable" {
  description = "Enable shared.pilotgab.com domain and certificate"
  type        = bool
  default     = false
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
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.5"
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

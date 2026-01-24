############################################
# OpenSearch Variables
############################################

variable "vpc_id" {
  description = "VPC ID where OpenSearch will be deployed (optional - leave null for public access)"
  type        = string
  default     = null
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules (optional - only needed for VPC deployment)"
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for OpenSearch (optional - leave null for public access)"
  type        = list(string)
  default     = null
}

variable "opensearch_instance_type" {
  description = "Instance type for OpenSearch data nodes"
  type        = string
  # Production: r6g.xlarge.search (4 vCPU, 32 GB RAM) - ~$200-300/month per node
  # default     = "r6g.xlarge.search"

  # Development/Testing: Fast provisioning, lower cost (~$30-50/month)
  default = "t3.small.search" # 2 vCPU, 2 GB RAM
}

variable "opensearch_instance_count" {
  description = "Number of OpenSearch data nodes"
  type        = number
  # Production: 3 nodes for high availability
  # default     = 3

  # Development/Testing: Single node for faster provisioning
  default = 1
}

variable "opensearch_master_type" {
  description = "Instance type for OpenSearch master nodes"
  type        = string
  # Production: r6g.large.search (2 vCPU, 16 GB RAM)
  # default     = "r6g.large.search"

  # Development/Testing: Not used with single node setup
  default = "t3.small.search"
}

variable "ebs_volume_size" {
  description = "EBS volume size (GB) per OpenSearch node"
  type        = number
  # Production: 200 GB per node
  # default     = 200

  # Development/Testing: Smaller volume for cost savings
  default = 50
}

variable "enable_warm_storage" {
  description = "Enable UltraWarm storage for older data"
  type        = bool
  default     = false
}

############################################
# OpenSearch Variables
############################################

variable "vpc_id" {
  description = "VPC ID where OpenSearch will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for OpenSearch"
  type        = list(string)
}

variable "opensearch_instance_type" {
  description = "Instance type for OpenSearch data nodes"
  type        = string
  default     = "r6g.xlarge.search"
}

variable "opensearch_instance_count" {
  description = "Number of OpenSearch data nodes"
  type        = number
  default     = 3
}

variable "opensearch_master_type" {
  description = "Instance type for OpenSearch master nodes"
  type        = string
  default     = "r6g.large.search"
}

variable "ebs_volume_size" {
  description = "EBS volume size (GB) per OpenSearch node"
  type        = number
  default     = 200
}

variable "enable_warm_storage" {
  description = "Enable UltraWarm storage for older data"
  type        = bool
  default     = false
}

############################################
# OpenSearch Module Variables
############################################

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}

variable "vpc_id" {
  description = "VPC ID where OpenSearch domain will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group rules"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for OpenSearch domain"
  type        = list(string)
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider for IRSA"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider for IRSA"
  type        = string
}

############################################
# OpenSearch Configuration
############################################

variable "instance_type" {
  description = "Instance type for OpenSearch nodes"
  type        = string
  default     = "t3.small.search"
}

variable "instance_count" {
  description = "Number of instances in the OpenSearch cluster"
  type        = number
  default     = 3
}

variable "dedicated_master_enabled" {
  description = "Whether to enable dedicated master nodes"
  type        = bool
  default     = true
}

variable "master_instance_type" {
  description = "Instance type for dedicated master nodes"
  type        = string
  default     = "t3.small.search"
}

variable "master_instance_count" {
  description = "Number of dedicated master nodes"
  type        = number
  default     = 1
}

variable "zone_awareness_enabled" {
  description = "Whether to enable zone awareness"
  type        = bool
  default     = true
}

variable "availability_zone_count" {
  description = "Number of availability zones for zone awareness"
  type        = number
  default     = 3
}

############################################
# Storage Configuration
############################################

variable "volume_type" {
  description = "EBS volume type for OpenSearch nodes"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.volume_type)
    error_message = "Volume type must be one of: gp2, gp3, io1, io2."
  }
}

variable "volume_size" {
  description = "EBS volume size in GB for OpenSearch nodes"
  type        = number
  default     = 20
}

variable "iops" {
  description = "IOPS for gp3/io1/io2 volumes"
  type        = number
  default     = 3000
}

variable "throughput" {
  description = "Throughput for gp3 volumes in MB/s"
  type        = number
  default     = 125
}

############################################
# Logging Configuration
############################################

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

############################################
# Jaeger Configuration
############################################

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

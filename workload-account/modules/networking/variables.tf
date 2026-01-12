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
  description = "database subnets for RDS"
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
# EKS Configuration
############################################
variable "cluster_name" {
  description = "EKS cluster name for subnet tagging"
  type        = string
  default     = ""
}

############################################
# Security Account Integration
############################################
variable "security_account_vpc_flow_logs_bucket_arn" {
  description = "ARN of the S3 bucket in security account for VPC Flow Logs"
  type        = string
  default     = "" # Will be populated from cross-account setup
}

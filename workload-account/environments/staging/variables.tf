# Staging environment variables

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

# Staging-specific variables with smaller instance sizes
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"  # Different CIDR for staging
}

variable "instance_type" {
  description = "Instance type for staging"
  type        = string
  default     = "t3.medium"  # Smaller instance type for staging
}

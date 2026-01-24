############################################
# Security Account - Cross-Account Variables
############################################

variable "workload_account_id" {
  description = "AWS Account ID for the workload account"
  type        = string
  default     = "555555666666" # Update this with actual workload account ID
}

variable "enable_guardduty" {
  description = "Enable GuardDuty organization admin"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable Security Hub organization admin"
  type        = bool
  default     = true
}

variable "enable_config_aggregator" {
  description = "Enable Config aggregator"
  type        = bool
  default     = true
}

variable "enable_security_lake" {
  description = "Enable Security Lake"
  type        = bool
  default     = true
}

variable "enable_detective" {
  description = "Enable Detective"
  type        = bool
  default     = true
}

variable "region" {
  description = "AWS region for security services"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Organization = "captaingab"
    ManagedBy    = "terraform"
    Environment  = "security"
  }
}

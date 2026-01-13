############################################
# Variables for Athena Configuration
############################################

variable "region" {
  description = "AWS region for Athena queries"
  type        = string
  default     = "us-east-1"
}

variable "security_account_id" {
  description = "Security account ID"
  type        = string
}

variable "workload_account_id" {
  description = "Workload account ID"
  type        = string
}

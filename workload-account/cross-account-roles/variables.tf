############################################
# Workload Account - Cross-Account Variables
############################################

variable "security_account_id" {
  description = "AWS Account ID for the security account"
  type        = string
  default     = "404068503087" # Update with actual security account ID
}

variable "management_account_id" {
  description = "AWS Account ID for the management account"
  type        = string
  # This will be automatically determined from AWS Organizations
  default = null
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Organization = "captaingab"
    ManagedBy    = "terraform"
    Environment  = "production"
  }
}

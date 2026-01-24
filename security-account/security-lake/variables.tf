############################################
# Security Lake Variables
############################################

variable "member_account_ids" {
  description = "List of AWS account IDs to include in Security Lake (auto-populated from organization)"
  type        = list(string)
  default = [
    "111111222222", # Management account (organization CloudTrail)
    "333333444444", # Security account (Security Hub, GuardDuty findings)
    "555555666666"  # Workload account (VPC Flow, WAF, Lambda logs)
  ]
}

variable "auto_include_new_accounts" {
  description = "Automatically include new organization member accounts in Security Lake"
  type        = bool
  default     = true
}

variable "enabled_regions" {
  description = "List of AWS regions to enable Security Lake in"
  type        = list(string)
  default = [
    "us-east-1",
    "us-west-2",
    "eu-west-1"
  ]
}

variable "enable_query_access" {
  description = "Enable query access for external services"
  type        = bool
  default     = true
}

variable "retention_days" {
  description = "Number of days to retain Security Lake data"
  type        = number
  default     = 365
}

variable "transition_days" {
  description = "Number of days before transitioning to intelligent tiering"
  type        = number
  default     = 30
}

variable "opensearch_role_arn" {
  description = "ARN of the OpenSearch IAM role for Security Lake subscriber access"
  type        = string
}

############################################
# Log Source Configuration
############################################

variable "enable_waf_logs" {
  description = "Enable AWS WAF logs ingestion into Security Lake"
  type        = bool
  default     = true
}

variable "enable_lambda_logs" {
  description = "Enable AWS Lambda execution logs ingestion into Security Lake"
  type        = bool
  default     = true
}

variable "enable_network_firewall_logs" {
  description = "Enable AWS Network Firewall logs ingestion into Security Lake"
  type        = bool
  default     = true
}

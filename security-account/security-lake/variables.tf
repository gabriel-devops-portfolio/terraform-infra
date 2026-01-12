############################################
# Security Lake Variables
############################################

variable "member_account_ids" {
  description = "List of AWS account IDs to include in Security Lake"
  type        = list(string)
  default     = ["290793900072"] # Workload account
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

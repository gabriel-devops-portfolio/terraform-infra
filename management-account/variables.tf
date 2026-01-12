############################
# Account Email Addresses
############################

variable "security_account_email" {
  description = "Email address for the security account (must be unique)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.security_account_email))
    error_message = "Must be a valid email address"
  }
}

variable "workload_account_email" {
  description = "Email address for the workload account (must be unique)"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.workload_account_email))
    error_message = "Must be a valid email address"
  }
}

############################
# Optional Configuration
############################

variable "tags" {
  description = "Common tags to apply to all organization resources"
  type        = map(string)
  default     = {}
}

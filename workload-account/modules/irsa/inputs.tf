variable "provider_url" {
  type        = string
  default     = ""
  description = "The OIDC prvider url"
}
variable "k8s_service_account_namespace" {
  type        = string
  default     = ""
  description = "The namespace this oidc role will be used by"
}

variable "policy" {
  type        = any
  default     = {}
  description = "policy - json"
}

variable "k8s_service_account_name" {
  type        = string
  default     = ""
  description = "The name of the service account and iam role"
}
variable "role_name" {
  type        = string
  description = "The name of iam role"
}

variable "cluster_id" {
  type        = string
  default     = ""
  description = "The Cluster id to assign this role to"
}

variable "account_id" {
  type        = string
  default     = ""
  description = "The account_id"
}

variable "environment" {
  type        = string
  default     = ""
  description = ""
}

variable "oidc_fully_qualified_audiences" {
  default = []
}

variable "role_policy_arns" {
  default = []
}
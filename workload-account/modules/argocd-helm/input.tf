############################
# ArgoCD Module Variables
############################

variable "cluster_id" {
  description = "EKS cluster name/ID for ArgoCD deployment"
  type        = string
}

variable "eks_cluster_ca_certificate" {
  description = "EKS cluster CA certificate (base64 decoded)"
  type        = string
}

variable "argocd_helm_release_version" {
  description = "Version of the ArgoCD Helm chart to deploy"
  type        = string
  default     = "9.3.1"
}

variable "enableLocalRedis" {
  description = "Enable local Redis instance for ArgoCD (set to false for external Redis)"
  type        = bool
  default     = false
}

variable "module_depends_on" {
  description = "List of dependencies for this module"
  type        = any
  default     = []
}

variable "argocd_helm_values" {
  description = "List of values in YAML format to pass to ArgoCD Helm chart"
  type        = list(string)
  default     = []
}

variable "enable_cluster_admin_rbac" {
  description = "Grant ArgoCD service accounts cluster-admin permissions via ClusterRoleBinding"
  type        = bool
  default     = true
}

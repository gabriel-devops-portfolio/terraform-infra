variable "cluster_role_binding_name" {}
variable "cluster_role_name" {}
variable "cluster_id" { type = string }
variable "eks_cluster_ca_certificate" { type = string }
variable "account_id" {}
variable "create_cluster_role" {
  default = false
}
variable "subjects" {
  type = list(object({
    kind      = string
    name      = string
    api_group = optional(string)
    namespace = optional(string)
  }))
}
variable "rules" {
  type = list(object({
    api_groups = optional(list(string))
    resources  = optional(list(string))
    verbs      = optional(list(string))
  }))
  default = [{}]
}

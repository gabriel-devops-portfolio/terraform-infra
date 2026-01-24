output "cluster_id" {
  value = module.eks-cluster.cluster_id
}

output "eks_managed_node_groups" {
  value = module.eks-cluster.eks_managed_node_groups
}

output "cluster_oidc_issuer_url" {
  value = module.eks-cluster.cluster_oidc_issuer_url
}
output "oidc_provider_arn" {
  value = module.eks-cluster.oidc_provider_arn
}
output "cluster_certificate_authority_data" {
  value = module.eks-cluster.cluster_certificate_authority_data
}
output "aws_auth_configmap_yaml" {
  value = module.eks-cluster.aws_auth_configmap_yaml
}
output "cluster_endpoint" {
  value = module.eks-cluster.cluster_endpoint
}

output "node_security_group_id" {
  value = module.eks-cluster.node_security_group_id
}

output "cluster_security_group_id" {
  value = module.eks-cluster.cluster_security_group_id
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster"
  value       = module.eks-cluster.cluster_arn
}

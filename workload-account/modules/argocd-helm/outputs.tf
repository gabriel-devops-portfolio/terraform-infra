############################
# ArgoCD Module Outputs
############################

output "argocd_namespace" {
  description = "Namespace where ArgoCD is deployed"
  value       = helm_release.argocd.namespace
}

output "argocd_release_name" {
  description = "Name of the ArgoCD Helm release"
  value       = helm_release.argocd.name
}

output "argocd_chart_version" {
  description = "Version of the ArgoCD Helm chart deployed"
  value       = helm_release.argocd.version
}

output "argocd_status" {
  description = "Status of the ArgoCD Helm release"
  value       = helm_release.argocd.status
}

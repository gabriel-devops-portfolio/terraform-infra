############################
# ArgoCD Helm Release
############################

resource "helm_release" "argocd" {
  namespace        = "argocd"
  version          = var.argocd_helm_release_version
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  values           = var.argocd_helm_values
  create_namespace = true

  # Wait for resources to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600 # 10 minutes

  # Force update if needed
  force_update    = false
  cleanup_on_fail = true

  depends_on = [
    var.module_depends_on
  ]
}

############################
# ArgoCD RBAC (Cluster Admin Bindings)
############################

# Bind ArgoCD Application Controller to cluster-admin
resource "kubernetes_cluster_role_binding" "argocd_controller_cluster_admin" {
  count = var.enable_cluster_admin_rbac ? 1 : 0

  metadata {
    name = "argocd-controller-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "argocd-application-controller"
    namespace = helm_release.argocd.namespace
  }
}

# Bind ArgoCD Server to cluster-admin (for projects, repos, and app management that may require cluster-level ops)
resource "kubernetes_cluster_role_binding" "argocd_server_cluster_admin" {
  count = var.enable_cluster_admin_rbac ? 1 : 0

  metadata {
    name = "argocd-server-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "argocd-server"
    namespace = helm_release.argocd.namespace
  }
}

# Bind ArgoCD Repo Server to cluster-admin (needed when templates apply cluster-scoped manifests)
resource "kubernetes_cluster_role_binding" "argocd_repo_cluster_admin" {
  count = var.enable_cluster_admin_rbac ? 1 : 0

  metadata {
    name = "argocd-repo-server-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "argocd-repo-server"
    namespace = helm_release.argocd.namespace
  }
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.aws_eks_cluster.cluster.name
}


data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "kubernetes_cluster_role" "cr" {
  count = var.create_cluster_role ? 1 : 0
  metadata {
    name = var.cluster_role_name
  }
  dynamic "rule" {
    for_each = var.rules
    content {
      api_groups = rule.value["api_groups"]
      resources  = rule.value["resources"]
      verbs      = rule.value["verbs"]
    }
  }
}

resource "kubernetes_cluster_role_binding" "crb" {
  metadata {
    name = var.cluster_role_binding_name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = var.cluster_role_name
  }
  dynamic "subject" {
    for_each = var.subjects
    content {
      kind      = subject.value["kind"]
      name      = subject.value["name"]
      api_group = subject.value["api_group"]
      namespace = subject.value["namespace"]
    }
  }
}
